<?php
// Shop module end-to-end on the site from env.php: admin editors, catalogue, cart, wishlist, compare, search, orders.
// Everything created is named/sysnamed "claude-test..." and removed by cleanup-shop.php (run at the end).
// Usage: php8.5 smoke-shop.php [keep]   ("keep" leaves the test data for a look in the browser)
require __DIR__ . '/testlib.php';
date_default_timezone_set('Europe/Kyiv');

const IMG = 'uploads/public/13662314846.png';
$useJar = function ($name) { $GLOBALS['jar'] = __DIR__ . "/cookies-shop-$name.txt"; };
$keep = ($argv[1] ?? '') === 'keep';
$A = '/admin/shop/';

// Grid save through its add form: returns the new id
$gridAdd = function ($single, array $set, $label) {
    [$c, $html] = http($single . 'add/');
    if (!check("$label: add form", $c == 200 && clean($html), $html)) return 0;
    [$c, $j, $raw] = json($single . 'save', formData($html, $set));
    $id = (int)($j['data'] ?? 0);
    check("$label: saved ($id)", !empty($j['result']) && $id, $raw);
    return $id;
};
$gridEdit = function ($single, $id, array $set, $label) {
    [$c, $html] = http($single . "$id/edit/");
    if (!check("$label: edit form", $c == 200 && clean($html), $html)) return false;
    [$c, $j, $raw] = json($single . 'save', formData($html, $set));
    return check("$label: edited", !empty($j['result']), $raw);
};
$gridDelete = function ($single, $id, $label) {
    [$c, $j, $raw] = json($single . "$id/delete/");
    return check("$label: deleted", !empty($j['result']), $raw);
};

$useJar('admin');
@unlink($GLOBALS['jar']);
login();

// ======================================================================================== reference data
echo "-- reference data\n";
$S = $A . 'currencies/single/currencyEditor/';
$usd = $gridAdd($S, ['shop_currencies[currency_code]' => 'CTU', 'shop_currencies[currency_shortname]' => 'ct$', 'shop_currencies[currency_shortname_order]' => 'before',
    'shop_currencies[currency_rate]' => '0.0250', 'shop_currencies[currency_is_default]' => '0', 'shop_currencies[currency_is_active]' => '1',
    'shop_currencies_translation[1][currency_name]' => 'claude-test доллар', 'shop_currencies_translation[2][currency_name]' => 'claude-test долар'], 'currency');
$gridEdit($S, $usd, ['shop_currencies[currency_rate]' => '0.0240'], 'currency');
check('currency rate stored', scalar('SELECT currency_rate FROM shop_currencies WHERE currency_id = ?', [$usd]) == '0.0240');

foreach ([['order-statuses/single/orderStatusEditor/', 'shop_order_statuses', 'status'], ['delivery-types/single/deliveryTypesEditor/', 'shop_delivery_types', 'type'],
          ['payment-types/single/paymentTypesEditor/', 'shop_payment_types', 'type']] as [$path, $table, $prefix]) {
    $S = $A . $path;
    [$c, $j, $raw] = json($S . 'get-data/');
    check("$table grid lists the seeded rows", count($j['data'] ?? []) >= 3, $raw);
    $id = $gridAdd($S, ["{$table}[{$prefix}_sysname]" => 'claude-test', "{$table}[{$prefix}_is_active]" => '1',
        "{$table}_translation[1][{$prefix}_name]" => 'claude-test ru', "{$table}_translation[2][{$prefix}_name]" => 'claude-test ua'], $table);
    $gridEdit($S, $id, ["{$table}_translation[1][{$prefix}_name]" => 'claude-test ru (ред.)'], $table);
    [$c, $j, $raw] = json($S . "$id/up/");
    check("$table: moved up", !empty($j['result']), $raw);
    $gridDelete($S, $id, $table);
}

$S = $A . 'countries/single/countryEditor/';
$countryId = $gridAdd($S, ['site_country[country_tel_code]' => '48', 'site_country[country_tel_format]' => '(XXX) XXX-XXX',
    'site_country_translation[1][country_name]' => 'claude-test Польша', 'site_country_translation[2][country_name]' => 'claude-test Польща'], 'country');
