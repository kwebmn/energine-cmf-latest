<?php

namespace Energine\shop\components;

use Energine\share\components\DBDataSet;
use Energine\share\gears\AttachmentManager;
use Energine\share\gears\TagManager;
use Energine\share\gears\QAL;
use Energine\share\gears\SystemException;

class RelatedGoodsList extends DBDataSet {

	/**
	 * Bounded component.
	 * @var DBDataSet|boolean $bindComponent
	 */
	protected $bindComponent;

	/**
	 * Конструктор
	 *
	 * @param string $name
	 * @param array $params
	 */
	public function __construct($name, ?array $params = null) {
		parent::__construct($name, $params);
		$this->setTableName('shop_goods');
		$this->setOrder(array('goods_price' => QAL::ASC));
		$this->bindComponent =
			$this->document->componentManager->getBlockByName($this->getParam('bind'));
		$this->setParam('recordsPerPage', false);
		$this->setParam('active', false);
	}

	protected function defineParams() {
		return array_merge(
			parent::defineParams(),
			[
				'bind' => false,
				'bind_state' => 'view',
				'relation_type' => 'similar'
			]
		);
	}

	protected function prepare() {

		if ($this->bindComponent and
			$this->bindComponent->getState() == $this->getParam('bind_state') and
			$this->getState() == 'main'
		) {

			// ID связанной записи
			$priFieldName = $this->bindComponent->getPK();
			$targetIds = $this->bindComponent->getData()->getFieldByName($priFieldName)->getData();

			// тип связи
			$relation_type = $this -> getParam('relation_type');

			// получаем список goods_id связи
			$goods_ids = $this -> dbh -> getColumn(
				'shop_goods_relations',
				'goods_to_id',
				array(
					'relation_type' => $relation_type,
					'goods_from_id' => $targetIds
				),
                array(
                    'relation_order_num' => QAL::ASC
                )
			);

			if (empty($goods_ids)) {
				$goods_ids = array('-1');
			}

			$this->setFilter(array(
				$this->getTableName().'.goods_id' => $goods_ids
			));

			parent::prepare();

		} else {
			$this->disable();
		}
	}

	/**
	 * Переопределенный метод вывода списка
	 * Выводит также аттачменты и теги для товаров
	 *
	 * @throws SystemException
	 */
	protected function main() {

		parent::main();

		// как и в GoodsList: обозначение валюты для шаблона цены
		$curr = E()['Energine\\shop\\gears\\Currency'];
		$this->setProperty('currency', $curr->getInfo()['currency_shortname']);
		$this->setProperty('currency-order', $curr->getInfo()['currency_shortname_order']);

		if ($this -> getData()) {

			// attachments in list
			$this->buildAttachments();

			// tags in list
			$this->buildTags();
		}
	}

	/**
	 * Прикрепляет аттачменты к record'ам (если есть фейковое поле attachments в конфиге)
	 *
	 * @throws SystemException
	 */
	/**
	 * Category URLs instead of their ids: the goods links of the list (as GoodsList::loadData()).
	 */
	protected function loadData() {
		$result = parent::loadData();
		if (is_array($result)) {
			$map = E()->getMap();
			$curr = E()['Energine\\shop\\gears\\Currency'];
			foreach ($result as &$row) {
				if (isset($row['smap_id'])) {
					$row['smap_id'] = $map->getURLByID($row['smap_id']);
				}
				// цена хранится в валюте товара, показывается в выбранной посетителем
				if (isset($row['currency_id'], $row['goods_price'])) {
					$row['goods_price'] = $curr->convert($row['goods_price'], $row['currency_id']);
				}
			}
		}
		return $result;
	}

	protected function buildAttachments() {
		if ($this->getDataDescription()->getFieldDescriptionByName('attachments')) {
			$am = new AttachmentManager(
				$this->getDataDescription(),
				$this->getData(),
				$this->getTableName()
			);
			$am->createFieldDescription();
			if ($f = $this->getData()->getFieldByName('goods_id'))
				$am->createField('goods_id', true, $f->getData());
		}
	}

	/**
	 * Прикрепляет теги к record'ам (если есть фейковое поле tags в конфиге)
	 *
	 * @throws SystemException
	 */
	protected function buildTags() {
		if ($this->getDataDescription()->getFieldDescriptionByName('tags')) {
			$tm = new TagManager($this->getDataDescription(), $this->getData(), $this->getTableName());
			$tm->createFieldDescription();
			$tm->createField();
		}
	}

}