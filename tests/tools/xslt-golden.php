<?php
// Сверка вывода шаблонов XSLT «до/после» (UI-подпроект 4): чистка шаблонов не должна менять HTML, кроме задуманного.
//   php8.5 tests/tools/xslt-golden.php capture DIR      — XML набора страниц (?debug, на площадке site.debug включён):
//                                                          гость и администратор, страницы сайта, формы, гриды
//   php8.5 tests/tools/xslt-golden.php compare DIR REV  — каждый XML преобразуется шаблонами ревизии REV (git archive)
//                                                          и текущими; разница HTML — в вывод
// XSLT_GOLDEN_IGNORE='регулярное выражение' — убирается из обоих выводов (задуманная разница, например снятый класс).
// Выход: 0 — без разницы (capture — снято), 1 — есть разница, 2 — не выполнено.
require dirname(__DIR__) . '/testlib.php';

[, $cmd, $dir, $rev] = $argv + [null, null, null, null];
if (!$cmd || !$dir) { fwrite(STDERR, "capture DIR | compare DIR REV\n"); exit(2); }

const TRANSFORMERS = ['core/modules/share/transformers', 'core/modules/user/transformers', 'core/modules/seo/transformers',
    'site/modules/main/transformers'];

if ($cmd === 'capture') {
    @mkdir($dir, 0700, true);
    $user = (int)scalar("SELECT u_id FROM user_users ORDER BY u_id LIMIT 1");
    $page = (int)scalar("SELECT q.smap_id FROM share_sitemap q JOIN share_sitemap i ON i.smap_id = q.smap_pid
        WHERE q.smap_segment = 'quick-start' AND i.smap_segment = 'info'");
    $guest = ['', 'info/quick-start/', 'service/', 'contacts/', 'login/', 'register/', 'restore-password/', 'sitemap/', 'ua/'];
    $admin = ['', 'info/quick-start/', 'admin/users/', 'admin/users/single/userEditor/add/', "admin/users/single/userEditor/$user/edit/",
        "admin/structure/single/divEditor/$page/edit/", "admin/structure/single/divEditor/add/$page/", 'admin/mail-templates/single/mailTemplateEditor/1/edit/',
        'admin/translations/', 'admin/settings/single/siteSettings/1/edit/', 'admin/users/single/adminPanel/file-library/'];
    $n = 0;
    foreach (['guest' => $guest, 'admin' => $admin] as $who => $urls) {
        $who === 'admin' ? login() : logout();
        foreach ($urls as $u) {
            [$code, $body] = http('/' . $u . '?debug');
            if ($code != 200 || !str_starts_with(ltrim($body), '<?xml')) { fwrite(STDERR, "$who /$u: $code\n"); exit(2); }
            file_put_contents("$dir/$who-" . (preg_replace('~[^a-z0-9]+~', '-', $u) ?: 'home') . '.xml', $body);
            $n++;
        }
    }
    logout();
    echo "снято: $n\n";
    exit(0);
}

if ($cmd !== 'compare' || !$rev || !is_dir($dir)) { fwrite(STDERR, "нет каталога $dir или ревизии\n"); exit(2); }
$old = sys_get_temp_dir() . '/xslt-golden-' . getmypid();
mkdir($old, 0700);
register_shutdown_function(fn() => exec('rm -rf ' . escapeshellarg($old)));
exec('cd ' . escapeshellarg(ROOT) . ' && git archive ' . escapeshellarg($rev) . ' -- ' . implode(' ', TRANSFORMERS)
    . ' | tar -x -C ' . escapeshellarg($old), $o, $rc);
if ($rc) { fwrite(STDERR, "git archive $rev\n"); exit(2); }

function render(string $root, string $xmlFile): string {
    $x = new DOMDocument('1.0', 'UTF-8');
    $x->load("$root/site/modules/main/transformers/main.xslt");
    $p = new XSLTProcessor();
    $p->importStylesheet($x);
    $d = new DOMDocument('1.0', 'UTF-8');
    $d->load($xmlFile);
    $html = (string)$p->transformToXml($d);
    // generate-id() и токены зависят от прогона, пробелы — от форматирования шаблона
    $html = preg_replace('~\bid[a-z]{0,2}\d{5,}\b~', 'ID', $html);
    $html = preg_replace('~[a-f0-9]{64}~', 'TOKEN', $html);
    if ($ignore = getenv('XSLT_GOLDEN_IGNORE')) $html = preg_replace($ignore, '', $html);
    return trim(preg_replace('~\s+~', ' ', preg_replace('~>\s+<~', '><', $html)));
}

$diff = 0;
foreach (glob("$dir/*.xml") as $f) {
    $a = render($old, $f);
    $b = render(ROOT, $f);
    if ($a === $b) continue;
    $diff++;
    // первая разница: по 160 знаков вокруг
    $i = 0; $n = min(strlen($a), strlen($b));
    while ($i < $n && $a[$i] === $b[$i]) $i++;
    $from = max(0, $i - 80);
    echo basename($f) . ":\n  было:  " . substr($a, $from, 240) . "\n  стало: " . substr($b, $from, 240) . "\n";
}
echo "== xslt-golden: страниц с разницей $diff\n";
exit($diff ? 1 : 0);