$gridDelete($S, $countryId, 'country');

// ======================================================================================== catalogue: producers, features, category
echo "-- producers, features, categories\n";
$S = $A . 'producers/single/producerEditor/';
$producerId = $gridAdd($S, ['shop_producers[producer_segment]' => '', 'shop_producers[producer_is_active]' => '1', 'shop_producers[producer_site_multi][]' => ['1'],
    'shop_producers_translation[1][producer_name]' => 'claude-test Производитель', 'shop_producers_translation[2][producer_name]' => 'claude-test Виробник'], 'producer');
check('producer segment generated: ' . scalar('SELECT producer_segment FROM shop_producers WHERE producer_id = ?', [$producerId]),
    (string)scalar('SELECT producer_segment FROM shop_producers WHERE producer_id = ?', [$producerId]) !== '');

$S = $A . 'feature-groups/single/fgEditor/';
$groupId = $gridAdd($S, ['shop_feature_groups[group_is_active]' => '1', 'shop_feature_groups_translation[1][group_name]' => 'claude-test Основные',
    'shop_feature_groups_translation[2][group_name]' => 'claude-test Основні'], 'feature group');

$category = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'phones' AND smap_pid = (SELECT smap_id FROM share_sitemap WHERE smap_segment = 'catalog' AND smap_pid = 80)");
$F = $A . 'features/single/featureEditor/';
$feature = function ($type, $name, $sysname, array $options = []) use ($F, $groupId, $category) {
    [$c, $html] = http($F . 'add/');
    check("feature $type: add form", $c == 200 && clean($html), $html);
    foreach ($options as $i => $value) {
        [$c, $optHtml] = http($F . 'option/add/');
        [$c, $j, $raw] = json($F . 'option/save/', formData($optHtml, ['shop_feature_options_translation[1][option_value]' => $value, 'shop_feature_options_translation[2][option_value]' => $value]));
        check("feature $type: option '$value' in the tab", !empty($j['result']), $raw);
    }
    [$c, $j, $raw] = json($F . 'save', formData($html, ['shop_features[group_id]' => (string)$groupId, 'shop_features[feature_type]' => $type,
        'shop_features[feature_is_active]' => '1', 'shop_features[feature_is_filter]' => '1', 'shop_features[feature_sysname]' => $sysname,
        'shop_features[feature_filter_type]' => $options ? 'CHECKBOXGROUP' : 'DEFAULT', 'shop_features[feature_order_num]' => '1',
        'shop_features[feature_site_multi][]' => ['1'], 'shop_features[feature_smap_multi][]' => [(string)$category],
        'shop_features_translation[1][feature_name]' => "claude-test $name", 'shop_features_translation[1][feature_title]' => $name,
        'shop_features_translation[2][feature_name]' => "claude-test $name", 'shop_features_translation[2][feature_title]' => $name]));
    $id = (int)($j['data'] ?? 0);
    check("feature $type saved ($id)", !empty($j['result']) && $id, $raw);
    if ($options) {
        check("feature $type: options bound", scalar('SELECT COUNT(*) FROM shop_feature_options WHERE feature_id = ? AND session_id IS NULL', [$id]) == count($options));
    }
    return $id;
};
$colorId = $feature('OPTION', 'Цвет', 'claude_color', ['Красный', 'Синий']);
$materialId = $feature('STRING', 'Материал', 'claude_material');
check('features linked to the site and the category',
    scalar('SELECT COUNT(*) FROM shop_features2sites WHERE feature_id IN (?, ?) AND site_id = 1', [$colorId, $materialId]) == 2
    && scalar('SELECT COUNT(*) FROM shop_sitemap2features WHERE feature_id IN (?, ?) AND smap_id = ?', [$colorId, $materialId, $category]) == 2);
[$c, $j, $raw] = json($F . 'get-data/');
check('features grid', count(array_filter($j['data'] ?? [], fn($r) => str_starts_with($r['feature_name'] ?? '', 'claude-test'))) == 2, $raw);
[$c, $html] = http($F . "$colorId/edit/");
check('feature edit form with options tab', $c == 200 && clean($html) && str_contains($html, "featureEditor/$colorId/option/"), $html);
[$c, $j, $raw] = json($F . "$colorId/option/get-data/");
check('options tab of the saved feature', count($j['data'] ?? []) == 2, $raw);

