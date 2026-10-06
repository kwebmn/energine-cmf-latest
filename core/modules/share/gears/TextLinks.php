<?php
/**
 * Битые ссылки в текстах на самой странице (идея xsight): ссылка из текстового блока на страницу, которой для этого
 * посетителя нет (нет совсем, закрыта правами, выключена на языке), или на отсутствующий файл гостю выводится обычным
 * текстом — без перехода на 404, отсутствующая картинка не выводится; администратор вне режима правки видит ссылку с
 * пометкой (класс e-broken-link / e-broken-image) и причиной в подсказке. Отчёт «Битые ссылки» (LinkChecker) по-прежнему
 * собирает их для владельца по всему сайту.
 *
 * Рабочими считаются: страницы из дерева посетителя (и с явным префиксом своего языка, и с точкой в сегменте —
 * robots.txt), старые адреса (301 на видимую ему страницу, с хвостом пути), ссылки на другой язык (его дерево не
 * загружено — не проверяются), внешние, якоря, mailto:, tel:, существующие файлы (адрес ресайзера — по файлу-источнику).
 * HTML без находок возвращается тем же и не разбирается вовсе: адреса сначала собираются регулярным выражением, DOM —
 * только когда есть что менять; текст, который разбор перестроил бы (непарный закрывающий тег), — тоже как есть.
 * Запросов к базе почти нет: дерево посетителя уже загружено, старые адреса читаются одним запросом и только если
 * какая-то ссылка не нашлась в дереве.
 */
namespace Energine\share\gears;

final class TextLinks {
    /** @var array<string, ?string> причина по ссылке за запрос */
    private array $reasons = [];

    /**
     * @param \Closure $pageOf (string[] сегменты без языка): ?int — страница по полному пути, видимая посетителю
     * @param \Closure $oldTarget (string[]): ?string[] — старый адрес: путь (сегменты, с хвостом), на который он ведёт 301;
     *     null — не старый адрес
     * @param string $webDir корень сайта на диске (web/)
     * @param string $root корень сайта в адресе (site.root: /, /sub/)
     * @param string $host имя сайта (ссылки на него с полным адресом — свои)
     * @param string[] $langPrefixes префиксы языков в адресе (у языка по умолчанию префикса нет)
     * @param string $currentPrefix префикс текущего языка ('' — язык по умолчанию)
     * @param string $defaultAbbr сокращение языка по умолчанию: адрес с ним явно (/ru/info/) — тот же, что без него
     */
    public function __construct(private \Closure $pageOf, private \Closure $oldTarget, private string $webDir,
        private string $root, private string $host, private array $langPrefixes, private string $currentPrefix = '',
        private string $defaultAbbr = '') {
    }

    /**
     * Для текущего запроса: дерево посетителя, его права, старые адреса, языки (один экземпляр на запрос).
     */
    public static function forRequest(): self {
        static $instance = null;
        if ($instance !== null) {
            return $instance;
        }
        $map = E()->getMap();
        $aliases = new PageAliases(E()->getDB());
        $site = E()->getSiteManager()->getCurrentSite();
        $language = E()->getLanguage();
        $prefixes = [];
        $current = $default = '';
        foreach ($language->getLanguages() as $id => $lang) {
            if (empty($lang['lang_default'])) {
                $prefixes[] = (string)$lang['lang_abbr'];
                if ((int)$id === (int)$language->getCurrent()) {
                    $current = (string)$lang['lang_abbr'];
                }
            } else {
                $default = (string)$lang['lang_abbr'];
            }
        }
        $visible = fn(int $id): bool => $map->getTree() && $map->getTree()->getNodeById($id) && $map->getDocumentRights($id) > ACCESS_NONE;
        $pageOf = function (array $segments) use ($map, $visible): ?int {
            $id = $map->findIDByPath($segments);
            return ($id !== null && $visible($id)) ? $id : null;
        };
        // старые адреса — одним запросом на весь запрос и только при первой ссылке, не найденной в дереве
        $all = null;
        $oldTarget = function (array $segments) use ($aliases, $map, &$all): ?array {
            $hit = $segments ? PageAliases::match($all ??= $aliases->all(), $segments) : null;
            if ($hit === null || !$map->getTree() || !$map->getTree()->getNodeById($hit['id'])) {
                return null;
            }
            return array_merge(array_values(array_filter(explode('/', (string)$map->getURLByID($hit['id'])), fn(string $s) => $s !== '')),
                $hit['rest']);
        };
        return $instance = new self($pageOf, $oldTarget, HTDOCS_DIR, (string)$site->root, (string)parse_url($site->base, PHP_URL_HOST),
            $prefixes, $current, $default);
    }

    /**
     * Почему ссылка битая для этого посетителя: 'page' — страницы нет, 'file' — файла нет; null — рабочая или не
     * проверяется.
     */
    public function reason(string $link): ?string {
        if (array_key_exists($link, $this->reasons)) {
            return $this->reasons[$link];
        }
        return $this->reasons[$link] = $this->check($link);
    }

