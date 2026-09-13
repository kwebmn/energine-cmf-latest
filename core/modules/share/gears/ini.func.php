<?php
/**
 * @file
 * Initialisation file.
 *
 * It contains the initialisation functions and constants.
 *
 * @author pavka
 * @copyright Energine 2007
 *
 * @version 1.0.0
 */
// Хак для cgi mode, где SCRIPT_FILENAME возвращает путь к PHP, вместо пути к текущему исполняемому файлу
if (isset($_SERVER['SCRIPT_FILENAME'])) {
    $_SERVER['SCRIPT_FILENAME'] =
        (isset($_SERVER['PATH_TRANSLATED'])) ? $_SERVER['PATH_TRANSLATED'] : $_SERVER['SCRIPT_FILENAME'];
}

// устанавливаем максимальный уровень отображения ошибок
//error_reporting(E_ALL | E_STRICT);
//С 5.4 вроде как E_STRICT стал частью E_ALL
error_reporting(E_ALL);
// включаем вывод ошибок и отключаем вывод в HTML
@ini_set('display_errors', 1);
@ini_set('html_errors', 0);
@ini_set('session.auto_start', 0);
@ini_set('session.use_trans_sid', 0);

@date_default_timezone_set('Europe/Kyiv');
/*
 * Определяем константы прав доступа
 * они должны иметь те же значения что и в таблице user_group_rights + ACCESS_NONE = 0
 * загружать их из таблицы особого смысла не имеет
 */
/**
 * Access level: none.
 * @var int ACCESS_NONE
 */
define('ACCESS_NONE', 0);
/**
 * Access level: read.
 * @var int ACCESS_READ
 */
define('ACCESS_READ', 1);
/**
 * Access level: edit.
 * @var int ACCESS_EDIT
 */
define('ACCESS_EDIT', 2);
/**
 * Access level: full.
 * @var int ACCESS_FULL
 */
define('ACCESS_FULL', 3);

// Подключаем реестр и мемкешер, нужные нам для автолоадера
require_once('Registry.php');

/**
 * @fn nrgnErrorHandler($errLevel, $message, $file, $line)
 * @brief Error handler.
 * It converts all errors except deprecations to the SystemException with type ERR_DEVELOPER.
 * Deprecations are only logged, so a PHP upgrade does not break the site.
 *
 * @param int $errLevel Error level.
 * @param string $message Error message.
 * @param string $file Error file.
 * @param int $line Error line.
 *
 */
set_error_handler(function ($errLevel, $message, $file, $line) {
        if (in_array($errLevel, [E_DEPRECATED, E_USER_DEPRECATED], true)) {
            error_log(sprintf('PHP Deprecated: %s in %s on line %d', $message, $file, $line));
            return true;
        }
        // components wrap exceptions and lose the original location, keep it in the log
        error_log(sprintf('PHP error %d thrown as SystemException: %s in %s on line %d', $errLevel, $message, $file, $line));
        $e = new Energine\share\gears\SystemException(
            $message,
            Energine\share\gears\SystemException::ERR_DEVELOPER
        );
        throw $e->setFile($file)->setLine($line);
    }
);