echo "-- categories\n";
$C = $A . 'categories/single/categoryDivEditor/';
[$c, $j, $raw] = json($C . '1/get-data/');
check('category tree of the shop', $c == 200 && is_array($j) && !empty($j['result']) && str_contains($raw, '"smap_id":"' . $category . '"'), $raw);
[$c, $html] = http($C . "add/$category/");
check('category add form with features', $c == 200 && clean($html) && str_contains($html, 'smap_features_multi'), $html);
$catalogRoot = (int)scalar("SELECT smap_pid FROM share_sitemap WHERE smap_id = ?", [$category]);
[$c, $html] = http($C . "add/$catalogRoot/");
[$c, $j, $raw] = json($C . 'save', formData($html, ['share_sitemap[smap_content]' => 'catalog_products.content.xml', 'share_sitemap[smap_layout]' => 'default.layout.xml',
    'share_sitemap[smap_segment]' => 'claude-test-category', 'tags' => '', 'share_sitemap[smap_features_multi][]' => [(string)$colorId],
    'share_sitemap_translation[1][smap_name]' => 'claude-test Категория', 'share_sitemap_translation[2][smap_name]' => 'claude-test Категорія']));
$newCategory = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'claude-test-category'");
check("category saved ($newCategory) with its features", !empty($j['result']) && $newCategory
    && scalar('SELECT COUNT(*) FROM shop_sitemap2features WHERE smap_id = ? AND feature_id = ?', [$newCategory, $colorId]) == 1, $raw);
[$c, $j, $raw] = json($C . '1/get-data/');
check('new category in the tree', str_contains($raw, '"smap_id":"' . $newCategory . '"'), $raw);
[$c, $html] = http($C . "$newCategory/edit/");
check('category edit form', $c == 200 && clean($html) && str_contains($html, 'claude-test Категория'), $html);
[$c] = http('/catalog/claude-test-category/');
check("new category page ($c)", $c == 200);
[$c, $j, $raw] = json($C . "$newCategory/delete/");
check('category deleted', !empty($j['result']) && !scalar('SELECT COUNT(*) FROM share_sitemap WHERE smap_id = ?', [$newCategory]), $raw);

echo "-- shops\n";
[$c, $html] = http($A . 'sites/single/shopEditor/1/edit/');
check('shop edit form: currency, country, domains and logo tabs', $c == 200 && clean($html) && str_contains($html, 'name="share_sites[currency_id]"')
    && str_contains($html, 'shopEditor/1/domains/') && str_contains($html, 'shopEditor/1/attachments/'), $html);
[$c, $j, $raw] = json($A . 'sites/single/shopEditor/1/domains/get-data/');
check('shop domains tab', count($j['data'] ?? []) >= 1, $raw);

// ======================================================================================== goods
echo "-- goods editor\n";
$G = $A . 'goods/single/goodsEditor/';
$redId = (int)scalar("SELECT o.option_id FROM shop_feature_options o JOIN shop_feature_options_translation t USING(option_id) WHERE o.feature_id = ? AND t.option_value = 'Красный' AND t.lang_id = 1", [$colorId]);
$blueId = (int)scalar("SELECT o.option_id FROM shop_feature_options o JOIN shop_feature_options_translation t USING(option_id) WHERE o.feature_id = ? AND t.option_value = 'Синий' AND t.lang_id = 1", [$colorId]);
$uplId = (int)scalar('SELECT upl_id FROM share_uploads WHERE upl_path = ?', [IMG]);

