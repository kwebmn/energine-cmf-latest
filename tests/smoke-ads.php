<?php
// Ads module end-to-end: banner places, banners (image/html, sites, categories, order, activity), banner widget on a page.
// Everything created is named claude-test*; cleanup-mail.php removes leftovers.
require __DIR__ . '/testlib.php';

const IMG = 'uploads/public/13662314846.png';
// testlib keeps the cookie file in the global $jar
$useJar = function ($name) { $GLOBALS['jar'] = __DIR__ . "/cookies-mail-ads-$name.txt"; };

$useJar('admin');
login();
$T = '/admin/ads-types/single/adsTypeEditor/';
$I = '/admin/ads-items/single/adsItemEditor/';
$pageSegment = 'claude-test-ads';

try {
    // ---------------------------------------------------------------- banner places
    [$c, $j, $raw] = json($T . 'get-data/');
    check('banner places grid', $c == 200 && in_array('sidebar', array_column($j['data'] ?? [], 'ads_type_sysname')), $raw);
    [$c, $html] = http($T . 'add/');
    check('banner place add form', $c == 200 && clean($html), $html);
    [$c, $j, $raw] = json($T . 'save', formData($html, ['ads_types[ads_type_sysname]' => 'claude-test-top', 'ads_types[ads_type_name]' => 'claude-test Верх страницы',
        'ads_types[ads_type_width]' => '728', 'ads_types[ads_type_height]' => '90']));
    $typeId = (int)($j['data'] ?? 0);
    check("banner place saved ($typeId)", !empty($j['result']) && $typeId, $raw);
    [$c, $html] = http($T . "$typeId/edit/");
    [$c, $j, $raw] = json($T . 'save', formData($html, ['ads_types[ads_type_height]' => '120']));
    check('banner place edited', !empty($j['result']) && scalar('SELECT ads_type_height FROM ads_types WHERE ads_type_id = ?', [$typeId]) == 120, $raw);

    // ---------------------------------------------------------------- banners
    [$c, $html] = http($I . 'add/');
    $banners = scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'banners'");
    check('banner add form: active by default, sites and categories', $c == 200 && clean($html)
        && preg_match('~name="ads_items\[ads_item_is_active\]"[^>]*checked~', $html) && str_contains($html, 'name="ads_items[ads_item_site_multi][]"')
        && str_contains($html, 'value="' . $banners . '"') && str_contains($html, 'AdsItemForm'), $html);
    $base = ['ads_items[ads_type_id]' => (string)$typeId, 'ads_items[ads_item_site_multi][]' => ['1'], 'ads_items[ads_item_smap_multi][]' => [(string)$banners]];
    [$c, $j, $raw] = json($I . 'save', formData($html, $base + ['ads_items[ads_item_name]' => 'claude-test image', 'ads_items[ads_item_mode]' => 'image',
        'ads_items[ads_item_img]' => IMG, 'ads_items[ads_item_url]' => BASE . '/news/']));
    $imageId = (int)($j['data'] ?? 0);
    check("image banner saved ($imageId)", !empty($j['result']) && $imageId, $raw);
    [$c, $html] = http($I . 'add/');
    [$c, $j, $raw] = json($I . 'save', formData($html, $base + ['ads_items[ads_item_name]' => 'claude-test html', 'ads_items[ads_item_mode]' => 'html',
        'ads_items[ads_item_html]' => '<div class="claude-test-html">HTML-баннер</div>']));
    $htmlId = (int)($j['data'] ?? 0);
    check("html banner saved ($htmlId)", !empty($j['result']) && $htmlId, $raw);
    check('links to sites and categories stored',
        q('SELECT COUNT(*) FROM ads_items2sites WHERE ads_item_id IN (?, ?) AND site_id = 1', [$imageId, $htmlId])->fetchColumn() == 2
        && q('SELECT COUNT(*) FROM ads_items2sitemap WHERE ads_item_id IN (?, ?) AND smap_id = ?', [$imageId, $htmlId, $banners])->fetchColumn() == 2);
    [$c, $html] = http($I . "$imageId/edit/");
    check('banner edit form keeps selections', $c == 200 && clean($html) && preg_match('~value="' . $banners . '"[^>]*checked~', $html) && str_contains($html, IMG), $html);
    [$c, $j, $raw] = json($I . 'get-data/');
    $names = array_column($j['data'] ?? [], 'ads_item_name');
    check('banners grid: newest first', array_slice($names, 0, 2) == ['claude-test html', 'claude-test image'], $raw);
    [$c, $j, $raw] = json($I . "$imageId/up/");
    [$c, $j2, $raw2] = json($I . 'get-data/');
    check('banner moved up', !empty($j['result']) && array_slice(array_column($j2['data'] ?? [], 'ads_item_name'), 0, 2) == ['claude-test image', 'claude-test html'], $raw . $raw2);

    // ---------------------------------------------------------------- banner widget on a page
    $page = ['componentAction' => 'add', 'share_sitemap' => ['smap_id' => '', 'smap_pid' => '80', 'site_id' => '1', 'smap_layout' => 'default.layout.xml',
        'smap_content' => 'textblock.content.xml', 'smap_segment' => $pageSegment, 'smap_redirect_url' => ''],
        'right_id' => [1 => 3, 3 => 1, 4 => 1], 'tags' => '',
        'share_sitemap_translation' => [1 => ['smap_name' => 'claude-test баннер'], 2 => ['smap_name' => 'claude-test банер']]];
    [$c, $j, $raw] = json('/admin/structure/single/divEditor/save', http_build_query($page));
    $smapId = scalar('SELECT smap_id FROM share_sitemap WHERE smap_segment = ?', [$pageSegment]);
    check("test page created ($smapId)", !empty($j['result']) && $smapId, $raw);
    [$c, $html] = http("/$pageSegment/", ['editMode' => 1]);
    $panel = preg_match("~new PageToolbar\\('([^']+)'~", $html, $mm) ? $mm[1] : BASE . "/$pageSegment/single/adminPanel/";
    $widget = scalar("SELECT widget_xml FROM share_widgets WHERE widget_xml LIKE '%ads\\\\\\\\components\\\\\\\\Ads%'");
    [$c, $body] = http($panel . 'widgets/');
    [$c2, $j, $raw] = json($panel . 'widgets/get-data/');
    check('banner widget in the widgets list', $c == 200 && clean($body) && in_array('Баннер', array_column($j['data'] ?? [], 'widget_name')), $raw);
    [$c, $body] = http($panel . 'widgets/build-widget/', ['xml' => $widget]);
    check('banner widget preview', $c == 200 && clean($body), $body);
    $widget = str_replace(['name="AdsContainer"', 'name="Ads"', '>sidebar<', '<param name="limit">1</param>', '<param name="order">rand</param>'],
        ['name="AdsContainer1"', 'name="Ads1"', '>claude-test-top<', '<param name="limit">2</param>', '<param name="order">num</param>'], $widget);
    [$c, $body] = http($panel . 'widgets/edit-params/Ads1/', ['modalBoxData' => $widget]);
    check('banner widget parameters form', $c == 200 && clean($body) && str_contains($body, 'claude-test-top'), $body);
    $content = str_replace('<container name="leftAdBlock"/>', $widget, file_get_contents(WEB . '/templates/content/textblock.content.xml'));
    [$c, $j, $raw] = json($panel . 'widgets/save-content/', http_build_query(['xml' => $content]));
    check('banner widget placed', !empty($j['result']) && str_contains((string)scalar('SELECT smap_content_xml FROM share_sitemap WHERE smap_id = ?', [$smapId]), 'claude-test-top'), $raw);
    [$c, $body] = http("/$pageSegment/");
    check('edit mode page with banners', $c == 200 && clean($body), $body);

    $useJar('guest');
    @unlink($GLOBALS['jar']);
    $render = function () use ($pageSegment) {
        [$c, $body] = http("/$pageSegment/");
        return [$c, $body, preg_match('~<div class="ads ads_claude-test-top">.*?</div></div>~s', $body, $mm) ? $mm[0] : ''];
    };
    // баннеры привязаны к разделу «Рубрики баннеров», а страница другая: показывать нечего
    [$c, $body, $ads] = $render();
    check('banner bound to another page stays hidden', $c == 200 && clean($body) && !str_contains($body, IMG) && !str_contains($body, 'claude-test-html'), $ads ?: $body);

    // переносим привязку на тестовую страницу через форму редактора
    $useJar('admin');
    foreach ([$imageId, $htmlId] as $id) {
        [$c, $html] = http($I . "$id/edit/");
        [$c, $j, $raw] = json($I . 'save', formData($html, ['ads_items[ads_item_smap_multi][]' => [(string)$smapId]]));
        check("banner $id rebound to the test page", !empty($j['result'])
            && scalar('SELECT smap_id FROM ads_items2sitemap WHERE ads_item_id = ?', [$id]) == $smapId, $raw);
    }
    $useJar('guest');
    @unlink($GLOBALS['jar']);
    [$c, $body, $ads] = $render();
    check('guest sees both banners in order', $c == 200 && clean($body) && !str_contains($body, '<component') && strpos($ads, IMG) !== false
        && strpos($ads, IMG) < strpos($ads, 'claude-test-html'), $ads ?: $body);
    check('image banner markup', str_contains($ads, '<a href="' . BASE . '/news/"><img src="' . BASE . '/' . IMG . '" alt="claude-test image" width="728" height="120"></a>'), $ads);
    check('html banner markup', str_contains($ads, '<div class="claude-test-html">HTML-баннер</div>'), $ads);
    check('no page structure in the banner block', !str_contains($body, 'smap_content_xml'), $body);
    q('UPDATE ads_items SET ads_item_is_active = 0 WHERE ads_item_id = ?', [$imageId]);
    [$c, $body, $ads] = $render();
    check('inactive banner hidden', $ads && !str_contains($ads, IMG) && str_contains($ads, 'claude-test-html'), $ads ?: $body);
    q('UPDATE ads_items SET ads_item_is_active = 1 WHERE ads_item_id = ?', [$imageId]);
    q("UPDATE share_sitemap SET smap_content_xml = REPLACE(smap_content_xml, '<param name=\"limit\">2</param>', '<param name=\"limit\">1</param>') WHERE smap_id = ?", [$smapId]);
    $seen = [];
    for ($i = 0; $i < 12; $i++) {
        q("UPDATE share_sitemap SET smap_content_xml = REPLACE(smap_content_xml, '<param name=\"order\">num</param>', '<param name=\"order\">rand</param>') WHERE smap_id = ?", [$smapId]);
        [$c, $body, $ads] = $render();
        $seen[str_contains($ads, IMG) ? 'image' : (str_contains($ads, 'claude-test-html') ? 'html' : 'none')] = true;
    }
    check('limit 1, random order: ' . implode(',', array_keys($seen)), isset($seen['image'], $seen['html']) && !isset($seen['none']));

    $useJar('admin');
    foreach ([$imageId, $htmlId] as $id) {
        [$c, $j, $raw] = json($I . "$id/delete/");
        check("banner $id deleted", !empty($j['result']) && !scalar('SELECT COUNT(*) FROM ads_items2sitemap WHERE ads_item_id = ?', [$id]), $raw);
    }
    $useJar('guest');
    [$c, $body] = http("/$pageSegment/");
    check('no banners: no block, no raw component', $c == 200 && clean($body) && !str_contains($body, 'ads_claude-test-top') && !str_contains($body, '<component'), $body);
    $useJar('admin');
    [$c, $j, $raw] = json($T . "$typeId/delete/");
    check('banner place deleted', !empty($j['result']), $raw);
} finally {
    $useJar('admin');
    if ($id = scalar('SELECT smap_id FROM share_sitemap WHERE smap_segment = ?', [$pageSegment])) {
        [$c, $j, $raw] = json("/admin/structure/single/divEditor/$id/delete/");
        check('test page deleted', !empty($j['result']), $raw);
    }
    foreach (glob(__DIR__ . '/cookies-mail-ads-*.txt') as $f) unlink($f);
}
done('ads');
