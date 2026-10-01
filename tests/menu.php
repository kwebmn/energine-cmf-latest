<?php
// Главное меню строится по флагу страницы «Показывать в меню» (share_sitemap.smap_in_menu):
//  1. гость видит на / и /ua/ ровно корневые страницы с флагом, открытые гостю, в порядке дерева;
//     вход, восстановление пароля, robots.txt и google-sitemap в меню не попадают;
//  2. снятый флаг убирает страницу из меню, возвращённый — возвращает (исходное значение
//     восстанавливается и при падении теста);
//  3. форма новой страницы в админке включает флаг по умолчанию, а снятый в форме правки флажок
//     сохраняется и убирает страницу из меню;
//  4. администратор видит в меню подразделы админки с флагом.
require __DIR__ . '/testlib.php';

$hasFlag = (bool)scalar("SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'smap_in_menu'");
if (!check('колонка share_sitemap.smap_in_menu есть', $hasFlag)) done('menu');

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$admin = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_pid = ? AND smap_segment = 'admin'", [$root]);
$guestGroup = (int)scalar('SELECT group_id FROM user_groups WHERE group_default = 1');
const SERVICE = ['login', 'restore-password', 'robots.txt', 'google-sitemap'];

// ссылки главного меню: первый уровень или подпункты раздела $parent; адрес без языка и косой черты
function menu(string $html, ?string $parent = null): array {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $xp = new DOMXPath($doc);
    $ul = "ul[contains(concat(' ', normalize-space(@class), ' '), ' main_menu ')]";
    $query = $parent === null
        ? "(//{$ul}[not(ancestor::{$ul})])[1]/li/a/@href"
        : "(//{$ul}[not(ancestor::{$ul})])[1]/li[a[@href='$parent/' or @href='ua/$parent/']]/{$ul}/li/a/@href";
    $items = [];
    foreach ($xp->query($query) as $href) $items[] = trim(preg_replace('~^ua/~', '', $href->value), '/');
    return $items;
}
function guestMenu(int $root, int $group, int $lang): array {
    return q('SELECT s.smap_segment FROM share_sitemap s
        JOIN share_access_level a ON a.smap_id = s.smap_id AND a.group_id = ? AND a.right_id > 0
        JOIN share_sitemap_translation t ON t.smap_id = s.smap_id AND t.lang_id = ? AND t.smap_is_disabled = 0
        WHERE s.smap_pid = ? AND s.smap_in_menu = 1 ORDER BY s.smap_order_num', [$group, $lang, $root])
        ->fetchAll(PDO::FETCH_COLUMN);
}

// 1. меню гостя на обоих языках
logout();
foreach (q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_order_num')->fetchAll() as $l) {
    $path = $l['lang_default'] ? '/' : '/' . $l['lang_abbr'] . '/';
    [$code, $html] = http($path);
    $got = menu($html);
    $want = guestMenu($root, $guestGroup, (int)$l['lang_id']);
    check("меню гостя $path — страницы с флагом: " . implode(' ', $want), $code == 200 && $want && $got === $want,
        "HTTP $code, в меню: " . implode(' ', $got));
    check("служебных страниц в меню гостя $path нет", !array_intersect(SERVICE, $got), implode(' ', array_intersect(SERVICE, $got)));
}

// 2. флаг у «Информации»
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_pid = ? AND smap_segment = 'info'", [$root]);
$orig = (int)scalar('SELECT smap_in_menu FROM share_sitemap WHERE smap_id = ?', [$info]);
register_shutdown_function(fn() => q('UPDATE share_sitemap SET smap_in_menu = ? WHERE smap_id = ?', [$orig, $info]));
q('UPDATE share_sitemap SET smap_in_menu = 0 WHERE smap_id = ?', [$info]);
[, $html] = http('/');
check('снятый флаг убирает «Информацию» из меню', !in_array('info', menu($html)), implode(' ', menu($html)));
q('UPDATE share_sitemap SET smap_in_menu = 1 WHERE smap_id = ?', [$info]);
[, $html] = http('/');
check('возвращённый флаг возвращает «Информацию» в меню', in_array('info', menu($html)), implode(' ', menu($html)));
q('UPDATE share_sitemap SET smap_in_menu = ? WHERE smap_id = ?', [$orig, $info]);

// 3. форма новой страницы
login();
[$code, $html] = http("/admin/structure/single/divEditor/add/$root/");
$doc = new DOMDocument();
libxml_use_internal_errors(true);
$doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
libxml_clear_errors();
$box = (new DOMXPath($doc))->query("//input[@type='checkbox'][@name='share_sitemap[smap_in_menu]']")->item(0);
check('в форме новой страницы флаг «в меню» включён', $code == 200 && $box && $box->hasAttribute('checked'),
    $box ? 'флаг выключен' : "HTTP $code, флага в форме нет");
[$code, $html] = http("/admin/structure/single/divEditor/$info/edit/");
[, $j] = json('/admin/structure/single/divEditor/save', formData($html, ['share_sitemap[smap_in_menu]' => '0']));
check('флажок, снятый в форме правки, сохраняется', !empty($j['result'])
    && (int)scalar('SELECT smap_in_menu FROM share_sitemap WHERE smap_id = ?', [$info]) === 0, json_encode($j, JSON_UNESCAPED_UNICODE));
logout();
[, $html] = http('/');
check('страница со снятым в форме флажком не в меню гостя', !in_array('info', menu($html)), implode(' ', menu($html)));
q('UPDATE share_sitemap SET smap_in_menu = ? WHERE smap_id = ?', [$orig, $info]);
login();

// 4. подменю админки у администратора
[, $html] = http('/');
$want = q("SELECT CONCAT('admin/', smap_segment) FROM share_sitemap WHERE smap_pid = ? AND smap_in_menu = 1 ORDER BY smap_order_num", [$admin])
    ->fetchAll(PDO::FETCH_COLUMN);
$got = menu($html, 'admin');
check('подменю админки — подразделы с флагом: ' . implode(' ', $want), $want && $got === $want, 'в меню: ' . implode(' ', $got));

done('menu');
