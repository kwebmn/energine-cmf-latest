<?php
// Код ответа страницы ошибки (надёжность 6, находка сравнения с xSight): HTML-страница, которую не удалось построить
// (ошибка базы, разработчика, критическая — здесь испорченный собственный XML страницы), отвечает 500, а не 200 —
// поисковик не примет её за страницу, мониторинг увидит сбой. Текст — общий, без путей сервера и SQL. Отказы 404 —
// как прежде; ответ JSON админки на ошибку базы — как прежде (200 с result: false).
// Стенд: страница claude-es со своим испорченным XML; удаляется в конце.
require __DIR__ . '/testlib.php';

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
$leak = '/SQLSTATE|PDOException|\/var\/www|\/private\/energine|Stack trace/i';

try {
    login();
    $page = savePage(null, $ROOT, 'claude-es');
    if (!check('стенд: страница claude-es', (bool)$page)) {
        throw new RuntimeException('стенд не создан');
    }
    // свой XML страницы — испорченный: построить её нельзя (ERR_BAD_STRUCTURE)
    q('UPDATE share_sitemap SET smap_content_xml = ? WHERE smap_id = ?', ['<content><container name="claude">', $page]);

    // JSON админки: ошибка базы (повтор константы) — как прежде, 200 с отказом
    [$code, $j] = json('/admin/translations/single/transEditor/save', http_build_query([
        'componentAction' => 'add', 'share_lang_tags' => ['ltag_id' => '', 'ltag_name' => 'TXT_HOME'],
        'share_lang_tags_translation' => [1 => ['ltag_value_rtf' => 'x'], 2 => ['ltag_value_rtf' => 'x']]]));
    check('JSON админки: ошибка базы — как прежде (200, result false)', $code == 200 && is_array($j) && empty($j['result']), "HTTP $code");
    logout();

    // гость
    [$code, $body] = http('/claude-es/');
    check('страница, которую нельзя построить, — код 500', $code == 500, "HTTP $code");
    // вне режима отладки — общий текст без путей и SQL; при отладке (демо) подробности показываются — так задумано
    $siteConfig = include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php');
    $debug = !empty($siteConfig['site']['debug']);
    check('страница ошибки 500 — с текстом' . ($debug ? ' (отладка включена: подробности видны)' : ', без путей сервера и SQL'),
        strlen(trim(strip_tags($body))) > 0 && ($debug || !preg_match($leak, $body)), substr(trim(strip_tags($body)), 0, 160));
    [$code] = http('/claude-es-nope-' . bin2hex(random_bytes(3)) . '/');
    check('неизвестный адрес — по-прежнему 404', $code == 404, "HTTP $code");
    [$code] = http('/');
    check('главная — 200', $code == 200, "HTTP $code");
    // ревью этапа: окно несуществующего компонента — «не найдено», а не сбой
    [$code] = http('/single/claudeNope' . bin2hex(random_bytes(2)) . '/');
    check('адрес окна несуществующего компонента (/single/…/) — 404, а не 500', $code == 404, "HTTP $code");
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment = 'claude-es'", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('error-status');
