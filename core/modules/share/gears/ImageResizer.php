<?php
/**
 * Ресайзер картинок (надёжность, этап 5): свой на GD вместо заброшенного timthumb (2012 г., 1260 строк чужого кода).
 *
 * Адрес — /resizer/wШИРИНА-hВЫСОТА/путь: правило веб-сервера переписывает его на resizer/timthumb.php?w=&h=&src=&zc=2
 * (docs/INSTALL.md), точка входа зовёт respond(). Вид — как у timthumb с zc=2: картинка вписана в ШИРИНА×ВЫСОТА по
 * центру с полями (у JPEG и GIF — белые, у PNG и WebP — прозрачные), нулевая сторона — по пропорции, обе нулевые —
 * 100×100, не больше 1500×1500, маленькие увеличиваются, формат — как у исходника, JPEG — качество 90. Новое: только
 * обычные файлы картинок внутри uploads/ этого сайта (остальное — 404 без текста), кэш готовых картинок на диске,
 * ETag и Last-Modified → 304, WebP. Проверка — tests/resizer.php.
 *
 * Чистый PHP + GD: без ядра, базы и конфига — точка входа подключает только этот файл.
 */
namespace Energine\share\gears;

final class ImageResizer {
    /** Не больше по каждой стороне — как timthumb (MAX_WIDTH, MAX_HEIGHT). */
    const MAX = 1500;
    /** Обе стороны нулевые — квадрат такого размера, как timthumb (DEFAULT_WIDTH, DEFAULT_HEIGHT). */
    const DEFAULT_SIZE = 100;
    /** Качество JPEG и WebP — как timthumb (DEFAULT_Q). */
    const QUALITY = 90;
    /** Сколько браузер держит картинку — 10 дней, как timthumb. */
    const MAX_AGE = 864000;
    /** Исходник больше стольких пикселей не открывается: картинке в памяти GD нужно ~5 байт на пиксель. */
    const MAX_PIXELS = 40000000;
    /** Записи кэша старше стольких дней удаляются (раз в сутки). */
    const CACHE_DAYS = 30;
    /** Меняется вместе с алгоритмом: записи кэша прежних версий не подходят. */
    const VERSION = 1;

    /** Тип картинки (getimagesize) → расширение файла кэша и тип ответа. */
    private const TYPES = [
        IMAGETYPE_JPEG => ['jpg', 'image/jpeg'],
        IMAGETYPE_PNG => ['png', 'image/png'],
        IMAGETYPE_GIF => ['gif', 'image/gif'],
        IMAGETYPE_WEBP => ['webp', 'image/webp'],
    ];
    private const EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    /** Каталог uploads/ сайта (реальный путь) — картинки берутся только из него. */
    private string $uploads;

    /**
     * @param string $webRoot корень сайта (web/), в нём uploads/
     * @param string $cacheDir каталог кэша готовых картинок (создаётся при первой записи; недоступен — без кэша)
     */
    public function __construct(private string $webRoot, private string $cacheDir) {
        $this->uploads = (string)@realpath($webRoot . '/uploads');
    }

    /**
     * Кэш по умолчанию — во временном каталоге PHP площадки (upload_tmp_dir пула, иначе системный).
     */
    public static function defaultCacheDir(): string {
        $tmp = (string)(ini_get('upload_tmp_dir') ?: sys_get_temp_dir());
        return rtrim($tmp, '/') . '/energine-resizer';
    }

    /**
     * Файл картинки: путь относительно корня сайта, после разрешения «..» и символических ссылок — обычный файл внутри
     * uploads/ с расширением картинки; иначе null (абсолютный путь, внешний адрес, обход каталога, ссылка наружу).
     */
    public function source(string $src): ?string {
        if ($this->uploads === '' || $src === '' || $src[0] === '/' || str_contains($src, "\0") || str_contains($src, '\\')
            || str_contains($src, '://')) {
            return null;
        }
        if (!in_array(strtolower(pathinfo($src, PATHINFO_EXTENSION)), self::EXTENSIONS, true)) {
            return null;
        }
        $path = @realpath($this->webRoot . '/' . $src);
        if ($path === false || !str_starts_with($path, $this->uploads . '/') || !@is_file($path)) {
            return null;
        }
        return $path;
    }

