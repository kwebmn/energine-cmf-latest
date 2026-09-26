<?php
/**
 * @file
 * SiteSettings.
 *
 * It contains the definition to:
 * @code
class SiteSettings;
@endcode
 *
 * @version 1.0.0
 */
namespace Energine\share\components;

use Energine\share\gears\FieldDescription, Energine\share\gears\Field;

/**
 * «Настройки сайта»: единственная запись share_sites — название, ключевые слова и описание по языкам,
 * site_meta_robots — и дополнительные параметры сайта (share_sites_properties) вкладкой формы.
 * Сайт не добавляется, не удаляется и не переставляется: таких состояний в конфиге нет.
 *
 * @code
class SiteSettings;
@endcode
 */
class SiteSettings extends Grid {
    /**
     * Редактор дополнительных параметров сайта (вкладка формы).
     * @var SitePropertiesEditor $propertiesEditor
     */
    private $propertiesEditor;

    /**
     * @copydoc Grid::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('share_sites');
    }

    /**
     * Форма правки: вкладка дополнительных параметров сайта.
     */
    protected function prepare() {
        parent::prepare();
        if ($this->getState() == 'edit') {
            $fd = new FieldDescription('properties');
            $fd->setType(FieldDescription::FIELD_TYPE_TAB);
            $fd->setProperty('title', $this->translate('TAB_SITE_PROPERTIES'));
            $this->getDataDescription()->addFieldDescription($fd);

            $field = new Field('properties');
            $field->setData($this->getData()->getFieldByName($this->getPK())->getRowData(0) . '/properties/', true);
            $this->getData()->addField($field);
        }
    }

    /**
     * Дополнительные параметры сайта — грид share_sites_properties во вкладке формы.
     */
    protected function properties() {
        $sp = $this->getStateParams(true);
        $this->request->shiftPath(2);
        $this->propertiesEditor = $this->document->componentManager->createComponent('propertiesEditor',
            'Energine\share\components\SitePropertiesEditor', ['siteID' => $sp['site_id']]);
        $this->propertiesEditor->run();
    }

    /**
     * @copydoc Grid::build
     */
    public function build() {
        if ($this->getState() == 'properties') {
            return $this->propertiesEditor->build();
        }

        return parent::build();
    }
}
