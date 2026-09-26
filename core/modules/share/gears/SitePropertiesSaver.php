<?php
/**
 * @file
 * SitePropertiesSaver
 *
 * It contains the definition to:
 * @code
class SitePropertiesSaver;
@endcode
 *
 * @author Andrii A
 * @copyright Energine 2014
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * Saver for site properties. Transliterates property name for each new property.
 *
 * @code
class SitePropertiesSaver;
@endcode
 */
class SitePropertiesSaver extends ExtendedSaver {
    public function setData(Data $data) {
        parent::setData($data);
        if($fPropName = $this->getData()->getFieldByName('prop_name')) {
            $name = Translit::transliterate($fPropName->getRowData(0), '_');
            $fPropName->setData(preg_replace("/[^A-Za-z0-9_\\.]/", '', $name), true);
        }
    }

    /**
     * Имя параметра не повторяется (ключ prop_name): отказ до записи — сообщением, а не текстом ошибки SQL.
     */
    public function save() {
        $propName = $this->getData()->getFieldByName('prop_name')->getRowData(0);
        $id = (int)($_POST['share_sites_properties']['prop_id'] ?? 0);
        if ($this->dbh->getScalar('SELECT COUNT(*) FROM share_sites_properties WHERE prop_name = %s AND prop_id <> %s', $propName, $id)) {
            throw new SystemException('ERR_PROPERTY_EXIST', SystemException::ERR_WARNING);
        }

        return parent::save();
    }
}