    /**
     * Холст и картинка на нём — как timthumb с zc=2: [ширина холста, высота холста, x, y, ширина, высота картинки].
     * Нулевая сторона — по пропорции исходника, обе нулевые — DEFAULT_SIZE; стороны не больше MAX (и вычисленная тоже).
     *
     * @return array{0: int, 1: int, 2: int, 3: int, 4: int, 5: int}
     */
    public static function box(int $w, int $h, int $srcW, int $srcH): array {
        $w = min(abs($w), self::MAX);
        $h = min(abs($h), self::MAX);
        if ($w === 0 && $h === 0) {
            $w = $h = self::DEFAULT_SIZE;
        } elseif ($h === 0) {
            $h = min(self::MAX, max(1, (int)floor($srcH * $w / $srcW)));
        } elseif ($w === 0) {
            $w = min(self::MAX, max(1, (int)floor($srcW * $h / $srcH)));
        }
        $fitH = $srcH * $w / $srcW;
        if ($fitH > $h) {
            $fitW = $srcW * $h / $srcH;
            return [$w, $h, (int)round($w / 2 - $fitW / 2), 0, max(1, (int)round($fitW)), $h];
        }
        return [$w, $h, 0, (int)round($h / 2 - $fitH / 2), $w, max(1, (int)round($fitH))];
    }

    /**
     * Ответ на запрос картинки: ?w=…&h=…&src=… (zc — всегда 2). 304 — если у браузера та же картинка; 404 без текста —
     * если файла нет или он не картинка из uploads/; иначе картинка (из кэша или только что сделанная).
     *
     * @param array $get параметры запроса ($_GET)
     * @param array $server $_SERVER (метод, If-None-Match, If-Modified-Since)
     */
    public function respond(array $get, array $server): void {
        $file = $this->source((string)($get['src'] ?? ''));
        $info = $file ? @getimagesize($file) : false;
        if (!$info || !isset(self::TYPES[$info[2]]) || $info[0] < 1 || $info[1] < 1 || $info[0] * $info[1] > self::MAX_PIXELS) {
            $this->notFound();
            return;
        }
        [$ext, $mime] = self::TYPES[$info[2]];
        $box = self::box((int)($get['w'] ?? 0), (int)($get['h'] ?? 0), $info[0], $info[1]);
        $mtime = (int)@filemtime($file);
        $key = sha1(self::VERSION . '|' . $file . '|' . $mtime . '|' . @filesize($file) . '|' . implode(',', $box));
        $etag = '"' . $key . '"';
        $validators = ['Cache-Control: public, max-age=' . self::MAX_AGE, 'ETag: ' . $etag,
            'Last-Modified: ' . gmdate('D, d M Y H:i:s', $mtime) . ' GMT'];

        $ifNoneMatch = trim((string)($server['HTTP_IF_NONE_MATCH'] ?? ''));
        $ifModifiedSince = (string)($server['HTTP_IF_MODIFIED_SINCE'] ?? '');
        if ($ifNoneMatch !== '' ? in_array($etag, array_map('trim', explode(',', $ifNoneMatch)), true)
            : ($ifModifiedSince !== '' && (int)strtotime($ifModifiedSince) >= $mtime)) {
            http_response_code(304);
            array_map('header', $validators);
            return;
        }

        $cached = $this->cacheDir . '/' . $key . '.' . $ext;
        $body = @is_file($cached) ? (string)@file_get_contents($cached) : '';
        if ($body === '') {
            $body = $this->render($file, $info[2], $box);
            if ($body === '') {
                $this->notFound();
                return;
            }
            $this->store($cached, $body);
        }
        array_map('header', $validators);
        header('Content-Type: ' . $mime);
        header('Content-Length: ' . strlen($body));
        if (strtoupper((string)($server['REQUEST_METHOD'] ?? 'GET')) !== 'HEAD') {
            echo $body;
        }
    }