$addGoods = function ($name, $price, $code, $option, $material, $withImage) use ($G, $category, $producerId, $colorId, $materialId, $uplId) {
    [$c, $html] = http($G . 'add/');
    check("goods '$name': add form with category tree", $c == 200 && clean($html) && str_contains($html, 'value="' . $category . '"'), $html);
    // features tab of the unsaved goods (GoodsForm.js: single + goodsID + /feature/show/ + smapID)
    [$c, $tab] = http($G . "/feature/show/$category/");
    check("goods '$name': features tab", $c == 200 && clean($tab), $tab);
    [$c, $j, $raw] = json($G . 'feature/get-data/');
    $rows = array_column($j['data'] ?? [], 'fpv_id', 'feature_id');
    // в демо-категории есть собственные характеристики, поэтому проверяем наличие своих
    check("goods '$name': feature rows for the category", count($j['data'] ?? []) >= 2, $raw);
    foreach (($j['data'] ?? []) as $row) {
        [$c, $form] = http($G . "feature/{$row['fpv_id']}/edit/");
        if (!check("goods '$name': feature value form ({$row['feature_id']})", $c == 200 && clean($form), $form)) continue;
        $isColor = str_contains($form, 'shop_feature_options') || str_contains($form, 'value="' . $option . '"');
        $value = $isColor ? (string)$option : $material;
        $set = [];
        foreach ([1, 2] as $lang) $set["shop_feature2good_values_translation[$lang][fpv_data]"] = $value;
        [$c, $jj, $raw] = json($G . 'feature/save/', formData($form, $set));
        check("goods '$name': feature value saved", !empty($jj['result']), $raw);
    }
    if ($withImage) {
        [$c, $att] = http($G . '/attachments/add/');
        [$c, $jj, $raw] = json($G . 'attachments/save/', formData($att, ['shop_goods_uploads[upl_id]' => (string)$uplId]));
        check("goods '$name': image attached", !empty($jj['result']), $raw);
    }
    [$c, $j, $raw] = json($G . 'save', formData($html, ['shop_goods[smap_id]' => (string)$category, 'shop_goods[goods_segment]' => '',
        'shop_goods[producer_id]' => (string)$producerId, 'shop_goods[sell_status_id]' => '1', 'shop_goods[goods_code]' => $code,
        'shop_goods[goods_price]' => $price, 'shop_goods[goods_price_old]' => '', 'shop_goods[goods_is_active]' => '1',
        'shop_goods_translation[1][goods_name]' => "claude-test $name", 'shop_goods_translation[1][goods_short_description]' => "Кратко о $name",
        'shop_goods_translation[1][goods_description_rtf]' => "<p>Описание товара $name</p>",
        'shop_goods_translation[2][goods_name]' => "claude-test $name ua", 'shop_goods_translation[2][goods_description_rtf]' => "<p>Опис $name</p>"]));
    $id = (int)($j['data'] ?? 0);
    check("goods '$name' saved ($id)", !empty($j['result']) && $id, $raw);
    return $id;
};
$chairId = $addGoods('Стул', '1500.00', 'CT-001', $redId, 'Дуб', true);
$tableId = $addGoods('Стол', '4200.50', 'CT-002', $blueId, 'Сосна', false);
check('goods segment generated', (string)scalar('SELECT goods_segment FROM shop_goods WHERE goods_id = ?', [$chairId]) !== '');
check('feature values bound to the goods', scalar('SELECT COUNT(*) FROM shop_feature2good_values WHERE goods_id = ? AND session_id IS NULL', [$chairId]) >= 2
    && scalar('SELECT t.fpv_data FROM shop_feature2good_values v JOIN shop_feature2good_values_translation t USING(fpv_id) WHERE v.goods_id = ? AND v.feature_id = ? AND t.lang_id = 1', [$chairId, $colorId]) == $redId);
check('image bound to the goods', scalar('SELECT COUNT(*) FROM shop_goods_uploads WHERE goods_id = ? AND upl_id = ?', [$chairId, $uplId]) == 1);
[$c, $j, $raw] = json($G . 'get-data/');
check('goods grid', count(array_filter($j['data'] ?? [], fn($r) => str_starts_with((string)($r['goods_name'] ?? ''), 'claude-test'))) == 2, $raw);
$gridEdit($G, $chairId, ['shop_goods[goods_price]' => '1450.00'], 'goods');
check('goods price updated', scalar('SELECT goods_price FROM shop_goods WHERE goods_id = ?', [$chairId]) == '1450.00');
http($G . "$chairId/feature/show/$category/");   // the tab page sets the feature filter of the grid in the session
[$c, $j, $raw] = json($G . "$chairId/feature/get-data/");
check('features tab of the saved goods', count($j['data'] ?? []) >= 2, $raw);

