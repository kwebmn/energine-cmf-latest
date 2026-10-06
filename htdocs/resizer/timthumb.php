<?php
/**
 * Ресайзер картинок: /resizer/wШИРИНА-hВЫСОТА/путь — правило веб-сервера переписывает такой адрес сюда
 * (resizer/timthumb.php?w=…&h=…&src=…&zc=2, docs/INSTALL.md). Имя файла задано этим правилом и остаётся; внутри —
 * свой ресайзер на GD (Energine\share\gears\ImageResizer, надёжность, этап 5), а не timthumb. Ядро и база не нужны.
 */
ini_set('display_errors', '0'); // в ответе — только картинка или пустой 404, никакого текста ошибки
$web = dirname(__DIR__);
require realpath($web . '/../private/energine') . '/core/modules/share/gears/ImageResizer.php';
(new Energine\share\gears\ImageResizer($web, Energine\share\gears\ImageResizer::defaultCacheDir()))->respond($_GET, $_SERVER);
