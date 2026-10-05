<?php
/**
 * @file
 * LinkChecker: битые ссылки в текстах сайта (текстовые блоки, описания разделов).
 */
namespace Energine\share\gears;

/**
 * Битые ссылки в текстах: ссылки (href, src) на страницы сайта, которых нет, которые отключены или только для
 * вошедших (ссылки на админку в текстах для администратора — пометка, а не ошибка), и на
 * отсутствующие файлы. Внешние сайты не запрашиваются: ссылки на другие хосты, mailto:, tel:, якоря не проверяются.
 *
 * Путь ссылки — от корня сайта (как <base href>): без корня, языка (ua/…), запроса и якоря; страница ищется точно
 * по цепочке сегментов, файл — в каталоге сайта (web/).
 */
class LinkChecker {
    /** причина-пометка, а не ошибка: ссылка ведёт на страницу для вошедших (например, в админку из текста для администратора) */
    const MEMBERS_ONLY = 'страница только для вошедших';

    /** @var \PDO */
    private $pdo;
    /** @var string каталог сайта (web/) */
    private $webDir;
    /** @var string хост сайта */
    private $domain;
    /** @var string корень сайта: '/' или '/site/' */
    private $root;
    /** @var array путь страницы ('' — главная, 'a/b/') => ['id', 'langs' => языки, на которых включена, 'guest' => гостю можно читать] */
    private $pages = [];
    /** @var string язык по умолчанию (ссылка без префикса языка) */
    private $defaultLang = '';
    /** @var string[] сокращения языков, кроме языка по умолчанию */
    private $langPrefixes = [];

    public function __construct(\PDO $pdo, string $webDir, string $domain, string $root = '/') {
        $this->pdo = $pdo;
        $this->webDir = rtrim($webDir, '/');
        $this->domain = self::host($domain);
        $this->root = '/' . trim($root, '/') . (trim($root, '/') === '' ? '' : '/');
        $this->loadPages();
    }

