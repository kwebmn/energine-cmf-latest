<?php
/**
 * @file
 * ExtendedSaver.
 *
 * It contains the definition to:
 * @code
class ExtendedSaver;
@endcode
 *
 * @author
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * Extended Saver.
 *
 * @code
class ExtendedSaver;
@endcode
 */
class ExtendedSaver extends Saver {
    /**
     * Primary key of the table.
     * @var string $pk
     */
    private $pk;

    /**
     * Main table name.
     * @var string $mainTableName
     */
    private $mainTableName;

    /**
     * Set data description and main table name.
     *
     * @param DataDescription $dd Data description.
     */
    public function setDataDescription(DataDescription $dd) {
        parent::setDataDescription($dd);
        foreach ($dd as $fieldName => $fieldInfo) {
            if ($fieldInfo->getPropertyValue('key') === true) {
                $this->pk = $fieldName;
                $this->mainTableName = $fieldInfo->getPropertyValue('tableName');
                break;
            }
        }
    }

    /**
     * Get main table name.
     *
     * @return string
     */
    protected function getTableName() {
        return $this->mainTableName;
    }

    /**
     * Get primary key.
     *
     * @return string
     */
    protected function getPK(){
        return $this->pk;
    }
}
