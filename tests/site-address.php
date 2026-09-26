<?php
// Адрес сайта из конфига (site.domain, site.root): хост без порта, атрибут Domain для cookie, корень.
// Cookie с Domain=.127.0.0.1:8123 или Domain=.localhost браузер отбрасывает: для адреса с портом, IP
// и имени без точки cookie ставится без Domain — только для этого хоста.
require dirname(__DIR__) . '/vendor/autoload.php';

use Energine\share\gears\Site;

$fail = 0;
function check($label, $got, $want) {
    global $fail;
    $ok = $got === $want;
    echo ($ok ? 'OK   ' : 'FAIL '), $label, ($ok ? '' : ': ожидалось ' . var_export($want, true) . ', получено ' . var_export($got, true)), "\n";
    if (!$ok) $fail++;
}

check('hostOf: имя без порта', Site::hostOf('example.org'), 'example.org');
check('hostOf: порт отрезается', Site::hostOf('example.org:8080'), 'example.org');
check('hostOf: IP с портом', Site::hostOf('127.0.0.1:8123'), '127.0.0.1');
check('hostOf: регистр сохраняется', Site::hostOf('Example.ORG'), 'Example.ORG');

check('cookieDomainOf: имя хоста — .хост', Site::cookieDomainOf('example.org'), '.example.org');
check('cookieDomainOf: поддомен — .поддомен', Site::cookieDomainOf('simple.energine.org'), '.simple.energine.org');
check('cookieDomainOf: с портом — без Domain', Site::cookieDomainOf('example.org:8080'), '');
check('cookieDomainOf: IP — без Domain', Site::cookieDomainOf('10.0.0.1'), '');
check('cookieDomainOf: IP с портом — без Domain', Site::cookieDomainOf('127.0.0.1:8123'), '');
check('cookieDomainOf: имя без точки — без Domain', Site::cookieDomainOf('localhost'), '');
check('cookieDomainOf: пусто — без Domain', Site::cookieDomainOf(''), '');

check('normalizeRoot: пусто — /', Site::normalizeRoot(''), '/');
check('normalizeRoot: null — /', Site::normalizeRoot(null), '/');
check('normalizeRoot: / — /', Site::normalizeRoot('/'), '/');
check('normalizeRoot: sub — /sub/', Site::normalizeRoot('sub'), '/sub/');
check('normalizeRoot: /sub — /sub/', Site::normalizeRoot('/sub'), '/sub/');
check('normalizeRoot: /sub/ — /sub/', Site::normalizeRoot('/sub/'), '/sub/');
check('normalizeRoot: /a/b/ — /a/b/', Site::normalizeRoot('/a/b/'), '/a/b/');

echo "== site-address failures: $fail\n";
exit($fail ? 1 : 0);
