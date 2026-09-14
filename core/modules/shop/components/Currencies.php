<?php
/**
 * Created by PhpStorm.
 * User: pavka
 * Date: 8/25/15
 * Time: 6:09 PM
 */

namespace Energine\shop\components;


use Energine\share\components\DataSet;
use Energine\share\gears\SimpleBuilder;

/**
 * Currency switcher.
 *
 * Lists the active currencies and lets a visitor pick one. The choice is kept in
 * the session and read back by @link Energine\shop\gears\Currency Currency @endlink,
 * which converts and formats the prices.
 */
class Currencies extends DataSet {
    /**
     * Session key holding the currency chosen by the visitor.
     * @var string SESSION_KEY
     */
    const SESSION_KEY = 'shop_currency_id';

    public function __construct($name, ?array $params = NULL) {
        // состояния из URL разбираются только у активного компонента, а переключатель
        // стоит на странице рядом со списком товаров; в single-режиме он один - и активен
        if (E()->getDocument()->getProperty('single')) {
            $params['active'] = true;
        }
        parent::__construct($name, $params);
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'active' => false
            ]
        );
    }

    protected function main() {
        $this->setType(self::COMPONENT_TYPE_LIST);
        $this->setDataDescription(E()['Energine\\shop\\gears\\Currency']->asDataDescription());
        $this->setData(E()['Energine\\shop\\gears\\Currency']->asData());
        $this->setBuilder(new SimpleBuilder());
    }

    /**
     * Remember the chosen currency and return to the page the visitor came from.
     */
    protected function set() {
        $params = $this->getStateParams(true);
        $id = isset($params['currencyID']) ? (int)$params['currencyID'] : 0;

        // принимаем только существующую активную валюту: иначе Currency бросит
        // исключение на каждой следующей странице
        if ($id && $this->dbh->getScalar('shop_currencies', 'currency_id',
                ['currency_id' => $id, 'currency_is_active' => 1])
        ) {
            $_SESSION[self::SESSION_KEY] = $id;
        }

        $this->response->redirectToReferer();
    }
}
