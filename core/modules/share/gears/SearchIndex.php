<?php
/**
 * @file
 * SearchIndex — индекс поиска по сайту: текст и основы слов каждой страницы на каждом языке.
 */
namespace Energine\share\gears;

/**
 * Строка индекса (share_search_index) — страница на языке: название (title) и текст для отрывка (body), их основы
 * (title_stems, body_stems — для FULLTEXT). Текст страницы — описание раздела и её текстовые блоки, которые она показывает
 * (по макету и шаблону содержимого: блок прежнего шаблона, оставшийся в базе, — нет; общие блоки без страницы — нет).
 * Не индексируются: служебные страницы (сегменты SYSTEM_SEGMENTS у корня и всё под ними: админка,
 * вход, карта …), страницы-ссылки, выключенные на языке — их строки удаляются. Видимость посетителю (права)
 * проверяет поиск по его дереву, а не индекс.
 */
final class SearchIndex {
    const TABLE = 'share_search_index';

    /**
     * Служебные сегменты корня — тот же список, что DivisionEditor::SYSTEM_SEGMENTS (tests/search.php сверяет): индекс
     * строит и setup reindex, а компонент в setup грузится только после файлов контроллера и менеджера компонентов (в них
     * объявлены интерфейсы ядра) — гир индекса от компонента не зависит.
     */
    const SYSTEM_SEGMENTS = ['admin', 'login', 'register', 'restore-password', 'profile', 'sitemap', 'google-sitemap', 'robots.txt', 'search'];

    /**
     * Номера блоков секций визитки — те же, что TextBlock::SECTIONS (tests/search.php сверяет; компонент, как и
     * DivisionEditor, в setup не грузится).
     */
    const SECTIONS = ['hero' => 11, 'services' => 12, 'prices' => 13, 'reviews' => 14, 'gallery' => 15, 'faq' => 16,
        'contacts' => 17, 'cta' => 18];

    /**
     * Подключение — PDO, как у LinkChecker: индекс строят и сайт, и setup reindex (у него своё подключение).
     *
     * @param string|null $templates каталог шаблонов площадки (web/templates/, по умолчанию — от HTDOCS_DIR): по макету и
     *     шаблону содержимого страницы индексируются только блоки, которые она показывает; каталога нет — все её блоки
     */
    public function __construct(private \PDO $pdo, private ?string $templates = null) {
        $this->templates ??= defined('HTDOCS_DIR') ? HTDOCS_DIR . '/templates/' : null;
    }

    private function q(string $sql, array $params = []): \PDOStatement {
        $st = $this->pdo->prepare($sql);
        $st->execute($params);
        return $st;
    }

    /** блочные теги: на их месте — пробел (абзацы, ячейки, пункты не слипаются); строчные убираются без пробела */
    private const BLOCK = 'p|div|br|hr|li|ul|ol|dl|dt|dd|h[1-6]|table|thead|tbody|tfoot|tr|td|th|caption|section|article|header'
        . '|footer|nav|aside|main|blockquote|pre|figure|figcaption|address|iframe';

