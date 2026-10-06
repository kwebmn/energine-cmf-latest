<?php
// Битые ссылки в текстах на самой странице (идеи xsight): ссылка из текстового блока на страницу, которой нет для этого
// посетителя (нет совсем или закрыта от него), или на отсутствующий файл гостю выводится обычным текстом — без перехода
// на 404, отсутствующая картинка не выводится; администратору вне режима правки — ссылка с пометкой и причиной в
// подсказке; в режиме правки текст не меняется (редактор сохранил бы изменения). Рабочими остаются: видимые страницы,
// старые адреса (301), ссылки на другой язык (не проверяются), внешние, якоря, mailto:, файлы через ресайзер.
// Стенд: страницы claude-tl, claude-tl-closed (гостю закрыта), старый адрес claude-tl-old, файлы uploads/claude-tl/.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$INFO = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_pid = ? AND smap_segment = 'info'", [$ROOT]);
$DIR = WEB . '/uploads/claude-tl';
$html = '<p class="lead">Ссылки: <a href="/info/">рабочая</a> <a href="/claude-tl-nope/">битая <b>жирная</b></a> '
    . '<a href="/claude-tl-closed/">закрытая</a> <a href="/claude-tl-old/">старый адрес</a> '
    . '<a href="/uploads/claude-tl-missing.pdf">нет файла</a> <a href="/uploads/claude-tl/ok.pdf">есть файл</a> '
    . '<a href="https://example.com/">внешняя</a> <a href="mailto:a@example.com">почта</a> <a href="#top">якорь</a> '
    . '<a href="/ua/claude-tl-nope/">другой язык</a> <a href="/info/?x=1#y">с запросом</a> <a href="info/">относительная</a> '
    . '<a href="/claude-tl-old/quick-start/">старый адрес с хвостом</a> <a href="/ru/info/">с префиксом основного языка</a></p>'
    . '<p><img src="/uploads/claude-tl-missing.jpg" alt="нет картинки"> <img src="/resizer/w10-h10/uploads/claude-tl/ok.jpg" alt="есть картинка"></p>'
    . '<p>Кириллица &amp; сущности&nbsp;тут<br>строка</p>';

