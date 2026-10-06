<?php
/**
 * @file
 * SiteSearch — поиск по сайту: запрос посетителя → страницы индекса (SearchIndex), которые ему видны, с отрывками.
 */
namespace Energine\share\gears;

/**
 * Поиск на языке посетителя. Слова запроса — основы (Stemmer): основа короче трёх букв не обязательна (FULLTEXT таких
 * слов не хранит), остальные обязательны все — страница находится, если в её названии или тексте каждой основе
 * подходит какое-то слово (pattern: «услуг» — «услуги», «услугами»). Кандидаты — FULLTEXT (любая из основ, по убыванию
 * релевантности, не больше MAX_CANDIDATES); дальше здесь: все основы есть, страница в дереве посетителя (Sitemap:
 * включена на его языке, права не ниже чтения, предки тоже). Порядок: сначала страницы, где слова запроса есть в
 * названии (больше таких слов — выше), затем — где совпадений больше.
 * Отрывок — около SNIPPET знаков текста вокруг первого совпадения, найденные слова отмечены (mark). Журнал поиска (log) —
 * что искали и сколько нашлось: владельцу видно, каких страниц или слов не хватает.
 */
final class SiteSearch {
    /** результатов на страницу выдачи */
    const PER_PAGE = 10;
    /** кандидатов из FULLTEXT */
    const MAX_CANDIDATES = 200;
    /** обязательных слов запроса */
    const MAX_WORDS = 10;
    /** длина запроса, знаков */
    const MAX_QUERY = 200;
    /** длина отрывка, знаков */
    const SNIPPET = 200;
    /** строк журнала поиска — не больше: при чистке остаются самые свежие */
    const LOG_ROWS = 10000;

    public function __construct(private Db $db) {
    }

    /**
     * Запрос для поиска, показа и журнала: корректный UTF-8, без символов, которых нет в XML 1.0 и в таблицах utf8mb3
     * (управляющие — пробелы, вне BMP — прочь), пробелы схлопнуты, не длиннее MAX_QUERY.
     */
    public static function normalize(string $q): string {
        $q = preg_replace('~[\x{0}-\x{1F}\x{7F}]~u', ' ', mb_scrub($q, 'UTF-8'));
        $q = preg_replace('~[^\x{20}-\x{D7FF}\x{E000}-\x{FFFD}]~u', '', (string)$q);
        $q = preg_replace('~[\s\x{A0}]+~u', ' ', (string)$q);
        return trim(mb_substr(trim((string)$q), 0, self::MAX_QUERY));
    }

    /**
     * Обязательные основы запроса: не короче трёх букв, без повторов, не больше MAX_WORDS.
     *
     * @return string[]
     */
    public static function terms(string $q): array {
        $terms = [];
        foreach (Stemmer::words($q) as $word) {
            $stem = Stemmer::stem($word);
            if (mb_strlen($stem) >= 3) {
                $terms[$stem] = true;
            }
        }
        return array_slice(array_map('strval', array_keys($terms)), 0, self::MAX_WORDS);
    }

    /**
     * Поиск: страница выдачи (номер приводится к 1…pages).
     *
     * @return array{query: string, total: int, page: int, pages: int,
     *     items: list<array{id: int, url: string, title: string, snippet: list<array{text: string, mark: bool}>}>}
     */
    public function find(string $q, int $langId, int $page = 1): array {
        $query = self::normalize($q);
        $terms = self::terms($query);
        $found = [];
        if ($terms) {
            $against = implode(' ', array_map(fn(string $t) => $t . '*', $terms));
            $rows = $this->db->rows('SELECT smap_id, title, body, title_stems, body_stems FROM ' . SearchIndex::TABLE
                . ' WHERE lang_id = ? AND MATCH (title_stems, body_stems) AGAINST (? IN BOOLEAN MODE)'
                . ' ORDER BY MATCH (title_stems, body_stems) AGAINST (? IN BOOLEAN MODE) DESC LIMIT ' . self::MAX_CANDIDATES,
                [$langId, $against, $against]);
            foreach ($rows as $i => $row) {
                $inTitle = self::hits((string)$row['title_stems'], $terms);
                $inBody = self::hits((string)$row['body_stems'], $terms);
                foreach ($terms as $t) {
                    if (!$inTitle[$t] && !$inBody[$t]) {
                        continue 2; // не все слова запроса есть на странице
                    }
                }
                if (!$this->visible((int)$row['smap_id'])) {
                    continue;
                }
                $found[] = ['row' => $row, 'title' => count(array_filter($inTitle)), 'hits' => array_sum($inTitle) + array_sum($inBody),
                    'order' => $i, 'id' => (int)$row['smap_id']];
            }
            // слова запроса в названии — выше (больше слов — выше); затем больше совпадений; затем порядок FULLTEXT и номер
            // страницы (листалка стабильна)
            usort($found, fn(array $a, array $b) => [$b['title'], $b['hits'], $a['order'], $a['id']] <=> [$a['title'], $a['hits'], $b['order'], $b['id']]);
        }
        $total = count($found);
        $pages = (int)ceil($total / self::PER_PAGE);
        $page = max(1, min($page, $pages));
        $items = [];
        foreach (array_slice($found, ($page - 1) * self::PER_PAGE, self::PER_PAGE) as $f) {
            $id = (int)$f['row']['smap_id'];
            $items[] = ['id' => $id, 'url' => (string)E()->getMap()->getURLByID($id), 'title' => self::xml((string)$f['row']['title']),
                'snippet' => self::snippet((string)$f['row']['body'], $terms)];
        }
        return ['query' => $query, 'total' => $total, 'page' => $page, 'pages' => $pages, 'items' => $items];
    }

