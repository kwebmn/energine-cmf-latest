<?php
// Router for PHP's built-in server — the rules of starter/jambalaya/.nginx.conf.example:
// dot-files and *.xml/*.xslt are not served, the resizer address goes to timthumb.php,
// existing files are served as they are, everything else goes to index.php.
$root = $_SERVER['DOCUMENT_ROOT'];
$path = rawurldecode((string)parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));
if (preg_match('~(^|/)\.|\.(xml|xslt)$~i', $path)) {
    http_response_code(403);
    return true;
}
if (preg_match('~^/resizer/w([0-9]+)-h([0-9]+)/(.*)$~', $path, $m)) {
    $_GET = ['w' => $m[1], 'h' => $m[2], 'src' => $m[3], 'zc' => '2'];
    $_SERVER['QUERY_STRING'] = http_build_query($_GET);
    chdir($root . '/resizer');
    require $root . '/resizer/timthumb.php';
    return true;
}
if ($path !== '/' && is_file($root . $path)) {
    return false;
}
chdir($root);
require $root . '/index.php';