// страница стенда целиком: гостем — без cookie, администратором — с банкой testlib
function page(string $path, bool $asAdmin): string {
    if ($asAdmin) {
        return http($path)[1];
    }
    $ch = curl_init(BASE . $path);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 60]);
    return (string)curl_exec($ch);
}
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
@mkdir($DIR, 0755, true);
file_put_contents("$DIR/ok.pdf", "%PDF-1.4\n");
$im = imagecreatetruecolor(20, 20);
imagejpeg($im, "$DIR/ok.jpg");
chmod("$DIR/ok.pdf", 0644);
chmod("$DIR/ok.jpg", 0644);
login();
try {
    $page = savePage(null, $ROOT, 'claude-tl');
    $closed = savePage(null, $ROOT, 'claude-tl-closed', ['rights' => [1 => 3]]);
    if (!check('стенд: страница с текстом и закрытая от гостя страница', $page && $closed)) {
        throw new RuntimeException('стенд не создан');
    }
    q('INSERT INTO share_sitemap_aliases (alias_path, smap_id) VALUES (?, ?)', ['claude-tl-old', $INFO]);
    q('INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, ?)', [$page, '1']);
    $tb = (int)scalar('SELECT tb_id FROM share_textblocks WHERE smap_id = ? AND tb_num = ?', [$page, '1']);
    q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, 1, ?)', [$tb, $html]);

    // 1. гость
    $g = page('/claude-tl/', false);
    foreach (['/info/', '/claude-tl-old/', '/uploads/claude-tl/ok.pdf', 'https://example.com/', 'mailto:a@example.com', '#top',
                 '/ua/claude-tl-nope/', '/info/?x=1#y', 'info/', '/claude-tl-old/quick-start/', '/ru/info/'] as $href) {
        check("гость: рабочая ссылка остаётся ссылкой — $href", str_contains($g, 'href="' . htmlspecialchars($href) . '"'));
    }
    foreach (['/claude-tl-nope/', '/claude-tl-closed/', '/uploads/claude-tl-missing.pdf'] as $href) {
        check("гость: битая или закрытая ссылка — текст без перехода — $href", !str_contains($g, 'href="' . $href . '"'));
    }
    check('гость: содержимое битой ссылки на месте (вместе с разметкой)', str_contains($g, 'битая <b>жирная</b>') && str_contains($g, 'закрытая')
        && str_contains($g, 'нет файла'));
    check('гость: отсутствующей картинки нет, рабочая — на месте', !str_contains($g, 'claude-tl-missing.jpg')
        && str_contains($g, '/resizer/w10-h10/uploads/claude-tl/ok.jpg'));
    check('гость: кириллица, сущности и переносы в тексте не искажены', str_contains($g, 'Кириллица &amp; сущности') && str_contains($g, 'строка')
        && str_contains($g, 'class="lead"'));
    check('гость: пометок для администратора нет', !str_contains($g, 'e-broken-'));

    // 2. администратор вне режима правки: ссылка с пометкой и причиной, закрытая страница ему открыта
    $a = page('/claude-tl/', true);
    check('администратор: битая ссылка — с пометкой e-broken-link и причиной в подсказке',
        (bool)preg_match('~<a[^>]*href="/claude-tl-nope/"[^>]*class="[^"]*e-broken-link[^"]*"[^>]*title="[^"]+"|<a[^>]*class="[^"]*e-broken-link[^"]*"[^>]*href="/claude-tl-nope/"~u', $a));
    check('администратор: нет файла — тоже с пометкой', (bool)preg_match('~<a[^>]*(?:href="/uploads/claude-tl-missing.pdf"[^>]*e-broken-link|e-broken-link[^>]*href="/uploads/claude-tl-missing.pdf")~u', $a));
    check('администратор: закрытая от гостя страница — обычная ссылка', (bool)preg_match('~<a href="/claude-tl-closed/">закрытая</a>~u', $a));
    check('администратор: отсутствующая картинка — с пометкой e-broken-image', (bool)preg_match('~<img[^>]*claude-tl-missing\.jpg[^>]*e-broken-image|<img[^>]*e-broken-image[^>]*claude-tl-missing\.jpg~u', $a));

    // 3. режим правки (при отладке — ?editMode): текст блока — как в базе, без пометок
    [$c, $xml] = http('/claude-tl/?editMode&debug');
    if (str_starts_with(ltrim($xml), '<?xml')) {
        $x = @simplexml_load_string($xml);
        $field = $x ? $x->xpath('//component[@sample="TextBlock" and @editable and @name="textBlock_1"]//field') : [];
        check('режим правки: текст блока в XML — ровно как в базе', $field && (string)$field[0] === $html,
            $field ? substr((string)$field[0], 0, 160) : 'блока нет');
    } else {
        echo "SKIP режим правки: отладка выключена, XML страницы недоступен\n";
    }

    // 4а. старые адреса читаются одним запросом, сколько бы ссылок ни нашлось вне дерева (бюджет запросов на страницу)
    $queries = function (string $content) use ($tb): int {
        q('UPDATE share_textblocks_translation SET tb_content = ? WHERE tb_id = ? AND lang_id = 1', [$content, $tb]);
        $ch = curl_init(BASE . '/claude-tl/?debug');
        curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 60]);
        $b = (string)curl_exec($ch);
        $x = str_starts_with(ltrim($b), '<?xml') ? @simplexml_load_string($b) : null;
        return $x && isset($x['queries']) ? (int)$x['queries'] : -1;
    };
    $one = $queries('<p><a href="/claude-tl-nope1/">a</a></p>');
    $three = $queries('<p><a href="/claude-tl-nope1/">a</a> <a href="/claude-tl-nope2/">b</a> <a href="/claude-tl-nope3/">c</a></p>');
    if ($one === -1) {
        echo "SKIP запросы: отладка выключена, XML страницы недоступен\n";
    } else {
        check('старые адреса — один запрос на страницу: три ссылки вне дерева стоят столько же, сколько одна', $three === $one,
            "одна: $one, три: $three");
    }

    // 4. TextLinks в консоли: причины по адресам и строка без находок — та же
    if (class_exists('Energine\share\gears\TextLinks')) {
        $pages = ['' => 1, 'info' => 2, 'info/quick-start' => 3, 'claude-seg.xml' => 4];
        // старый адрес old → info: замыкание отдаёт нынешний путь (с хвостом), его проверяет дерево
        $tl = new Energine\share\gears\TextLinks(fn(array $s) => $pages[implode('/', $s)] ?? null,
            fn(array $s) => ($s && $s[0] === 'old') ? array_merge(['info'], array_slice($s, 1)) : null,
            WEB, '/', parse_url(BASE, PHP_URL_HOST), ['ua'], '', 'ru');
        $cases = ['/' => null, '/info/' => null, 'info/quick-start/' => null, '/info/quick-start/?a=1#b' => null, BASE . '/info/' => null,
            '/nope/' => 'page', '/old/' => null, '/old/deeper/' => 'page', '/ua/nope/' => null, 'https://example.com/x/' => null, '#a' => null,
            'mailto:x@y.z' => null, 'tel:+1' => null, 'javascript:void(0)' => null, '/uploads/claude-tl/ok.pdf' => null,
            '/uploads/claude-tl/nope.pdf' => 'file', '/resizer/w1-h1/uploads/claude-tl/ok.jpg' => null, '/resizer/w1-h1/uploads/nope.jpg' => 'file',
            '/info/../nope/' => 'page', '' => null,
            // ревью этапа: старый адрес с хвостом, явный префикс основного языка, страница с точкой в сегменте
            '/old/quick-start/' => null, '/ru/info/' => null, '/ru/nope/' => 'page', '/claude-seg.xml' => null, '/nope.xml' => 'file'];
        foreach ($cases as $link => $want) {
            check('TextLinks::reason(' . var_export($link, true) . ') = ' . var_export($want, true), $tl->reason($link) === $want, var_export($tl->reason($link), true));
        }
        $clean = '<p>Нет <a href="/info/">ссылок</a> на ничто &amp; всё<br>хорошо</p>';
        check('filter без находок — строка та же', $tl->filter($clean, false, []) === $clean);
        check('filter без ссылок и картинок — строка та же', $tl->filter('<p>текст</p>', true, []) === '<p>текст</p>');
        // непарный </div> закрыл бы обёртку разбора — всё после него пропало бы: такой текст отдаётся как есть
        $unbalanced = '<p>до <a href="/nope/">битая</a></p></div><p>ПОСЛЕ</p><h2>Заголовок</h2>';
        $out = $tl->filter($unbalanced, false, []);
        check('filter: непарный </div> в тексте — ничего не теряется (текст как есть)', $out === $unbalanced, $out);
        // с находкой текст собирается заново: неразрывный пробел, <br />, сущности и кириллица — те же по смыслу
        $out = $tl->filter('<p><a href="/nope/">x</a> a&nbsp;b<br /> &amp; Ёж</p>', false, []);
        check('filter с находкой: &nbsp;, <br />, &amp; и кириллица сохранены', !str_contains($out, 'href')
            && (str_contains($out, "a\u{00A0}b") || str_contains($out, 'a&nbsp;b')) && (bool)preg_match('~<br\s*/?>~', $out)
            && str_contains($out, '&amp; Ёж'), $out);
    } else {
        check('гир TextLinks есть', false);
    }
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    q("DELETE FROM share_sitemap_aliases WHERE alias_path = 'claude-tl-old'");
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-tl', 'claude-tl-closed')");
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    @unlink("$DIR/ok.pdf");
    @unlink("$DIR/ok.jpg");
    @rmdir($DIR);
    logout();
}
done('text-links');
