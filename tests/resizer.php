<?php
// Ресайзер картинок (надёжность, этап 5): свой на GD вместо заброшенного timthumb; адрес тот же — /resizer/wШ-hВ/путь
// (правило веб-сервера ведёт на resizer/timthumb.php, его не меняем). Вид — как прежде (timthumb, zc=2): картинка
// вписана в Ш×В по центру с полями (у JPEG белые, у PNG/GIF/WebP прозрачные), нулевая сторона — по пропорции, обе
// нулевые — 100×100, не больше 1500×1500, маленькие увеличиваются, формат — как у исходника. Новое: кэш готовых
// картинок на диске, ETag и Last-Modified → 304, только картинки из uploads/ этого сайта — остальное 404 без текста
// ошибки. Стенд — каталог web/uploads/claude-resizer (картинки рисует GD), удаляется в конце вместе со своими записями
// кэша.
require __DIR__ . '/testlib.php';

$DIR = WEB . '/uploads/claude-resizer';
$REL = 'uploads/claude-resizer';
$CACHE = dirname(WEB) . '/tmp/energine-resizer'; // кэш ресайзера площадки (upload_tmp_dir пула PHP + energine-resizer)
$cacheBefore = is_dir($CACHE) ? scandir($CACHE) : [];

// запрос без cookie: код, заголовки (имена в нижнем регистре), тело
function fetch(string $path, array $headers = [], string $method = 'GET'): array {
    $ch = curl_init(BASE . $path);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_NOBODY => $method === 'HEAD', CURLOPT_HTTPHEADER => $headers, CURLOPT_TIMEOUT => 60]);
    $raw = (string)curl_exec($ch);
    $size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $h = [];
    foreach (explode("\r\n", substr($raw, 0, $size)) as $line) {
        if (str_contains($line, ':')) {
            [$k, $v] = explode(':', $line, 2);
            $h[strtolower(trim($k))] = trim($v);
        }
    }
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), $h, substr($raw, $size)];
}
// размеры и тип картинки из тела; пиксель (r, g, b, alpha 0–127)
function info(string $body): array {
    $i = @getimagesizefromstring($body);
    return $i ? [$i[0], $i[1], $i['mime']] : [0, 0, ''];
}
function px(string $body, int $x, int $y): array {
    $im = @imagecreatefromstring($body);
    if (!$im) return [-1, -1, -1, -1];
    $c = imagecolorsforindex($im, imagecolorat($im, $x, $y));
    return [$c['red'], $c['green'], $c['blue'], $c['alpha']];
}
function makeImage(string $file, int $w, int $h, array $rgb, string $type, bool $transparentBorder = false): void {
    $im = imagecreatetruecolor($w, $h);
    imagealphablending($im, false);
    imagesavealpha($im, true);
    imagefill($im, 0, 0, $transparentBorder ? imagecolorallocatealpha($im, 0, 0, 0, 127) : imagecolorallocate($im, ...$rgb));
    if ($transparentBorder) {
        imagefilledrectangle($im, (int)($w / 4), (int)($h / 4), (int)($w * 3 / 4), (int)($h * 3 / 4), imagecolorallocatealpha($im, ...[...$rgb, 0]));
    }
    match ($type) {
        'jpg' => imagejpeg($im, $file, 95),
        'png' => imagepng($im, $file),
        'gif' => imagegif($im, $file),
        'webp' => imagewebp($im, $file, 95),
    };
    chmod($file, 0644);
}
$ok = fn(int $code, string $body) => $code === 404 && !preg_match('~/var/www|Warning|Fatal|Stack trace|timthumb|SystemException~i', $body);