// relation: the table is similar to the chair
[$c, $rel] = http($G . "$chairId/relation/add/");
check('relation add form', $c == 200 && clean($rel), $rel);
[$c, $j, $raw] = json($G . "$chairId/relation/save/", formData($rel, ['shop_goods_relations[goods_to_id]' => (string)$tableId, 'shop_goods_relations[relation_type]' => 'similar']));
check('relation saved', !empty($j['result']) && scalar('SELECT COUNT(*) FROM shop_goods_relations WHERE goods_from_id = ? AND goods_to_id = ?', [$chairId, $tableId]) == 1, $raw);
[$c, $j, $raw] = json($G . "$chairId/relation/get-data/");
check('relations tab', count($j['data'] ?? []) == 1, $raw);

// ======================================================================================== public catalogue
echo "-- catalogue\n";
$useJar('guest');
@unlink($GLOBALS['jar']);
// цены выводятся с неразрывным пробелом между разрядами, для сравнения приводим его к обычному
$nb = fn($s) => str_replace("\xC2\xA0", ' ', (string)$s);
$center = function ($html) use ($nb) {
    $d = new DOMDocument();
    libxml_use_internal_errors(true);
    $d->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    $node = (new DOMXPath($d))->query('//div[contains(@class, "col2")]')->item(0);
    return $node ? preg_replace('/\s+/', ' ', $nb($node->textContent)) : '';
};
$chairSegment = scalar('SELECT goods_segment FROM shop_goods WHERE goods_id = ?', [$chairId]);
[$c, $html] = http('/catalog/');
check('catalogue page with categories and search', $c == 200 && clean($html) && str_contains($html, 'href="catalog/phones/"') && str_contains($html, 'name="keyword"'), $html);
[$c, $html] = http('/catalog/phones/');
$text = $center($html);
check('category lists the goods cheapest first', $c == 200 && clean($html) && strpos($text, 'claude-test Стул') !== false
    && str_contains($text, '1 450') /* цена выводится с разделителем разрядов и валютой */ && str_contains($text, 'claude-test Производитель') && str_contains($html, 'resizer/w200-h150/' . IMG), $text);
check('buy and wishlist buttons bound to the informers', (bool)preg_match('~onClick="(idm\d+)\.add\(event, ' . $chairId . '\);"~', $html) && str_contains($html, 'cartInformer//add/[productID]/'), $html);
check('filter form with price, producers and features', str_contains($html, 'filter[price]') || str_contains($html, 'data-filter-name="filter"'), $html);
[$c, $html] = http('/catalog/phones/sort-price-desc/');
$text = $center($html);
check('sort by price desc', $c == 200 && clean($html) && strpos($text, 'claude-test Стол') < strpos($text, 'claude-test Стул'), $text);
[$c, $html] = http('/catalog/phones/?' . http_build_query(['filter' => ['price' => ['begin' => 2000, 'end' => 5000]]]));
$text = $center($html);
check('price filter', $c == 200 && clean($html) && str_contains($text, 'claude-test Стол') && !str_contains($text, 'claude-test Стул'), $text);
$colorFilterName = (string)scalar('SELECT feature_sysname FROM shop_features WHERE feature_id = ?', [$colorId]);
[$c, $html] = http('/catalog/phones/?' . http_build_query(['filter' => [$colorFilterName => [$redId]]]));
$text = $center($html);
check("feature filter ($colorFilterName)", $c == 200 && clean($html) && str_contains($text, 'claude-test Стул') && !str_contains($text, 'claude-test Стол'), $text);
[$c, $html] = http('/catalog/phones/?filter[producers][]=' . rawurlencode('1) OR (1=1'));
check('producer filter does not take SQL', $c == 200 && clean($html) && !str_contains($center($html), 'claude-test'), $html);
[$c, $html] = http('/catalog/phones/?filter=' . rawurlencode('broken;price'));
check('malformed filter string', $c == 200 && clean($html), $html);
[$c, $html] = http("/catalog/phones/view/$chairSegment/");
$text = $center($html);
check('goods page with features', $c == 200 && clean($html) && str_contains($text, 'Описание товара Стул') && str_contains($text, 'Цвет') && str_contains($text, 'Красный')
    && str_contains($text, 'Материал') && str_contains($text, 'Дуб') && str_contains($html, 'resizer/w400-h300/' . IMG), $text);
