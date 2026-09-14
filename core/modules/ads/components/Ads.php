<?php

namespace Energine\ads\components;

use Energine\share\components\DBDataSet;

class Ads extends DBDataSet {

    public function __construct($name, ?array $params = NULL) {
        parent::__construct($name, $params);
        $this->setTableName('ads_items');
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'type' => false,
                'limit' => 1,
                'order' => 'rand'
            ]
        );
    }

    public function main() {

        $type = $this->getParam('type');
        $this->setProperty('type', $type);
        $type_id = $this->dbh->getScalar('ads_types', 'ads_type_id', array('ads_type_sysname' => $type));

        // Привязки к сайтам и страницам раньше не учитывались: баннер выводился всюду,
        // где стоит его место. Баннер без привязок считается общим.
        $siteID = (int)E()->getSiteManager()->getCurrentSite()->id;
        $smapID = (int)$this->document->getID();

        $this->setFilter([
            'ads_type_id' => $type_id,
            'ads_item_is_active' => 1,
            '(NOT EXISTS (SELECT 1 FROM ads_items2sites s WHERE s.ads_item_id = ads_items.ads_item_id)'
            . " OR EXISTS (SELECT 1 FROM ads_items2sites s WHERE s.ads_item_id = ads_items.ads_item_id AND s.site_id = $siteID))",
            '(NOT EXISTS (SELECT 1 FROM ads_items2sitemap m WHERE m.ads_item_id = ads_items.ads_item_id)'
            . " OR EXISTS (SELECT 1 FROM ads_items2sitemap m WHERE m.ads_item_id = ads_items.ads_item_id AND m.smap_id = $smapID))",
        ]);

        if ($limit = $this->getParam('limit')) {
            $this->setLimit([0, $limit]);
        }

        if ($order = $this->getParam('order')) {
            if ($order == 'rand') {
                $this->setOrder('RAND()');
            } else {
                $this->setOrder('ads_item_order_num');
            }
        }

        parent::main();
    }
}