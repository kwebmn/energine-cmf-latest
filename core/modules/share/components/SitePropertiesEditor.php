<?php
/**
 * @file
 * SitePropertiesEditor
 *
 * It contains the definition to:
 * @code
class SitePropertiesEditor;
@endcode
 *
 * @author Andrii A
 * @copyright Energine 2014
 *
 * @version 1.0.0
 */
namespace Energine\share\components;
use Energine\share\gears\SitePropertiesSaver, Energine\share\gears\FieldDescription;
/**
 * Site properties editor.
 *
 * @code
class SitePropertiesEditor;
@endcode
 */
class SitePropertiesEditor extends Grid {
    /**
     * @copydoc Grid::__construct
     */
    public function __construct($name,  ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('share_sites_properties');
        $this->setSaver(new SitePropertiesSaver());
    }

    /**
     * Имя параметра — латиница, цифры, точка и подчёркивание; при правке не меняется.
     */
    protected function createDataDescription() {
        $dd = parent::createDataDescription();
        if (in_array($this->getState(), array('add', 'edit'))) {
            if ($this->getState() == 'edit') {
                $dd->getFieldDescriptionByName('prop_name')->setMode(FieldDescription::FIELD_MODE_READ);
            }
            $dd->getFieldDescriptionByName('prop_name')->setProperty('pattern', '/^[A-Za-z0-9_\\.]+$/');
            $dd->getFieldDescriptionByName('prop_name')->setProperty('message', 'ERR_BAD_PROPERTY_NAME');
        }
        return $dd;
    }
}