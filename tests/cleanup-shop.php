<?php
// Removes everything smoke-shop.php creates (names/sysnames starting with claude-test / claude_).
require __DIR__ . '/testlib.php';
$report = [];
$del = function ($label, $sql, $args = []) use (&$report) {
    $report[] = sprintf('%-28s %d', $label, q($sql, $args)->rowCount());
};
$del('orders', "DELETE FROM shop_orders WHERE order_user_name LIKE 'claude-test%' OR order_email LIKE 'claude-test%'");
$del('promotions', "DELETE p FROM shop_promotions p JOIN shop_promotions_translation t USING(promotion_id) WHERE t.promotion_name LIKE 'claude-test%'");
$del('goods', "DELETE g FROM shop_goods g JOIN shop_goods_translation t USING(goods_id) WHERE t.goods_name LIKE 'claude-test%'");
$del('unbound goods rows', "DELETE FROM shop_feature2good_values WHERE goods_id IS NULL");
$del('unbound relations', "DELETE FROM shop_goods_relations WHERE goods_from_id IS NULL");
// вложения формы ещё не сохранённого товара: привязаны к сессии, после теста остаются висеть
$del('unbound goods uploads', "DELETE FROM shop_goods_uploads WHERE goods_id IS NULL");
$del('unbound order lines', "DELETE FROM shop_orders_goods WHERE order_id IS NULL");
$del('unbound promotion goods', "DELETE FROM shop_goods2promotions WHERE promotion_id IS NULL");
$del('features', "DELETE f FROM shop_features f JOIN shop_features_translation t USING(feature_id) WHERE t.feature_name LIKE 'claude-test%'");
$del('unbound options', "DELETE FROM shop_feature_options WHERE feature_id IS NULL");
$del('feature groups', "DELETE g FROM shop_feature_groups g JOIN shop_feature_groups_translation t USING(group_id) WHERE t.group_name LIKE 'claude-test%'");
$del('producers', "DELETE p FROM shop_producers p JOIN shop_producers_translation t USING(producer_id) WHERE t.producer_name LIKE 'claude-test%'");
$del('currencies', "DELETE FROM shop_currencies WHERE currency_code = 'CTU'");
foreach (['shop_order_statuses' => 'status', 'shop_delivery_types' => 'type', 'shop_payment_types' => 'type'] as $table => $prefix) {
    $del($table, "DELETE FROM $table WHERE {$prefix}_sysname LIKE 'claude-test%'");
}
$del('countries', "DELETE c FROM site_country c JOIN site_country_translation t USING(country_id) WHERE t.country_name LIKE 'claude-test%'");
$del('category pages', "DELETE FROM share_sitemap WHERE smap_segment LIKE 'claude-test%'");
$del('users', "DELETE FROM user_users WHERE u_name LIKE 'claude-shop%'");
$del('cart', "DELETE FROM shop_cart WHERE goods_id NOT IN (SELECT goods_id FROM shop_goods)");
foreach (glob(__DIR__ . '/cookies-shop-*.txt') as $f) unlink($f);
echo implode("\n", $report), "\n";
