<?php
/**
 * Содержит класс Wishlist
 * @package energine
 * @author dr.Pavka
 * @copyright Energine 2015
 */
namespace Energine\shop\components;

use Energine\share\components\DBDataSet;
use Energine\share\gears\ComponentProxyBuilder;
use Energine\share\gears\EmptyBuilder;
use Energine\share\gears\QAL;

/**
 * Список пожеланий
 * @package energine
 * @author dr.Pavka
 */
class Wishlist extends DBDataSet implements SampleWishlist {
    public function __construct($name, ?array $params = null) {
        // the wishlist page has a passive component (state "show"), its single mode requests need the URL states
        if (E()->getDocument()->getProperty('single')) {
            $params['active'] = true;
        }
        parent::__construct($name, $params);
        $this->setTableName('shop_wishlist');
        $this->setFilter([
            'site_id' => E()->getSiteManager()->getCurrentSite()->id,
            'u_id'    => $this->document->getUser()->getID()
        ]);
        $this->setOrder(['w_date' => QAL::ASC]);
        $curr = E()['Energine\\shop\\gears\\Currency'];
        $this->setProperty('currency', $curr->getInfo()['currency_shortname']);
        $this->setProperty('currency-order', $curr->getInfo()['currency_shortname_order']);
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'active' => true
            ]
        );
    }

    protected function getGoodsIds() {
        $res = $this->dbh->getColumn($this->getTableName(), 'goods_id', $this->getFilter());
        return ($res) ? implode(',', $res) : '';
    }

    protected function mainState() {
        $this->setBuilder(new EmptyBuilder());
        $this->setProperty('count', $this->getCount());
        $this->setProperty('goods_ids', $this->getGoodsIds());
        $this->js = $this->buildJS();
        $this->setAction((string)$this->config->getStateConfig('add')->uri_patterns->pattern, true);
        $this->setProperty('load', (string)$this->config->getStateConfig('show')->uri_patterns->pattern);
    }

    protected function getCount() {
        return $this->dbh->getScalar($this->getTableName(), 'COUNT(w_id)', $this->getFilter());
    }

    protected function addState($productID) {
        if ($this->document->getUser()->isAuthenticated() && $this->dbh->getScalar('shop_goods', 'goods_id',
                ['goods_id' => $productID])
        ) {
            $this->dbh->modify(QAL::INSERT_IGNORE, $this->getTableName(), [
                'site_id'  => E()->getSiteManager()->getCurrentSite()->id,
                'w_date'   => date('Y-m-d H:i:s'),
                'u_id'     => $this->document->getUser()->getID(),
                'goods_id' => $productID
            ]);

            $this->showState();
        }
        else {
            $this->setBuilder(new EmptyBuilder());
        }
        $this->setProperty('count', $this->getCount());
    }

    protected function deleteState($productID) {
        $this->removeProduct($productID, false);
        $this->config->setCurrentState('show');
        $this->showState();
    }

    protected function basketState($productID) {
        $this->removeProduct($productID, true);
        $this->config->setCurrentState('show');
        $this->showState();
    }

    /**
     * Remove goods from the wishlist of the current user, optionally putting them into the cart.
     * Rows are found by site and user (the filter of the component); session_id is never written to the wishlist.
     *
     * @param int $productID
     * @param bool $toCart
     */
    protected function removeProduct($productID, $toCart) {
        if (!$this->document->getUser()->isAuthenticated()) {
            return;
        }
        if ($wishlistID = $this->dbh->getScalar($this->getTableName(), 'w_id', array_merge($this->getFilter(), ['goods_id' => (int)$productID]))) {
            $this->dbh->modify(QAL::DELETE, $this->getTableName(), NULL, ['w_id' => $wishlistID]);
            if ($toCart) {
                $this->dbh->modify(QAL::INSERT_IGNORE, 'shop_cart', [
                    'goods_id' => (int)$productID,
                    'session_id' => E()->UserSession->start()->getID(),
                    'u_id' => $this->document->getUser()->getID(),
                    'cart_goods_count' => 1,
                    'cart_date' => date('Y-m-d H:i:s'),
                    'site_id' => E()->getSiteManager()->getCurrentSite()->id
                ]);
            }
        }
    }

    protected function showState() {
        // the form of the wishlist page: checked goods and the pressed button (wishlist.xslt)
        if (($this->getState() == 'show') && isset($_POST['products'], $_POST['action']) && is_array($_POST['products'])
            && in_array($_POST['action'], ['basket', 'delete'], true)
        ) {
            foreach ($_POST['products'] as $productID) {
                $this->removeProduct($productID, $_POST['action'] == 'basket');
            }
        }
        $products = $this->dbh->getColumn($this->getTableName(), 'goods_id', $this->getFilter());
        if (!empty($products)) {
            $this->setProperty('delete', (string)$this->config->getStateConfig('show')->uri_patterns->pattern);
            $this->setBuilder($b = new ComponentProxyBuilder());
            $params = [
                'active'        => false,
                'state'         => 'main',
                'id'            => $products,
                'list_features' => 'any' // вывод всех фич товаров в списке
            ];
            $b->setComponent('products',
                '\\Energine\\shop\\components\\GoodsList',
                $params);
            $this->addToolbar($this->loadToolbar());
            $this->js = $this->buildJS();
        } else {
            $this->setBuilder(new EmptyBuilder());
        }
    }

    public function build() {
        if ($this->document->getProperty('single')) {
            E()->getController()->getTransformer()->setFileName('../../../../core/modules/shop/transformers/single_wishlist.xslt');
        }
        $result = parent::build();

        return $result;
    }

}

interface SampleWishlist {
}

;