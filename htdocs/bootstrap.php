<?php

/**
 * Common core settings
 * Defines main entry points
 *
 * @package energine
 * @author Andy Karpov <andy.karpov@gmail.com>
 * @copyright Energine 2013
 */

// absolute path to htdocs
define('HTDOCS_DIR', realpath(dirname(__FILE__)));

//absolute path to project's dir
//document root (web/) is fixed by ISPConfig, so the project (core included) lives outside of it in ../private/energine
define('ROOT_DIR', realpath(HTDOCS_DIR.'/../private/energine'));

if (!file_exists($autoloader = ROOT_DIR.'/vendor/autoload.php')) {
	throw new \LogicException('Autoloader not found. Firstly you have to run "composer install".');
}
require_once($autoloader);

// Подключаем конфиг, чтобы достать из него местоположение ядер и имя текущего ядра
if (!file_exists($configName = HTDOCS_DIR . '/system.config.php')) {
	throw new \LogicException('Configuration file '.$configName.' not found.');
}

// загружаем конфиг в $config
$config = include($configName);

// относительный путь к ядру (ядро и проект — один репозиторий в ../private/energine)
define('CORE_REL_DIR', '../private/energine/core');

// относительный путь к сайту
define('SITE_REL_DIR', '../private/energine/site');



// абсолютный путь к ядру
define('CORE_DIR', realpath(implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, CORE_REL_DIR))));

// абсолютный путь к сайту
define('SITE_DIR', realpath(implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, SITE_REL_DIR))));

//Название директории в которой содержатся модули(как ядра, так и модули проекта)
define('MODULES', 'modules');


// режим отладки
define('DEBUG', $config['site']['debug']);

// установка текущего пути местоположения файла bootstrap.php
// как одного из путей для нахождения файлов для include
set_include_path(implode(PATH_SEPARATOR, array(HTDOCS_DIR, get_include_path())));

// точка входа для setup (удалён из ядра в 0e0f4bd0, восстановлен в ROOT_DIR/setup)
// только из консоли: php7.0 web/index.php setup [install|linker|scriptMap|...]
if ((PHP_SAPI == 'cli') && isset($argv[1]) && ($argv[1] == 'setup')) {
	include_once($config['setup_dir'] . DIRECTORY_SEPARATOR . 'index.php');
	exit;
}

//это первое обращение к ядру
//проверяем наличие файла ini.func.php, если он отсутствует -значит скорее всего инсталляция проекта не произошла
if(!file_exists($iniPath = implode(DIRECTORY_SEPARATOR, array(CORE_DIR, 'modules', 'share', 'gears', 'ini.func.php')))){
	throw new \LogicException('Ядро не подключено. Необходимо запустить setup.');
}
// подключаем инициализационные функции
require_once($iniPath);

// подключаем служебные(вспомогательные) функции
require_once(implode(DIRECTORY_SEPARATOR, array(CORE_DIR, 'modules', 'share', 'gears', 'Utils.php')));

// установка уже подключенного конфига в статическую переменную Primitive
Energine\share\gears\Primitive::setConfig($config);