<?php
/**
 * Created by PhpStorm.
 * User: pavka
 * Date: 10/9/15
 * Time: 1:35 PM
 */

namespace Energine\shop\components;


use Energine\share\components\DBDataSet;
use Energine\share\gears\Field;
use Energine\share\gears\FieldDescription;
use Energine\share\gears\Filter;
use Energine\share\gears\JSONCustomBuilder;
use Energine\share\gears\QAL;

class SavedFilters extends DBDataSet {
    /**
     * @copydoc DataSet::__construct
     */
    public function __construct($name, ?array $params = NULL) {
        // то же, что у фильтра: удаление вызывается по своему URL в single-режиме
        if (E()->getDocument()->getProperty('single')) {
            $params['active'] = true;
        }
        parent::__construct($name, $params);
        $this->setTableName('shop_saved_filters');
        $this->setFilter(['u_id' => E()->getUser()->getID(), 'site_id' => E()->getSiteManager()->getCurrentSite()->id]);
        // фильтры принадлежат пользователю: гостю показывать нечего
        if (!$this->document->getUser()->isAuthenticated()) {
            $this->disable();
        }
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'active' => true
            ]
        );
    }

    protected function main() {
        parent::main();

        // Ссылка на отфильтрованный список - вычисляемое поле. Раньше её клали
        // прямо в строку данных, а описание поля отсутствовало; стоило описание
        // добавить, как sf_link попадал в SELECT и запрос падал.
        if (!($smap = $this->getData()->getFieldByName('smap_id'))
            || !($data = $this->getData()->getFieldByName('sf_data'))
        ) {
            return;
        }

        $fd = new FieldDescription('sf_link');
        $fd->setType(FieldDescription::FIELD_TYPE_STRING);
        $this->getDataDescription()->addFieldDescription($fd);

        $field = new Field('sf_link');
        $map = E()->getMap();
        foreach ($smap as $row => $smapID) {
            $field->setRowData($row, $map->getURLByID($smapID) . '?' . Filter::TAG_NAME . '=' . $data->getRowData($row));
        }
        $this->getData()->addField($field);
    }

    protected function save() {
        $this->setBuilder($b = new JSONCustomBuilder());
        $this->dbh->beginTransaction();
        try {
            if (!isset($_POST['id']) && !isset($_POST['name'])) {
                throw new \InvalidArgumentException(E()->Utils->translate('ERR_NO_DATA'));
            }
            $this->dbh->modify(QAL::UPDATE, $this->getTableName(), ['sf_name' => $realName = trim(strip_tags((string)$_POST['name']))], ['u_id' => E()->getUser()->getID(), 'site_id' => E()->getSiteManager()->getCurrentSite()->id, 'sf_id' => (int)$_POST['id']]);

            $this->dbh->commit();
            $b->setProperty('name', $realName);
        } catch (\Exception $e) {
            $this->dbh->rollback();
            $b->setProperty('result', false);
            $b->setProperty('message', $e->getMessage());
        }
    }
    protected function delete($id) {
        $this->setBuilder($b = new JSONCustomBuilder());
        $this->dbh->beginTransaction();
        try {
            $this->dbh->modify(QAL::DELETE, $this->getTableName(), false, ['u_id' => E()->getUser()->getID(), 'site_id' => E()->getSiteManager()->getCurrentSite()->id, 'sf_id' => $id]);
            $this->dbh->commit();
        } catch (\Exception $e) {
            $this->dbh->rollback();
            $b->setProperty('result', false);
            $b->setProperty('message', $e->getMessage());
        }
        // список выводится ссылками, поэтому возвращаемся на страницу каталога
        $this->response->redirectToReferer();
    }

}