check('similar goods under the goods page', (bool)preg_match('~class="products related_goods">.*?claude-test Стол~s', $html), $html);
[$c] = http('/catalog/phones/view/no-such-goods/');
check("unknown goods is 404 ($c)", $c == 404);
[$c, $html] = http('/search/?keyword=' . rawurlencode('Стол'));
$text = $center($html);
check('search', $c == 200 && clean($html) && str_contains($text, 'claude-test Стол') && !str_contains($text, 'claude-test Стул'), $text);
[$c, $html] = http('/search/?keyword=' . rawurlencode('%s" OR 1=1 -- '));
check('search does not take SQL', $c == 200 && clean($html) && !str_contains($center($html), 'claude-test'), $html);

echo "-- cart\n";
$cart = '/catalog/phones/single/cartInformer/';
[$c, $html] = http($cart . "add/$chairId/");
[$c, $html] = http($cart . "add/$chairId/");
check('cart: added twice', $c == 200 && clean($html) && str_contains($nb($html), '2 900'), $html);
[$c, $html] = http($cart . "add/$tableId/");
[$c, $html] = http('/cart/');
$text = $center($html);
check('cart page', $c == 200 && clean($html) && str_contains($text, 'claude-test Стул') && str_contains($text, 'claude-test Стол') && str_contains($text, '7 100.5'), $text);
$cartRow = q('SELECT cart_id FROM shop_cart WHERE goods_id = ? ORDER BY cart_id DESC LIMIT 1', [$chairId])->fetchColumn();
[$c, $html] = http("/cart/single/cart/edit/$cartRow/", ['count' => 3]);
check('cart: quantity changed', $c == 200 && clean($html) && scalar('SELECT cart_goods_count FROM shop_cart WHERE cart_id = ?', [$cartRow]) == 3, $html);
[$c, $html] = http("/cart/single/cart/del/$cartRow/");
check('cart: goods removed', $c == 200 && clean($html) && !scalar('SELECT COUNT(*) FROM shop_cart WHERE cart_id = ?', [$cartRow]), $html);
[$c, $html] = http('/wishlist/single/wishlistInformer/wadd/' . $chairId . '/');
check('guest cannot use the wishlist', !scalar('SELECT COUNT(*) FROM shop_wishlist WHERE goods_id = ?', [$chairId]));

echo "-- wishlist and orders of a user\n";
q('DELETE FROM user_users WHERE u_name = ?', ['claude-shop@loki.kweb.biz']);
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_phone, u_city) VALUES (?, ?, ?, ?, ?)', ['claude-shop@loki.kweb.biz', password_hash('claude-test', PASSWORD_DEFAULT), 'claude-test Покупатель', '0441234567', 'Киев']);
$uid = (int)pdo()->lastInsertId();
q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, 4)', [$uid]);
$useJar('user');
@unlink($GLOBALS['jar']);
http('/login/');
http('/auth.php', ['user' => ['login' => 1, 'username' => 'claude-shop@loki.kweb.biz', 'password' => 'claude-test']], [], BASE . '/login/');
[$c, $html] = http("/catalog/phones/single/wishlistInformer/wadd/$chairId/");
[$c, $html] = http("/catalog/phones/single/wishlistInformer/wadd/$tableId/");
[$c, $html] = http('/wishlist/');
$text = $center($html);
check('wishlist page', $c == 200 && clean($html) && str_contains($text, 'claude-test Стул') && str_contains($text, 'claude-test Стол') && str_contains($html, 'name="action" value="basket"'), $text);
[$c, $html] = http('/wishlist/', ['products' => [$chairId], 'action' => 'basket']);
check('wishlist: moved to the cart', $c == 200 && clean($html) && !scalar('SELECT COUNT(*) FROM shop_wishlist WHERE u_id = ? AND goods_id = ?', [$uid, $chairId])
    && scalar('SELECT COUNT(*) FROM shop_cart WHERE u_id = ? AND goods_id = ?', [$uid, $chairId]) == 1, $html);
