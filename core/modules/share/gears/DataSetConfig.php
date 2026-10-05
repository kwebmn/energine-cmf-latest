<?php
/**
 * @file
 * DataSetConfig.
 *
 * It contains the definition to:
 * @code
class DataSetConfig;
@endcode
 *
 * @author Andrii A
 * @copyright Energine 2014
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * DataSet configuration.
 *
 * @code
class GridConfig;
@endcode
 */
class DataSetConfig extends ComponentConfig {
    /**
     * @copydoc ComponentConfig::__construct
     */
    public function __construct($config, $className, $moduleName){
        parent::__construct($config, $className, $moduleName);
        // окна редактора (библиотека файлов, менеджер картинок, дерево разделов для ссылки) — только полным правам:
        // без rights состояние наследовало бы права документа, и гость через публичную форму открывал бы встроенный
        // компонент целиком (список файлов, карту сайта, пользователей)
        $this->registerState('imageManager', array('/imagemanager/'), ACCESS_FULL);
        $this->registerState('fileLibrary', array('/file-library/', '/file-library/[any]/'), ACCESS_FULL);
        $this->registerState('pageTree', array('/page-tree/', '/page-tree/[any]/'), ACCESS_FULL);
    }
}