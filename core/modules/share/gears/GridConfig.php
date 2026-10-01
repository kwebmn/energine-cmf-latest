<?php
/**
 * @file
 * GridConfig.
 *
 * It contains the definition to:
 * @code
class GridConfig;
@endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2011
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * Grid configuration.
 *
 * @code
class GridConfig;
@endcode
 */
class GridConfig extends DataSetConfig {
    /**
     * @copydoc ComponentConfig::__construct
     */
    public function __construct($config, $className, $moduleName){
        parent::__construct($config, $className, $moduleName);
        $this->registerState('put', array('/put/'));
        $this->registerState('upload', array('/upload/'));
        $this->registerState('cleanup', array('/cleanup/'));
    }
}