<?php
// Страница-ссылка (идея xsight): у поля «адрес переадресации» формы раздела — кнопки выбора страницы из дерева и файла
// из репозитория; пункт меню и списка подразделов на внешний адрес (http(s):// другого сайта) открывается в новой
// вкладке (target="_blank" rel="noopener"), внутренний (от корня или полный адрес этого сайта) — в той же.
// Стенд: страницы в меню claude-pl-ext (https://example.com/claude), claude-pl-int (/info/), claude-pl-own (полный
// адрес этого сайта), раздел claude-pl (не в меню) с подстраницей claude-pl/ext2 (https://example.com/claude2);
// всё удаляется в конце.
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
const MENU = "//*[contains(concat(' ', normalize-space(@class), ' '), ' main_menu ')]";
const LIST_ITEMS = "//li[contains(concat(' ', normalize-space(@class), ' '), ' menu_item ')]";

try {
    login();
    $ext = savePage(null, $ROOT, 'claude-pl-ext', ['redirect' => 'https://example.com/claude', 'menu' => '1']);
    $int = savePage(null, $ROOT, 'claude-pl-int', ['redirect' => '/info/', 'menu' => '1']);
    $self = savePage(null, $ROOT, 'claude-pl-own', ['redirect' => $own, 'menu' => '1']);
    $section = savePage(null, $ROOT, 'claude-pl', ['content' => 'childs.content.xml']);
    $ext2 = $section ? savePage(null, $section, 'ext2', ['redirect' => 'https://example.com/claude2', 'menu' => '1']) : null;
    if (!check('стенд: внешняя, внутренняя, полный адрес этого сайта в меню; раздел с внешней подстраницей',
        $ext && $int && $self && $section && $ext2)) {
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
    [$c, $list] = http('/claude-pl/');
    check('список подразделов: внешний адрес — новая вкладка', $c == 200 && $newTab(linkAttrs($list, LIST_ITEMS, 'https://example.com/claude2')),
        "HTTP $c " . json_encode(linkAttrs($list, LIST_ITEMS, 'https://example.com/claude2')));
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    // подстраницы, переводы, права удаляются каскадом
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment IN ('claude-pl-ext', 'claude-pl-int', 'claude-pl-own', 'claude-pl')", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('page-link');