    /**
     * Картинка нужного размера в формате исходника; '' — GD не открыл файл.
     *
     * @param array{0: int, 1: int, 2: int, 3: int, 4: int, 5: int} $box
     */
    private function render(string $file, int $type, array $box): string {
        [$canvasW, $canvasH, $x, $y, $w, $h] = $box;
        self::raiseMemoryLimit();
        $source = match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($file),
            IMAGETYPE_PNG => @imagecreatefrompng($file),
            IMAGETYPE_GIF => @imagecreatefromgif($file),
            IMAGETYPE_WEBP => @imagecreatefromwebp($file),
            default => false,
        };
        if (!$source) {
            return '';
        }
        $canvas = imagecreatetruecolor($canvasW, $canvasH);
        // PNG и WebP — прозрачные поля и прозрачность исходника; JPEG и GIF (без канала прозрачности) — на белом
        $alpha = in_array($type, [IMAGETYPE_PNG, IMAGETYPE_WEBP], true);
        imagealphablending($canvas, false);
        imagefill($canvas, 0, 0, $alpha ? imagecolorallocatealpha($canvas, 255, 255, 255, 127) : imagecolorallocate($canvas, 255, 255, 255));
        imagealphablending($canvas, !$alpha);
        imagesavealpha($canvas, $alpha);
        imagecopyresampled($canvas, $source, $x, $y, 0, 0, $w, $h, imagesx($source), imagesy($source));
        ob_start();
        match ($type) {
            IMAGETYPE_JPEG => imagejpeg($canvas, null, self::QUALITY),
            IMAGETYPE_PNG => imagepng($canvas),
            IMAGETYPE_GIF => imagegif($canvas),
            IMAGETYPE_WEBP => imagewebp($canvas, null, self::QUALITY),
        };
        return (string)ob_get_clean();
    }

    /**
     * Запись в кэш — атомарно (временный файл и переименование): параллельный запрос не прочтёт половину картинки.
     * Каталог недоступен — без кэша, картинка всё равно отдаётся. Раз в сутки — удаление старых записей.
     */
    private function store(string $path, string $body): void {
        $dir = dirname($path);
        if (!@is_dir($dir) && !@mkdir($dir, 0700, true) && !@is_dir($dir)) {
            return;
        }
        $tmp = @tempnam($dir, '.tmp');
        if ($tmp === false || !str_starts_with($tmp, $dir . '/')) {
            if ($tmp !== false) {
                @unlink($tmp);
            }
            return;
        }
        if (@file_put_contents($tmp, $body) !== strlen($body) || !@rename($tmp, $path)) {
            @unlink($tmp);
            return;
        }
        $mark = $dir . '/.cleaned';
        if ((int)@filemtime($mark) < time() - 86400) {
            @touch($mark);
            foreach (glob($dir . '/*') ?: [] as $old) {
                if ((int)@filemtime($old) < time() - self::CACHE_DAYS * 86400) {
                    @unlink($old);
                }
            }
        }
    }

    private function notFound(): void {
        http_response_code(404);
        header('Content-Type: text/plain; charset=utf-8');
        header('Cache-Control: no-store');
    }

    /**
     * Большой исходник не помещается в обычный предел памяти PHP: для запроса ресайзера — не меньше 256 МБ.
     */
    private static function raiseMemoryLimit(): void {
        $limit = trim((string)ini_get('memory_limit'));
        if ($limit === '-1') {
            return;
        }
        $bytes = (int)$limit * match (strtoupper(substr($limit, -1))) { 'G' => 1 << 30, 'M' => 1 << 20, 'K' => 1 << 10, default => 1 };
        if ($bytes < 256 << 20) {
            @ini_set('memory_limit', '256M');
        }
    }
}