    /**
     * HTML → текст: блочные теги — пробелы, строчные (<b>, <a>, <span>) — без пробела, script и style — прочь,
     * сущности раскрыты, неразрывные пробелы — обычные, пробелы схлопнуты. Символы вне BMP (эмодзи из сущности
     * &#128222;) — прочь: таблицы utf8mb3 их не хранят, запись строки индекса упала бы.
     */
    public static function text(?string $html): string {
        $text = preg_replace('~<(script|style)\b[^>]*>.*?</\1\s*>~is', ' ', (string)$html);
        $text = preg_replace('~</?(?:' . self::BLOCK . ')\b[^>]*>~i', ' ', (string)$text);
        $text = html_entity_decode(preg_replace('~<[^>]*>~', '', (string)$text), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = preg_replace('~[^\x{0}-\x{FFFF}]~u', '', mb_scrub($text, 'UTF-8'));
        return trim((string)preg_replace('~[\s\x{00A0}]+~u', ' ', (string)$text));
    }

    /**
     * Переиндексировать страницу на языке (или на всех языках).
     */
    public function page(int $smapId, ?int $langId = null): void {
        $langs = $langId ? [$langId] : array_map('intval', $this->q('SELECT lang_id FROM share_languages')->fetchAll(\PDO::FETCH_COLUMN));
        if (!$this->indexable($smapId)) {
            $this->drop($smapId, $langId);
            return;
        }
        $names = [];
        foreach ($this->q('SELECT lang_id, smap_name, smap_title, smap_html_title, smap_description_rtf, smap_is_disabled
            FROM share_sitemap_translation WHERE smap_id = ?', [$smapId])->fetchAll(\PDO::FETCH_ASSOC) as $row) {
            $names[(int)$row['lang_id']] = $row;
        }
        $shown = $this->shown($smapId);
        $blocks = [];
        foreach ($this->q('SELECT tt.lang_id, tt.tb_content, t.tb_num FROM share_textblocks t JOIN share_textblocks_translation tt
            ON tt.tb_id = t.tb_id WHERE t.smap_id = ? ORDER BY t.tb_num', [$smapId])->fetchAll(\PDO::FETCH_ASSOC) as $row) {
            if ($shown === null || in_array((string)$row['tb_num'], $shown, true)) {
                $blocks[(int)$row['lang_id']][] = self::text($row['tb_content']);
            }
        }
        foreach ($langs as $lang) {
            $t = $names[$lang] ?? null;
            if (!$t || !empty($t['smap_is_disabled'])) {
                $this->drop($smapId, $lang);
                continue;
            }
            $title = trim((string)$t['smap_name']);
            $titleText = implode(' ', array_filter([$title, (string)$t['smap_title'], (string)$t['smap_html_title']]));
            $body = trim(self::text($t['smap_description_rtf']) . ' ' . implode(' ', $blocks[$lang] ?? []));
            $this->q('REPLACE INTO ' . self::TABLE . ' (smap_id, lang_id, title, body, title_stems, body_stems)
                VALUES (?, ?, ?, ?, ?, ?)', [$smapId, $lang, $title, $body, Stemmer::stems($titleText), Stemmer::stems($body)]);
        }
    }

    /**
     * Обновить индекс при сохранении (правка текста, откат, сохранение раздела) — внутри транзакции сохранения, тем же
     * подключением: индекс видит её ещё не записанные изменения. Сбой индекса сохранение не отменяет — ошибка в журнал.
     * Кроме взаимной блокировки (SQLSTATE 40001): InnoDB откатывает при ней всю транзакцию, сохранения уже нет — ошибка
     * уходит вызывающему (его откат и сообщение об ошибке вместо ложного «сохранено»).
     *
     * @param int[] $smapIds страницы
     */
    public static function refresh(\PDO $pdo, array $smapIds, ?int $langId = null): void {
        try {
            $index = new self($pdo);
            foreach (array_unique(array_map('intval', $smapIds)) as $id) {
                $index->page($id, $langId);
            }
        } catch (\Throwable $e) {
            if ($e instanceof \PDOException && $e->getCode() === '40001') {
                throw $e;
            }
            error_log('Energine: индекс поиска: ' . $e->getMessage());
        }
    }

    /**
     * Переиндексировать весь сайт.
     *
     * @return int строк в индексе
     */
    public function all(): int {
        $this->q('DELETE FROM ' . self::TABLE);
        foreach ($this->q('SELECT smap_id FROM share_sitemap ORDER BY smap_id')->fetchAll(\PDO::FETCH_COLUMN) as $id) {
            $this->page((int)$id);
        }
        return (int)$this->q('SELECT COUNT(*) FROM ' . self::TABLE)->fetchColumn();
    }

    /**
     * Номера блоков, которые страница показывает: текстовые блоки (TextBlock) её макета и шаблона содержимого (свой XML
     * страницы — вместо файла, как у DocumentController) с номером страницы — num с числом (нечисловой — общий блок всех
     * страниц), секция визитки — номер из SECTIONS, без num — 1. null — шаблон не прочитать (каталога шаблонов нет,
     * файла нет, XML испорчен): тогда индексируются все блоки страницы.
     *
     * @return string[]|null
     */
    private function shown(int $smapId): ?array {
        $page = $this->q('SELECT smap_layout, smap_content, smap_layout_xml, smap_content_xml FROM share_sitemap WHERE smap_id = ?',
            [$smapId])->fetch(\PDO::FETCH_ASSOC);
        if (!$page || $this->templates === null) {
            return null;
        }
        $xml = '';
        foreach (['layout', 'content'] as $type) {
            $own = trim((string)$page['smap_' . $type . '_xml']);
            if ($own === '') {
                $file = $this->templates . $type . '/' . $page['smap_' . $type];
                $own = is_file($file) ? (string)file_get_contents($file) : '';
                if ($own === '') {
                    return null;
                }
            }
            $xml .= preg_replace('~<\?xml\s.+?\?>~s', '', $own);
        }
        $doc = @simplexml_load_string('<structure>' . $xml . '</structure>');
        if (!$doc) {
            return null;
        }
        $nums = [];
        foreach ($doc->xpath('//component') as $component) {
            if (!preg_match('~(?:^|\\\\)TextBlock$~', (string)$component['class'])) {
                continue;
            }
            $num = '1';
            foreach ($component->xpath('params/param') as $param) {
                $value = trim((string)$param);
                if ((string)$param['name'] === 'num') {
                    $num = $value;
                } elseif ((string)$param['name'] === 'section' && isset(self::SECTIONS[$value])) {
                    $num = (string)self::SECTIONS[$value];
                    break;
                }
            }
            if (intval($num) !== 0) {
                $nums[] = $num;
            }
        }
        return $nums;
    }

    /** страница с текстом для посетителя: не служебная и не страница-ссылка */
    private function indexable(int $smapId): bool {
        $root = (int)$this->q('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL')->fetchColumn();
        for ($cur = $smapId, $depth = 0; $cur && $depth < 64; $depth++) {
            $row = $this->q('SELECT smap_pid, smap_segment, smap_redirect_url FROM share_sitemap WHERE smap_id = ?', [$cur])->fetch(\PDO::FETCH_ASSOC);
            if (!$row) {
                return false;
            }
            if ($cur === $smapId && trim((string)$row['smap_redirect_url']) !== '') {
                return false; // страница-ссылка: своего текста у неё нет
            }
            if ((int)$row['smap_pid'] === $root && in_array($row['smap_segment'], self::SYSTEM_SEGMENTS, true)) {
                return false;
            }
            $cur = (int)$row['smap_pid'];
        }
        return true;
    }

    private function drop(int $smapId, ?int $langId): void {
        $langId ? $this->q('DELETE FROM ' . self::TABLE . ' WHERE smap_id = ? AND lang_id = ?', [$smapId, $langId])
            : $this->q('DELETE FROM ' . self::TABLE . ' WHERE smap_id = ?', [$smapId]);
    }
}
