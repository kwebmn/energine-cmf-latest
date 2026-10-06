<?php
// Переключатель языка без 404 (идея xsight): ссылка на другой язык ведёт на ту же страницу, только если она открыта на
// том языке (сама и все её родители не выключены); иначе, и на странице ошибки (404, 403, 422) — на главную языка.
// Хвост пути доступной страницы сохраняется. Стенд: claude-ls (включена на ru, выключена на ua), её подстраница
// claude-ls/child (включена на обоих), claude-ls2 (выключена на ru, включена на ua), claude-ls-closed (только
// администраторам); всё удаляется в конце.
require __DIR__ . '/testlib.php';

$langs = q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_default DESC, lang_id')->fetchAll();
if (count($langs) < 2) {
    check('на площадке два языка', false);
    done('lang-switcher');
}
[$def, $other] = [(int)$langs[0]['lang_id'], (int)$langs[1]['lang_id']];
$abbr = $langs[1]['lang_abbr'];
$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();

// адрес ссылки переключателя на другой язык (у текущего языка ссылки нет), от корня сайта: «/ua/info/», «/»
function switchTo(string $body): ?string {
    preg_match_all('~<li class="lang_switcher_item">.*?</li>~su', $body, $m);
    foreach ($m[0] as $li) {
        if (preg_match('~<a[^>]*\shref="([^"]*)"~', $li, $h)) {
            $href = html_entity_decode($h[1]);
            return '/' . ltrim(str_starts_with($href, BASE) ? substr($href, strlen(BASE)) : $href, '/');
        }
    }
    return null;
}

try {
    login();
    $ls = savePage(null, $ROOT, 'claude-ls', ['disabled' => [$other => 1]]);
    $child = $ls ? savePage(null, $ls, 'child') : null;
    $ls2 = savePage(null, $ROOT, 'claude-ls2', ['disabled' => [$def => 1]]);
    $closed = savePage(null, $ROOT, 'claude-ls-closed', ['rights' => [1 => 3]]);
    if (!check('стенд: страница выключена на втором языке, её подстраница, страница выключена на основном, закрытая гостю',
        $ls && $child && $ls2 && $closed)) {
        throw new RuntimeException('стенд не создан');
    }

    // администратор: хвост пути доступной страницы (окно добавления языка) сохраняется
    [$c, $b] = http('/admin/translations/languages/add/');
    check("хвост пути на доступной странице сохраняется: /admin/translations/languages/add/ → /$abbr/admin/translations/languages/add/",
        $c == 200 && switchTo($b) === "/$abbr/admin/translations/languages/add/", "HTTP $c → " . switchTo($b));
    logout();

    // гость
    [$c, $b] = http('/info/');
    check("страница открыта на обоих языках: /info/ → /$abbr/info/", $c == 200 && switchTo($b) === "/$abbr/info/", "HTTP $c → " . switchTo($b));
    [$c, $b] = http('/claude-ls/');
    check("страница выключена на втором языке: /claude-ls/ → /$abbr/", $c == 200 && switchTo($b) === "/$abbr/", "HTTP $c → " . switchTo($b));
    [$c] = http("/$abbr/claude-ls/child/");
    check("подстраница выключенной: /$abbr/claude-ls/child/ — 404 (предпосылка)", $c == 404, "HTTP $c");
    [$c, $b] = http('/claude-ls/child/');
    check("выключен родитель на втором языке: /claude-ls/child/ → /$abbr/", $c == 200 && switchTo($b) === "/$abbr/", "HTTP $c → " . switchTo($b));
    [$c, $b] = http("/$abbr/claude-ls2/");
    check("страница выключена на основном языке: /$abbr/claude-ls2/ → /", $c == 200 && switchTo($b) === '/', "HTTP $c → " . switchTo($b));
    [$c, $b] = http('/claude-ls-nope/');
    check("страница 404: /claude-ls-nope/ → /$abbr/", $c == 404 && switchTo($b) === "/$abbr/", "HTTP $c → " . switchTo($b));
    [$c, $b] = http('/claude-ls-closed/');
    check("страница, закрытая гостю (403 или 404): /claude-ls-closed/ → /$abbr/", in_array($c, [403, 404]) && switchTo($b) === "/$abbr/",
        "HTTP $c → " . switchTo($b));
    [$c, $b] = http('/info/', ['x' => '1'], ['X-CSRF-Token: claude-wrong']);
    check("страница ошибки не 404 (форма без токена, 422): /info/ → /$abbr/", $c == 422 && switchTo($b) === "/$abbr/", "HTTP $c → " . switchTo($b));
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    // подстраницы, переводы, права удаляются каскадом
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment IN ('claude-ls', 'claude-ls2', 'claude-ls-closed')", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('lang-switcher');
