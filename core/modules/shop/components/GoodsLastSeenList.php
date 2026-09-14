<?php

namespace Energine\shop\components;

use Energine\share\components\DataSet;
use Energine\share\gears\ComponentProxyBuilder;
use Energine\share\gears\EmptyBuilder;
use Energine\share\gears\SimpleBuilder;

class GoodsLastSeenList extends DataSet implements SampleGoodsLastSeenList {
    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'active' => true
            ]
        );
    }

    protected function createBuilder() {
        return new SimpleBuilder();
    }

    private function getCount() {
        return (isset($_SESSION['last_seen_goods']) && is_array($_SESSION['last_seen_goods'])) ? sizeof($_SESSION['last_seen_goods']) : 0;
    }

    protected function mainState() {
        E()->UserSession->start();
        $this->setProperty('count', $this->getCount());
        $this->addTranslation('TXT_LAST_SEEN_GOODS');
        if (!empty($_SESSION['last_seen_goods'])) {
            $this->setBuilder($b = new ComponentProxyBuilder());
            $params = [
                'active'        => false,
                'state'         => 'main',
                'id'            => $_SESSION['last_seen_goods'],
                'list_features' => 'any' // вывод всех фич товаров в списке
            ];
            $b->setComponent('products',
                '\\Energine\\shop\\components\\GoodsList',
                $params);
        } else {
            $this->setBuilder(new EmptyBuilder());
        }
    }

}

interface SampleGoodsLastSeenList {

}