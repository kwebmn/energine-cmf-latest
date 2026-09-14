<?php
/**
 * @file.
 * Ads
 *
 * It contains the definition to:
 * @code
class Ads;
@endcode
 *
 * @author spacelord
 * @copyright Energine 2011
 *
 * @version 1.0.0
 */
namespace Energine\apps\components;
use Energine\share\components\DataSet, Energine\apps\gears\AdsManager, Energine\share\gears\QAL, Energine\share\gears\FieldDescription;
/**
 * Class to show ad blocks.
 *
 * @code
class Ads;
@endcode
 *
 * @note Ads should be in the "apps_ads" table. The list of blocks is described in the form of fields and bounds by "smap_id" to the section.
 * If you do not specify your block then parent block will be token.
 */
class Ads extends DataSet{
    /**
     * @copydoc DataSet::__construct
     */
    public function __construct($name,  ?array $params = null){
        parent::__construct($name, $params);
        if(!AdsManager::isActive()){
            $this->disable();
        }
    }

    /**
     * @copydoc DataSet::main
     */
    protected function main(){
        parent::main();

        // Берём врезку самой страницы, а если её нет - ближайшего предка, у которого
        // она задана. Прежний перебор родителей в PHP не срабатывал; здесь порядок
        // «текущая страница, затем предки от ближнего к корню» задаётся явно.
        $ids = [(int)$this->document->getID()];
        foreach (array_reverse(array_keys((array)E()->getMap()->getParents($this->document->getID()))) as $parentID) {
            $ids[] = (int)$parentID;
        }
        $ids = array_values(array_unique($ids));

        $result = $this->dbh->select(
            'SELECT * FROM ' . AdsManager::TABLE_NAME
            . ' WHERE smap_id IN (' . implode(',', $ids) . ')'
            . ' ORDER BY FIELD(smap_id, ' . implode(',', $ids) . ') LIMIT 1'
        );

        // при отсутствии строк select возвращает то true, то пустой массив
        if(is_array($result) && !empty($result[0])){
            //We don't need smap_id, so don't write it to Data
            unset($result[0]['smap_id']);
            foreach ($result[0] as $key => $value) {
                $fd = new FieldDescription($key);
                if (in_array($key, array('ad_id'))) {
                    $fd->setType(FieldDescription::FIELD_TYPE_INT);
                } else {
                    $fd->setType(FieldDescription::FIELD_TYPE_TEXT);
                }
                $this->getDataDescription()->addFieldDescription($fd);
            }
            $this->getData()->load($result);
        }
    }
}