    /**
     * Журнал поиска (share_search_log): запрос в нижнем регистре на языке — сколько раз искали, сколько нашлось в
     * последний раз, когда. Сбой журнала поиску не мешает — в журнал ошибок. Изредка (1 раз из 100) — чистка: остаются
     * LOG_ROWS самых свежих строк (журнал не растёт без конца от случайных запросов).
     */
    public function log(string $q, int $langId, int $total): void {
        $query = mb_substr(mb_strtolower(self::normalize($q)), 0, self::MAX_QUERY);
        if ($query === '') {
            return;
        }
        try {
            $this->db->exec('INSERT INTO share_search_log (log_query, lang_id, log_count, log_results, log_last) VALUES (?, ?, 1, ?, NOW())'
                . ' ON DUPLICATE KEY UPDATE log_count = log_count + 1, log_results = VALUES(log_results), log_last = VALUES(log_last)',
                [$query, $langId, $total]);
            if (random_int(1, 100) === 1) {
                $this->db->exec('DELETE FROM share_search_log WHERE log_last < (SELECT log_last FROM (SELECT log_last FROM share_search_log'
                    . ' ORDER BY log_last DESC LIMIT 1 OFFSET ' . self::LOG_ROWS . ') edge)');
            }
        } catch (\Throwable $e) {
            error_log('Energine: журнал поиска: ' . $e->getMessage());
        }
    }

    /**
     * Отрывок текста: около SNIPPET знаков вокруг первого слова, начинающегося с основы запроса (нет такого — начало
     * текста), по границам слов, «…» на месте отрезанного; слова запроса — с mark.
     *
     * @param string[] $terms
     * @return list<array{text: string, mark: bool}>
     */
    public static function snippet(string $body, array $terms): array {
        $body = self::xml($body);
        $length = mb_strlen($body);
        $start = 0;
        if (preg_match_all(Stemmer::WORD, $body, $m, PREG_OFFSET_CAPTURE)) {
            foreach ($m[0] as [$word, $offset]) {
                if (self::matches($word, $terms)) {
                    $start = max(0, mb_strlen(substr($body, 0, $offset)) - (int)(self::SNIPPET / 3));
                    break;
                }
            }
        }
        $text = mb_substr($body, $start, self::SNIPPET);
        $cutEnd = $start + self::SNIPPET < $length;
        // отрывок — из целых слов: часть слова на краю (рядом с краем нет пробела) убирается
        if ($start > 0 && !preg_match('~^\s~u', mb_substr($body, $start - 1, 1))) {
            $text = (string)preg_replace('~^\S*\s+~u', '', $text, 1);
        }
        if ($cutEnd && !preg_match('~^\s~u', mb_substr($body, $start + self::SNIPPET, 1))) {
            $text = (string)preg_replace('~\s+\S*$~u', '', $text, 1);
        }
        $pieces = [];
        $add = function (string $piece, bool $mark) use (&$pieces): void {
            if ($piece === '') {
                return;
            }
            $last = count($pieces) - 1;
            if (!$mark && $last >= 0 && !$pieces[$last]['mark']) {
                $pieces[$last]['text'] .= $piece;
            } else {
                $pieces[] = ['text' => $piece, 'mark' => $mark];
            }
        };
        $add($start > 0 ? '… ' : '', false);
        $at = 0;
        if (preg_match_all(Stemmer::WORD, $text, $m, PREG_OFFSET_CAPTURE)) {
            foreach ($m[0] as [$word, $offset]) {
                if (self::matches($word, $terms)) {
                    $add(substr($text, $at, $offset - $at), false);
                    $add($word, true);
                    $at = $offset + strlen($word);
                }
            }
        }
        $add(substr($text, $at), false);
        $add($cutEnd ? ' …' : '', false);
        return $pieces;
    }

    /** слово подходит к основе запроса (pattern; сравниваются основы: «услугами» — «услуг») */
    private static function matches(string $word, array $terms): bool {
        $stem = Stemmer::stem($word);
        foreach ($terms as $t) {
            if (preg_match(self::pattern($t), $stem)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Основа слова страницы подходит к основе запроса: начинается с неё; у короткой основы (до четырёх букв) — длиннее
     * не больше чем на букву («цен» — «цена», «ценам», но не «центр»; «кот» — не «который»), у длинной — любое
     * продолжение («калибр» — «калибровка»). Шаблон для строки основ через пробел и для одной основы.
     */
    private static function pattern(string $term): string {
        return '~(?:^| )' . preg_quote($term, '~') . (mb_strlen($term) <= 4 ? '\S?(?= |$)' : '') . '~u';
    }

    /**
     * Сколько основ строки индекса (через пробел) подходит к каждой основе запроса (pattern).
     *
     * @param string[] $terms
     * @return array<string, int>
     */
    private static function hits(string $stems, array $terms): array {
        $hits = [];
        foreach ($terms as $t) {
            $hits[$t] = (int)preg_match_all(self::pattern($t), $stems);
        }
        return $hits;
    }

    /** страница видна посетителю: в его дереве (включена на языке, предки тоже) и права не ниже чтения */
    private function visible(int $id): bool {
        $map = E()->getMap();
        return $map->getTree() && $map->getTree()->getNodeById($id) && $map->getDocumentRights($id) > ACCESS_NONE;
    }

    /** текст без символов, которых нет в XML 1.0 (отрывок и название уходят в XML страницы) */
    private static function xml(string $text): string {
        return (string)preg_replace('~[^\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}]~u', '', mb_scrub($text, 'UTF-8'));
    }
}