@mkdir($DIR, 0755, true);
try {
    makeImage("$DIR/wide.jpg", 400, 200, [255, 0, 0], 'jpg');
    makeImage("$DIR/small.jpg", 20, 10, [0, 160, 0], 'jpg');
    makeImage("$DIR/alpha.png", 100, 100, [0, 0, 255], 'png', true);
    makeImage("$DIR/pic.gif", 60, 30, [200, 200, 0], 'gif');
    makeImage("$DIR/pic.webp", 120, 60, [0, 0, 200], 'webp');
    file_put_contents("$DIR/fake.jpg", "not an image\n");
    @unlink("$DIR/link.jpg");
    symlink('/etc/hostname', "$DIR/link.jpg");
    @mkdir("$DIR/dir.jpg", 0755);

    // 1. вид — как у timthumb zc=2
    [$c, $h, $b] = fetch("/resizer/w40-h40/$REL/wide.jpg");
    [$w, $hh, $mime] = info($b);
    $top = px($b, 20, 2);
    $mid = px($b, 20, 20);
    check('wide.jpg 400×200 → w40-h40: JPEG 40×40, поля сверху белые, в центре картинка', $c === 200 && $mime === 'image/jpeg' && $w === 40 && $hh === 40
        && min(array_slice($top, 0, 3)) > 235 && $mid[0] > 200 && $mid[1] < 70 && $mid[2] < 70, json_encode([$c, $w, $hh, $mime, $top, $mid]));
    $etag = $h['etag'] ?? '';
    $lastModified = $h['last-modified'] ?? '';
    foreach ([['w100-h0', 100, 50], ['w0-h50', 100, 50], ['w0-h0', 100, 100]] as [$size, $ew, $eh]) {
        [$c, , $b] = fetch("/resizer/$size/$REL/wide.jpg");
        [$w, $hh] = info($b);
        check("wide.jpg → $size: {$ew}×{$eh}", $c === 200 && $w === $ew && $hh === $eh, json_encode([$c, $w, $hh]));
    }
    [$c, , $b] = fetch("/resizer/w9999-h9999/$REL/wide.jpg");
    [$w, $hh] = info($b);
    check('w9999-h9999 — не больше 1500×1500', $c === 200 && $w <= 1500 && $hh <= 1500 && $w > 0, json_encode([$c, $w, $hh]));
    [$c, , $b] = fetch("/resizer/w200-h100/$REL/small.jpg");
    [$w, $hh] = info($b);
    $mid = px($b, 100, 50);
    check('маленькая 20×10 → w200-h100: увеличена до 200×100, как прежде', $c === 200 && $w === 200 && $hh === 100 && $mid[1] > 120 && $mid[0] < 60,
        json_encode([$c, $w, $hh, $mid]));

    // 2. форматы и прозрачность
    [$c, , $b] = fetch("/resizer/w50-h20/$REL/alpha.png");
    [$w, $hh, $mime] = info($b);
    $corner = px($b, 0, 0);
    $center = px($b, 25, 10);
    check('PNG с прозрачностью → PNG 50×20, поле прозрачное, середина — синяя', $c === 200 && $mime === 'image/png' && $w === 50 && $hh === 20
        && $corner[3] === 127 && $center[2] > 200 && $center[3] < 10, json_encode([$c, $w, $hh, $mime, $corner, $center]));
    [$c, , $b] = fetch("/resizer/w30-h30/$REL/pic.gif");
    [$w, $hh, $mime] = info($b);
    check('GIF → GIF 30×30', $c === 200 && $mime === 'image/gif' && $w === 30 && $hh === 30, json_encode([$c, $w, $hh, $mime]));
    [$c, , $b] = fetch("/resizer/w60-h60/$REL/pic.webp");
    [$w, $hh, $mime] = info($b);
    check('WebP → WebP 60×60', $c === 200 && $mime === 'image/webp' && $w === 60 && $hh === 60, json_encode([$c, $w, $hh, $mime]));

    // 3. кэш и HTTP
    [$c, $h2, $b2] = fetch("/resizer/w40-h40/$REL/wide.jpg");
    [, , $b1] = fetch("/resizer/w40-h40/$REL/wide.jpg");
    check('повторный запрос — те же байты, ETag и Last-Modified, Cache-Control max-age=864000', $c === 200 && $b1 === $b2 && $etag !== ''
        && ($h2['etag'] ?? '') === $etag && $lastModified !== '' && str_contains($h2['cache-control'] ?? '', 'max-age=864000'), json_encode($h2));
    [$c, , $b] = fetch("/resizer/w40-h40/$REL/wide.jpg", ['If-None-Match: ' . $etag]);
    check('If-None-Match → 304 без тела', $c === 304 && $b === '', (string)$c);
    [$c, , $b] = fetch("/resizer/w40-h40/$REL/wide.jpg", ['If-Modified-Since: ' . $lastModified]);
    check('If-Modified-Since → 304 без тела', $c === 304 && $b === '', (string)$c);
    [$c, $h, $b] = fetch("/resizer/w40-h40/$REL/wide.jpg", [], 'HEAD');
    check('HEAD — 200, заголовки без тела', $c === 200 && $b === '' && (int)($h['content-length'] ?? 0) > 0, json_encode([$c, $h['content-length'] ?? null]));
    if (is_dir($CACHE)) {
        $mine = array_diff(scandir($CACHE), $cacheBefore);
        check('готовые картинки лежат в кэше на диске', count(array_filter($mine, fn($f) => $f[0] !== '.')) >= 7, implode(' ', $mine));
    } else {
        echo "SKIP кэш площадки не в $CACHE — проверка каталога кэша пропущена\n";
    }
    // заменённый файл — новая картинка, а не старая из кэша
    makeImage("$DIR/wide.jpg", 400, 200, [0, 0, 255], 'jpg');
    touch("$DIR/wide.jpg", time() + 5);
    clearstatcache();
    [$c, $h, $b] = fetch("/resizer/w40-h40/$REL/wide.jpg");
    $mid = px($b, 20, 20);
    check('файл заменён — новый ETag и новая картинка', $c === 200 && ($h['etag'] ?? '') !== $etag && $mid[2] > 200 && $mid[0] < 70,
        json_encode([$c, $h['etag'] ?? '', $mid]));

    // 4. отказы — 404 без текста ошибки и путей сервера
    $refusals = [
        'вне uploads/: index.php' => 'index.php',
        'вне uploads/: конфиг площадки' => 'system.config.php',
        'обход через ..' => 'uploads/../index.php',
        'абсолютный путь' => '/etc/passwd',
        'внешний адрес' => 'http://example.com/a.jpg',
        'каталог' => "$REL/dir.jpg",
        'не картинка с расширением .jpg' => "$REL/fake.jpg",
        'символическая ссылка наружу' => "$REL/link.jpg",
        'нет файла' => "$REL/nope.jpg",
    ];
    foreach ($refusals as $label => $src) {
        [$c, , $b] = fetch('/resizer/timthumb.php?w=10&h=10&src=' . rawurlencode($src) . '&zc=2');
        check("отказ — $label: 404 без текста ошибки", $ok($c, $b), $c . ' ' . substr($b, 0, 120));
    }
    [$c, , $b] = fetch("/resizer/w10-h10/$REL/nope.jpg");
    check('через правило веб-сервера: нет файла — 404', $ok($c, $b), (string)$c);

    // 5. ядро в консоли: размеры холста — таблица случаев; кэш недоступен — картинка всё равно отдаётся
    $gear = ROOT . '/core/modules/share/gears/ImageResizer.php';
    if (is_file($gear)) {
        require_once $gear;
        $R = 'Energine\share\gears\ImageResizer';
        $cases = [
            [[40, 40, 400, 200], [40, 40, 0, 10, 40, 20]],
            [[100, 0, 400, 200], [100, 50, 0, 0, 100, 50]],
            [[0, 50, 400, 200], [100, 50, 0, 0, 100, 50]],
            [[0, 0, 400, 200], [100, 100, 0, 25, 100, 50]],
            [[200, 100, 20, 10], [200, 100, 0, 0, 200, 100]],
            [[50, 20, 100, 100], [50, 20, 15, 0, 20, 20]],
            [[9999, 9999, 400, 200], [1500, 1500, 0, 375, 1500, 750]],
        ];
        foreach ($cases as [$in, $want]) {
            $got = $R::box(...$in);
            check('box(' . implode(', ', $in) . ') = ' . implode(', ', $want), $got === $want, json_encode($got));
        }
        $r = new $R(WEB, '/proc/claude-no-cache');
        ob_start();
        // в консоли тест уже печатал строки — header() предупреждал бы «headers already sent»; заголовки здесь не нужны
        @$r->respond(['w' => '40', 'h' => '40', 'src' => "$REL/small.jpg"], []);
        $out = ob_get_clean();
        [$w, $hh] = info($out);
        check('кэш недоступен для записи — картинка всё равно отдаётся', $w === 40 && $hh === 40, strlen($out) . ' байт');
    } else {
        check('гир ImageResizer есть', false);
    }
} finally {
    @unlink("$DIR/link.jpg");
    foreach (glob("$DIR/*") ?: [] as $f) {
        is_dir($f) ? @rmdir($f) : @unlink($f);
    }
    @rmdir($DIR);
    if (is_dir($CACHE)) {
        foreach (array_diff(scandir($CACHE), $cacheBefore) as $f) {
            if ($f[0] !== '.') @unlink("$CACHE/$f");
        }
    }
}
done('resizer');