    /**
     * Текст с обработанными битыми ссылками: $mark — пометка и подсказка (администратор), иначе ссылка заменяется своим
     * содержимым, картинка без файла удаляется (посетитель). Без находок — та же строка.
     *
     * @param array{page?: string, file?: string} $titles подсказки по причинам
     */
    public function filter(string $html, bool $mark, array $titles): string {
        // сначала адреса — регулярным выражением: без находок текст не разбирается вовсе
        if (!preg_match_all('~\b(?:href|src)\s*=\s*(["\'])(.*?)\1~is', $html, $m)
            || !array_filter(array_unique($m[2]), fn(string $link) => $this->reason($link) !== null)) {
            return $html;
        }
        $doc = new \DOMDocument('1.0', 'UTF-8');
        $errors = libxml_use_internal_errors(true);
        $loaded = $doc->loadHTML('<?xml encoding="UTF-8"?><div id="e-text-links-root">' . $html . '</div>',
            LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD | LIBXML_NONET);
        libxml_clear_errors();
        libxml_use_internal_errors($errors);
        $xp = new \DOMXPath($doc);
        $root = $loaded ? $xp->query('//div[@id="e-text-links-root"]')->item(0) : null;
        // непарный закрывающий тег (</div>) закрыл бы обёртку раньше конца текста — остаток лёг бы рядом с ней и пропал:
        // такой текст отдаётся как есть (рядом с обёрткой бывает только инструкция xml encoding разбора)
        if (!$root || $root !== $doc->documentElement) {
            return $html;
        }
        for ($node = $doc->firstChild; $node; $node = $node->nextSibling) {
            if ($node !== $root && $node->nodeType !== XML_PI_NODE
                && !($node->nodeType === XML_TEXT_NODE && trim($node->textContent) === '')) {
                return $html;
            }
        }
        $changed = false;
        foreach (iterator_to_array($xp->query('.//a[@href]', $root)) as $a) {
            /** @var \DOMElement $a */
            if (!($why = $this->reason($a->getAttribute('href')))) {
                continue;
            }
            $changed = true;
            if ($mark) {
                self::markAs($a, 'e-broken-link', (string)($titles[$why] ?? ''));
            } else {
                while ($a->firstChild) {
                    $a->parentNode->insertBefore($a->firstChild, $a);
                }
                $a->parentNode->removeChild($a);
            }
        }
        foreach (iterator_to_array($xp->query('.//img[@src]', $root)) as $img) {
            /** @var \DOMElement $img */
            if ($this->reason($img->getAttribute('src')) !== 'file') {
                continue;
            }
            $changed = true;
            if ($mark) {
                self::markAs($img, 'e-broken-image', (string)($titles['file'] ?? ''));
            } else {
                $img->parentNode->removeChild($img);
            }
        }
        if (!$changed) {
            return $html;
        }
        $out = '';
        foreach ($root->childNodes as $node) {
            $out .= $doc->saveHTML($node);
        }
        return $out;
    }

    private function check(string $link): ?string {
        $link = trim(html_entity_decode($link, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
        if ($link === '' || $link[0] === '#' || preg_match('~^(mailto|tel|javascript|data|sms|skype|callto):~i', $link)) {
            return null;
        }
        if (preg_match('~^(?:https?:)?//([^/?#]+)(.*)$~i', $link, $m)) {
            if (strcasecmp((string)preg_replace('~:\d+$~', '', $m[1]), $this->host) !== 0) {
                return null; // другой сайт
            }
            $link = $m[2] === '' ? '/' : $m[2];
        } elseif (preg_match('~^[a-z][a-z0-9+.-]*:~i', $link)) {
            return null; // другая схема
        }
        $path = rawurldecode((string)preg_replace('~[?#].*$~s', '', $link));
        if (str_starts_with($path, '/')) {
            if (!str_starts_with($path . '/', $this->root) && $path !== rtrim($this->root, '/')) {
                return null; // вне корня сайта
            }
            $path = substr($path, strlen($this->root));
        }
        // относительный путь — от корня сайта (<base href>); «..» выше корня не уходит
        $parts = [];
        foreach (explode('/', $path) as $part) {
            if ($part === '..') {
                array_pop($parts);
            } elseif ($part !== '.' && $part !== '') {
                $parts[] = $part;
            }
        }
        $last = end($parts);
        $isFile = !($path === '' || str_ends_with($path, '/')) && $last !== false && str_contains($last, '.');
        if ($isFile) {
            // файл; адрес ресайзера (resizer/wШ-hВ/путь) — по файлу-источнику
            $file = $parts;
            if (($file[0] ?? '') === 'resizer' && isset($file[1]) && preg_match('~^w\d+-h\d+$~', $file[1])) {
                $file = array_slice($file, 2);
            }
            if (is_file($this->webDir . '/' . implode('/', $file))) {
                return null;
            }
        }
        // страница; файла нет — может, это страница с точкой в сегменте (robots.txt, sitemap.xml)
        $page = $this->page($parts);
        if ($isFile) {
            return $page === 'found' ? null : 'file';
        }
        return $page === 'missing' ? 'page' : null;
    }

    /**
     * Страница по сегментам адреса: 'found' — видна посетителю (сразу или по старому адресу), 'other' — другой язык
     * (не проверяется), 'missing' — нет.
     *
     * @param string[] $parts
     */
    private function page(array $parts): string {
        if ($parts && $this->defaultAbbr !== '' && $parts[0] === $this->defaultAbbr) {
            array_shift($parts); // язык по умолчанию явно: /ru/info/ — та же страница, что /info/
            $prefix = '';
        } else {
            $prefix = ($parts && in_array($parts[0], $this->langPrefixes, true)) ? array_shift($parts) : '';
        }
        if ($prefix !== $this->currentPrefix) {
            return 'other'; // другой язык: его дерево не загружено
        }
        if (($this->pageOf)($parts) !== null) {
            return 'found';
        }
        $target = ($this->oldTarget)($parts);
        return ($target !== null && ($this->pageOf)($target) !== null) ? 'found' : 'missing';
    }

    private static function markAs(\DOMElement $el, string $class, string $title): void {
        $el->setAttribute('class', trim($el->getAttribute('class') . ' ' . $class));
        if ($title !== '') {
            $el->setAttribute('title', $title);
        }
    }
}
