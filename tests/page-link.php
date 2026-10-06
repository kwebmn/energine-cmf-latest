<?php
// Страница-ссылка (идея xsight): у поля «адрес переадресации» формы раздела — кнопки выбора страницы из дерева и файла
// из репозитория; пункт меню и списка подразделов на внешний адрес (http(s):// другого сайта) открывается в новой
// вкладке (target="_blank" rel="noopener"), внутренний (от корня или полный адрес этого сайта) — в той же.
// Стенд: страницы в меню claude-pl-ext (https://example.com/claude), claude-pl-int (/info/), claude-pl-own (полный
// адрес этого сайта), раздел claude-pl (не в меню) с подстраницей claude-pl/ext2 (https://example.com/claude2);
// на втором языке (ревью этапа): страница-ссылка на страницу сайта от корня ведёт на ту же страницу этого языка, если
// она на нём открыта (claude-pl-toru → claude-pl-ruonly, выключенная на втором языке, — как есть), на файл
// (claude-pl-file) — как есть. Всё удаляется в конце.
require __DIR__ . '/testlib.php';

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
$own = rtrim(BASE, '/') . '/info/';

// target и rel ссылки с адресом $href внутри элементов $scope (XPath) страницы; null — такой ссылки нет
function linkAttrs(string $html, string $scope, string $href): ?array {
    $d = new DOMDocument();
    @$d->loadHTML('<?xml encoding="UTF-8">' . $html);
    foreach ((new DOMXPath($d))->query($scope . '//a[@href]') as $a) {
        if ($a->getAttribute('href') === $href) {
            return ['target' => $a->getAttribute('target'), 'rel' => $a->getAttribute('rel')];
        }
    }
    return null;
}
$newTab = fn(?array $a) => $a !== null && $a['target'] === '_blank' && in_array('noopener', preg_split('/\s+/', $a['rel']), true);
$sameTab = fn(?array $a) => $a !== null && $a['target'] === '' && $a['rel'] === '';
// код ответа и Location без перехода по нему (гость)
function redirectOf(string $path): array {
    $ch = curl_init(BASE . $path);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_FOLLOWLOCATION => false, CURLOPT_TIMEOUT => 60]);
    $raw = (string)curl_exec($ch);
    $location = preg_match('~^Location:\s*(\S+)~mi', $raw, $m) ? $m[1] : '';
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), str_starts_with($location, BASE) ? '/' . ltrim(substr($location, strlen(BASE)), '/') : $location];
}
$abbr = (string)scalar('SELECT lang_abbr FROM share_languages WHERE lang_default = 0 ORDER BY lang_id LIMIT 1');
$otherLang = (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 0 ORDER BY lang_id LIMIT 1');
const MENU = "//*[contains(concat(' ', normalize-space(@class), ' '), ' main_menu ')]";
const LIST_ITEMS = "//li[contains(concat(' ', normalize-space(@class), ' '), ' menu_item ')]";

try {
    login();
    $ext = savePage(null, $ROOT, 'claude-pl-ext', ['redirect' => 'https://example.com/claude', 'menu' => '1']);
    $int = savePage(null, $ROOT, 'claude-pl-int', ['redirect' => '/info/', 'menu' => '1']);
    $self = savePage(null, $ROOT, 'claude-pl-own', ['redirect' => $own, 'menu' => '1']);
    $section = savePage(null, $ROOT, 'claude-pl', ['content' => 'childs.content.xml']);
    $ext2 = $section ? savePage(null, $section, 'ext2', ['redirect' => 'https://example.com/claude2', 'menu' => '1']) : null;
    $file = savePage(null, $ROOT, 'claude-pl-file', ['redirect' => '/uploads/public/claude-pl.pdf', 'menu' => '1']);
    $ruOnly = savePage(null, $ROOT, 'claude-pl-ruonly', ['disabled' => [$otherLang => 1]]);
    $toRu = savePage(null, $ROOT, 'claude-pl-toru', ['redirect' => '/claude-pl-ruonly/', 'menu' => '1']);
    if (!check('стенд: внешняя, внутренняя, полный адрес этого сайта в меню; раздел с внешней подстраницей; ссылки на файл и на страницу только основного языка',
        $ext && $int && $self && $section && $ext2 && $file && $ruOnly && $toRu)) {
        throw new RuntimeException('стенд не создан');
    }

    // форма раздела: поле адреса и кнопки выбора — в правке и при добавлении
    foreach (["/admin/structure/single/divEditor/$ext/edit/" => 'https://example.com/claude', "/admin/structure/single/divEditor/add/$ROOT/" => ''] as $url => $value) {
        [$c, $html] = http($url);
        $d = new DOMDocument();
        @$d->loadHTML('<?xml encoding="UTF-8">' . $html);
        $x = new DOMXPath($d);
        $input = $x->query("//input[@id='smap_redirect_url']")->item(0);
        $page = $x->query("//button[contains(@class, 'pick-redirect-page')]")->item(0);
        $file = $x->query("//button[contains(@class, 'pick-redirect-file')]")->item(0);
        $texts = [$page ? trim($page->textContent) : '', $file ? trim($file->textContent) : ''];
        check("форма раздела ($url): поле адреса переадресации и кнопки «Страница…», «Файл…»", $c == 200 && $input
            && $input->getAttribute('value') === $value && $input->getAttribute('name') === 'share_sitemap[smap_redirect_url]'
            && $texts[0] !== '' && $texts[1] !== '' && !preg_grep('/^BTN_/', $texts), "HTTP $c " . implode(' | ', $texts));
    }
    logout();

    // гость: меню главной и список подразделов
    [$c, $home] = http('/');
    check('меню: внешний адрес — новая вкладка (target="_blank" rel="noopener")', $newTab(linkAttrs($home, MENU, 'https://example.com/claude')),
        json_encode(linkAttrs($home, MENU, 'https://example.com/claude')));
    check('меню: адрес от корня сайта (/info/) — та же вкладка', $sameTab(linkAttrs($home, MENU, '/info/')), json_encode(linkAttrs($home, MENU, '/info/')));
    check('меню: полный адрес этого сайта — та же вкладка', $sameTab(linkAttrs($home, MENU, $own)), json_encode(linkAttrs($home, MENU, $own)));
    check('меню: обычный пункт (раздел /info/ сайта) — без target', $sameTab(linkAttrs($home, MENU, 'info/')), json_encode(linkAttrs($home, MENU, 'info/')));
    // второй язык: страница сайта — на её версию этого языка, файл и страница, выключенная на нём, — как есть
    if ($abbr !== '') {
        [$c, $uaHome] = http("/$abbr/");
        check("второй язык, меню: страница-ссылка на /info/ ведёт на /$abbr/info/", $c == 200 && linkAttrs($uaHome, MENU, "/$abbr/info/") !== null
            && linkAttrs($uaHome, MENU, '/info/') === null, "HTTP $c");
        check('второй язык, меню: страница-ссылка на файл — адрес файла как есть', linkAttrs($uaHome, MENU, '/uploads/public/claude-pl.pdf') !== null);
        check('второй язык, меню: страница, выключенная на этом языке, — адрес основного языка как есть',
            linkAttrs($uaHome, MENU, '/claude-pl-ruonly/') !== null);
        check('второй язык, меню: внешний адрес — как есть, новая вкладка', $newTab(linkAttrs($uaHome, MENU, 'https://example.com/claude')));
        [$c, $loc] = redirectOf("/$abbr/claude-pl-int/");
        check("второй язык: заход на страницу-ссылку — переадресация на /$abbr/info/", in_array($c, [301, 302]) && $loc === "/$abbr/info/", "HTTP $c → $loc");
        [$c, $loc] = redirectOf('/claude-pl-int/');
        check('основной язык: заход на страницу-ссылку — переадресация на /info/', in_array($c, [301, 302]) && $loc === '/info/', "HTTP $c → $loc");
    }
    [$c, $list] = http('/claude-pl/');
    check('список подразделов: внешний адрес — новая вкладка', $c == 200 && $newTab(linkAttrs($list, LIST_ITEMS, 'https://example.com/claude2')),
        "HTTP $c " . json_encode(linkAttrs($list, LIST_ITEMS, 'https://example.com/claude2')));
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    // подстраницы, переводы, права удаляются каскадом
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment IN ('claude-pl-ext', 'claude-pl-int', 'claude-pl-own', 'claude-pl',
        'claude-pl-file', 'claude-pl-ruonly', 'claude-pl-toru')", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('page-link');