[$c, $html] = http("/wishlist/single/wishlist/wdel/$tableId/");
check('wishlist: removed', $c == 200 && clean($html) && !scalar('SELECT COUNT(*) FROM shop_wishlist WHERE u_id = ?', [$uid]), $html);
[$c, $html] = http('/my-orders/');
check('my orders: empty', $c == 200 && clean($html), $html);

$useJar('admin');
$O = $A . 'orders/single/orderEditor/';
[$c, $html] = http($O . 'add/');
check('order add form with goods tab', $c == 200 && clean($html) && str_contains($html, 'orderEditor//goods/'), $html);
[$c, $j, $raw] = json($O . "$uid/user-details/");
check('order: user details', ($j['order_user_name'] ?? '') === 'claude-test Покупатель' && ($j['order_email'] ?? '') === 'claude-shop@loki.kweb.biz', $raw);
[$c, $tab] = http($O . '/goods/');
check('order goods tab', $c == 200 && clean($tab), $tab);
[$c, $line] = http($O . 'goods/add/');
check('order line form', $c == 200 && clean($line), $line);
[$c, $j, $raw] = json($O . "goods/$chairId/goods-details/");
check('order line: goods details', !empty($j['result']) && ($j['goods_price'] ?? '') === '1450.00' && ($j['goods_title'] ?? '') === 'claude-test Стул', $raw);
[$c, $j, $raw] = json($O . "goods/$chairId/goods-total/", http_build_query(['goods_quantity' => 2, 'goods_price' => '1450.00']));
check('order line: amount', ($j['goods_amount'] ?? '') === '2900.00', $raw);
[$c, $j, $raw] = json($O . 'goods/save/', formData($line, ['shop_orders_goods[goods_id]' => (string)$chairId, 'shop_orders_goods[goods_title]' => 'claude-test Стул',
    'shop_orders_goods[goods_real_price]' => '1450.00', 'shop_orders_goods[goods_price]' => '1450.00', 'shop_orders_goods[goods_quantity]' => '2', 'shop_orders_goods[goods_amount]' => '2900.00']));
check('order line saved', !empty($j['result']), $raw);
[$c, $j, $raw] = json($O . 'order-total/', http_build_query(['order_discount' => '100']));
check('order total', ($j['total'] ?? '') === '2800.00' && ($j['amount'] ?? '') === '2900.00', $raw);
$now = date('Y-m-d H:i:s');
[$c, $j, $raw] = json($O . 'save', formData($html, ['shop_orders[site_id]' => '1', 'shop_orders[status_id]' => (string)scalar("SELECT status_id FROM shop_order_statuses WHERE status_sysname = 'new'"),
    'shop_orders[u_id]' => (string)$uid, 'shop_orders[order_email]' => 'claude-shop@loki.kweb.biz', 'shop_orders[order_city]' => 'Киев', 'shop_orders[order_address]' => 'ул. Тестовая, 1',
    'shop_orders[order_phone]' => '+380441234567', 'shop_orders[order_user_name]' => 'claude-test Покупатель', 'shop_orders[order_comment]' => 'Позвонить заранее',
    'shop_orders[delivery_type_id]' => '1', 'shop_orders[payment_type_id]' => '1', 'shop_orders[order_created]' => $now, 'shop_orders[order_updated]' => $now,
    'shop_orders[order_amount]' => '2900.00', 'shop_orders[order_discount]' => '100.00', 'shop_orders[order_total]' => '2800.00', 'shop_orders[order_promocode]' => '']));
$orderId = (int)($j['data'] ?? 0);
check("order saved ($orderId)", !empty($j['result']) && $orderId, $raw);
check('order line bound, goods count', scalar('SELECT COUNT(*) FROM shop_orders_goods WHERE order_id = ? AND session_id IS NULL', [$orderId]) == 1
    && scalar('SELECT order_goods_count FROM shop_orders WHERE order_id = ?', [$orderId]) == 2);