    /**
     * Все битые ссылки.
     * @return array[] ['page' => путь страницы текста или '(общий блок)', 'lang' => сокращение, 'link', 'reason']
     */
    public function check(): array {
        $result = [];
        $langs = $this->pdo->query('SELECT lang_id, lang_abbr FROM share_languages')->fetchAll(\PDO::FETCH_KEY_PAIR);
        $pathOf = array_column(array_map(fn($p, $k) => ['id' => $p['id'], 'path' => $k], $this->pages, array_keys($this->pages)), 'path', 'id');
        $sources = $this->pdo->query(
            'SELECT t.smap_id AS page, tt.lang_id AS lang, tt.tb_content AS html FROM share_textblocks t
               JOIN share_textblocks_translation tt ON tt.tb_id = t.tb_id
             UNION ALL
             SELECT smap_id, lang_id, smap_description_rtf FROM share_sitemap_translation WHERE smap_description_rtf IS NOT NULL'
        );
        foreach ($sources as $row) {
            if (!preg_match_all('~\b(?:href|src)\s*=\s*(["\'])(.*?)\1~is', (string)$row['html'], $m)) {
                continue;
            }
            foreach (array_unique($m[2]) as $link) {
                $reason = $this->brokenReason(html_entity_decode($link, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
                if ($reason !== null) {
                    $result[] = [
                        'page' => $row['page'] === null ? '(общий блок)' : ($pathOf[$row['page']] ?? '?') ,
                        'lang' => $langs[$row['lang']] ?? '?',
                        'link' => $link,
                        'reason' => $reason,
                    ];
                }
            }
        }
        return $result;
    }

    /** хост без порта и «www.»: www.example.org и example.org — один сайт */
    private static function host(string $host): string {
        return preg_replace('/^www\./', '', strtolower(preg_replace('/:\d+$/', '', $host)));
    }

    /**
     * Страницы, в текстах которых есть ссылки на страницу $pageId (по пути; язык ссылки не важен).
     * @return string[] пути страниц-источников ('' — главная), без повторов
     */
    public function referrers(int $pageId): array {
        $target = null;
        foreach ($this->pages as $path => $p) {
            if ($p['id'] === $pageId) { $target = $path; }
        }
        if ($target === null) {
            return [];
        }
        $pathOf = [];
        foreach ($this->pages as $path => $p) { $pathOf[$p['id']] = $path; }
        $result = [];
        $sources = $this->pdo->query(
            'SELECT t.smap_id AS page, tt.tb_content AS html FROM share_textblocks t JOIN share_textblocks_translation tt ON tt.tb_id = t.tb_id
             UNION ALL SELECT smap_id, smap_description_rtf FROM share_sitemap_translation WHERE smap_description_rtf IS NOT NULL'
        );
        foreach ($sources as $row) {
            if ($row['page'] == $pageId || !preg_match_all('~\b(?:href|src)\s*=\s*(["\'])(.*?)\1~is', (string)$row['html'], $m)) {
                continue;
            }
            foreach ($m[2] as $link) {
                if ($this->pageKeyOf(html_entity_decode($link, ENT_QUOTES | ENT_HTML5, 'UTF-8')) === $target) {
                    $result[$row['page'] === null ? '(общий блок)' : ($pathOf[$row['page']] ?? '?')] = true;
                    break;
                }
            }
        }
        return array_keys($result);
    }

    /**
     * Путь страницы сайта, на которую ведёт ссылка ('' — главная), или null — ссылка не на страницу этого сайта
     * (внешняя, файл, якорь, mailto …). Префикс языка снимается.
     */
    public function pageKeyOf(string $link): ?string {
        $link = trim($link);
        if ($link === '' || $link[0] === '#' || preg_match('~^(mailto|tel|javascript|data|sms|skype|callto):~i', $link)) {
            return null;
        }
        if (preg_match('~^(?:https?:)?//([^/?#]+)(.*)$~i', $link, $m)) {
            if (self::host($m[1]) !== $this->domain) {
                return null;
            }
            $link = $m[2] === '' ? '/' : $m[2];
        } elseif (preg_match('~^[a-z][a-z0-9+.-]*:~i', $link)) {
            return null;
        }
        $path = rawurldecode(preg_replace('~[?#].*$~s', '', $link));
        if (str_starts_with($path, '/')) {
            if (!str_starts_with($path . '/', $this->root) && $path !== rtrim($this->root, '/')) {
                return null;
            }
            $path = substr($path, strlen($this->root));
        }
        $parts = [];
        foreach (explode('/', $path) as $part) {
            if ($part === '..') { array_pop($parts); } elseif ($part !== '.' && $part !== '') { $parts[] = $part; }
        }
        $last = end($parts);
        if (!($path === '' || str_ends_with($path, '/')) && $last !== false && str_contains($last, '.')) {
            return null; // файл
        }
        if ($parts && in_array($parts[0], $this->langPrefixes, true)) {
            array_shift($parts);
        }
        $key = $parts ? implode('/', $parts) . '/' : '';
        return isset($this->pages[$key]) ? $key : null;
    }

    /**
     * Почему ссылка битая, или null — рабочая либо не проверяется. Язык ссылки — по префиксу (ua/…), без префикса —
     * язык по умолчанию: так адрес и открывается; страница должна быть включена на этом языке.
     */
    public function brokenReason(string $link): ?string {
        $link = trim($link);
        if ($link === '' || $link[0] === '#' || preg_match('~^(mailto|tel|javascript|data|sms|skype|callto):~i', $link)) {
            return null;
        }
        if (preg_match('~^(?:https?:)?//([^/?#]+)(.*)$~i', $link, $m)) {
            if (self::host($m[1]) !== $this->domain) {
                return null; // другой сайт
            }
            $link = $m[2] === '' ? '/' : $m[2];
        } elseif (preg_match('~^[a-z][a-z0-9+.-]*:~i', $link)) {
            return null; // другая схема
        }
        $path = rawurldecode(preg_replace('~[?#].*$~s', '', $link));
        if (str_starts_with($path, '/')) {
            if (!str_starts_with($path . '/', $this->root) && $path !== rtrim($this->root, '/')) {
                return 'вне сайта';
            }
            $path = substr($path, strlen($this->root));
        }
        // относительный путь — от корня сайта (<base href>); «./» и «../» выше корня не уходят
        $parts = [];
        foreach (explode('/', $path) as $part) {
            if ($part === '..') {
                array_pop($parts);
            } elseif ($part !== '.' && $part !== '') {
                $parts[] = $part;
            }
        }
        $isDir = $path === '' || str_ends_with($path, '/');
        $last = end($parts);
        if (!$isDir && $last !== false && str_contains($last, '.')) {
            $file = $this->webDir . '/' . implode('/', $parts);
            return is_file($file) ? null : 'нет файла';
        }
        $lang = $this->defaultLang;
        if ($parts && in_array($parts[0], $this->langPrefixes, true)) {
            $lang = array_shift($parts);
        }
        $key = $parts ? implode('/', $parts) . '/' : '';
        if (!isset($this->pages[$key])) {
            return 'нет страницы';
        }
        if (!in_array($lang, $this->pages[$key]['langs'], true)) {
            return 'страница отключена';
        }
        return $this->pages[$key]['guest'] ? null : self::MEMBERS_ONLY;
    }

    /**
     * Пути всех страниц одним запросом: сегменты по дереву, доступность гостю — включена на всех языках и группа
     * гостей имеет право чтения.
     */
    private function loadPages(): void {
        $this->langPrefixes = $this->pdo->query('SELECT lang_abbr FROM share_languages WHERE lang_default = 0')->fetchAll(\PDO::FETCH_COLUMN);
        $this->defaultLang = (string)$this->pdo->query('SELECT lang_abbr FROM share_languages WHERE lang_default = 1')->fetchColumn();
        $guest = (int)$this->pdo->query('SELECT group_id FROM user_groups WHERE group_default = 1')->fetchColumn();
        $rows = $this->pdo->query(
            "SELECT s.smap_id, s.smap_pid, s.smap_segment,
                    (SELECT MAX(a.right_id) FROM share_access_level a WHERE a.smap_id = s.smap_id AND a.group_id = $guest) AS guest_right
               FROM share_sitemap s"
        )->fetchAll(\PDO::FETCH_ASSOC);
        // языки, на которых страница включена
        $langsOf = [];
        foreach ($this->pdo->query('SELECT t.smap_id, l.lang_abbr FROM share_sitemap_translation t
                JOIN share_languages l USING (lang_id) WHERE t.smap_is_disabled = 0') as $r) {
            $langsOf[$r['smap_id']][] = $r['lang_abbr'];
        }
        $byId = array_column($rows, null, 'smap_id');
        foreach ($byId as $id => $row) {
            $segments = [];
            $guestOk = true;
            $langs = null;
            for ($cur = $row, $depth = 0; $cur && $depth < 50;
                 $cur = $cur['smap_pid'] === null ? null : ($byId[$cur['smap_pid']] ?? null), $depth++) {
                // страница доступна на языке, если на нём включены она и все её родители
                $own = $langsOf[$cur['smap_id']] ?? [];
                $langs = $langs === null ? $own : array_values(array_intersect($langs, $own));
                $guestOk = $guestOk && (int)$cur['guest_right'] > 0;
                if ($cur['smap_pid'] !== null) {
                    array_unshift($segments, $cur['smap_segment']);
                }
            }
            $this->pages[$segments ? implode('/', $segments) . '/' : ''] = ['id' => (int)$id, 'langs' => $langs ?? [], 'guest' => $guestOk];
        }
    }
}