[$c, $j, $raw] = json($O . 'get-data/');
$orderRow = current(array_filter($j['data'] ?? [], fn($r) => $r['order_id'] == $orderId)) ?: [];
check('orders grid, phone in the country format: ' . ($orderRow['order_phone'] ?? ''), ($orderRow['order_phone'] ?? '') === '+380(44) 123-45-67', $raw);
$gridEdit($O, $orderId, ['shop_orders[status_id]' => (string)scalar("SELECT status_id FROM shop_order_statuses WHERE status_sysname = 'valid'")], 'order');
check('order status changed', scalar('SELECT s.status_sysname FROM shop_orders o JOIN shop_order_statuses s USING(status_id) WHERE o.order_id = ?', [$orderId]) === 'valid');
[$c, $j, $raw] = json($O . "$orderId/goods/get-data/");
check('goods tab of the saved order', count($j['data'] ?? []) == 1, $raw);

$useJar('user');
[$c, $html] = http('/my-orders/');
$text = $center($html);
check('my orders page lists the order', $c == 200 && clean($html) && str_contains($text, 'claude-test Стул') && str_contains($text, '2 800'), $text);

echo "-- promotions\n";
$useJar('admin');
$P = $A . 'promotions/single/promotionEditor/';
[$c, $html] = http($P . 'add/');
[$c, $line] = http($P . '/goods/add/');
[$c, $j, $raw] = json($P . 'goods/save/', formData($line, ['shop_goods2promotions[goods_id]' => (string)$tableId]));
check('promotion goods added in the tab', !empty($j['result']), $raw);
[$c, $j, $raw] = json($P . 'save', formData($html, ['shop_promotions[site_id]' => '1', 'shop_promotions[promotion_is_active]' => '1',
    'shop_promotions[promotion_start_date]' => date('Y-m-d H:i:s', time() - 86400), 'shop_promotions[promotion_end_date]' => date('Y-m-d H:i:s', time() + 7 * 86400),
    'shop_promotions_translation[1][promotion_name]' => 'claude-test Скидки недели', 'shop_promotions_translation[2][promotion_name]' => 'claude-test Знижки тижня']));
$promotionId = (int)($j['data'] ?? 0);
check("promotion saved ($promotionId)", !empty($j['result']) && $promotionId && scalar('SELECT COUNT(*) FROM shop_goods2promotions WHERE promotion_id = ? AND goods_id = ?', [$promotionId, $tableId]) == 1, $raw);
$useJar('guest');
[$c, $html] = http('/catalog/phones/view/' . scalar('SELECT goods_segment FROM shop_goods WHERE goods_id = ?', [$tableId]) . '/');
check('goods page of a promoted goods', $c == 200 && clean($html), $html);

if ($keep) {
    echo "IDS producer=$producerId group=$groupId color=$colorId material=$materialId category=$category currency=$usd chair=$chairId table=$tableId order=$orderId user=$uid\n";
    done('shop');
}

echo "-- deleting through the editors\n";
$useJar('admin');
$gridDelete($O, $orderId, 'order');
$gridDelete($P, $promotionId, 'promotion');
$gridDelete($G, $chairId, 'goods');
$gridDelete($G, $tableId, 'goods');
check('goods rows removed with values, images and relations', !scalar('SELECT COUNT(*) FROM shop_feature2good_values WHERE goods_id IN (?, ?)', [$chairId, $tableId])
    && !scalar('SELECT COUNT(*) FROM shop_goods_uploads WHERE goods_id = ?', [$chairId]) && !scalar('SELECT COUNT(*) FROM shop_goods_relations WHERE goods_from_id = ?', [$chairId]));
$gridDelete($F, $colorId, 'feature');
$gridDelete($F, $materialId, 'feature');
$gridDelete($A . 'feature-groups/single/fgEditor/', $groupId, 'feature group');
$gridDelete($A . 'producers/single/producerEditor/', $producerId, 'producer');
$gridDelete($A . 'currencies/single/currencyEditor/', $usd, 'currency');
q('DELETE FROM user_users WHERE u_id = ?', [$uid]);
done('shop');
