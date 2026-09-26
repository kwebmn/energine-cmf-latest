-- Energine Simple, этап 1: вырезаны модули shop, blog, comments, calendar, forms, ads
-- и рассылки модуля mail. Отправка писем и шаблоны писем остались в ядре.
--
-- Переходный скрипт. Применяется после восьми файлов установки полной системы
-- (docs/INSTALL.md) и переводит базу, уже работающую на этапе 0. Повторный прогон
-- на той же базе ничего не меняет. Сведение установки в один файл — этап 5.
-- Файлы демо-контента, которые после этого ни к чему не привязаны, перечислены
-- в stage1.files.

SET SESSION group_concat_max_len = 65535;

-- 1. Колонки магазина в оставшихся таблицах вместе с внешними ключами.
ALTER TABLE `share_sites` DROP FOREIGN KEY IF EXISTS `share_sites_shop_ibfk_1`;
ALTER TABLE `share_sites` DROP FOREIGN KEY IF EXISTS `share_sites_shop_ibfk_2`;
ALTER TABLE `share_sites` DROP COLUMN IF EXISTS `currency_id`, DROP COLUMN IF EXISTS `country_id`;
ALTER TABLE `share_sitemap` DROP FOREIGN KEY IF EXISTS `share_sitemap_shop_ibfk_1`;
ALTER TABLE `share_sitemap` DROP COLUMN IF EXISTS `smap_features_multi`;

-- 2. Таблицы вырезанных модулей. Список берётся из information_schema, поэтому
--    скрипт не ломается, если части таблиц уже нет. Внешние ключи между ними
--    отключаются только на время удаления.
DROP VIEW IF EXISTS `shop_goods_view`;
SET @cut_tables := (
    SELECT GROUP_CONCAT(CONCAT('`', `TABLE_NAME`, '`') SEPARATOR ', ')
      FROM `information_schema`.`TABLES`
     WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_TYPE` = 'BASE TABLE'
       AND (`TABLE_NAME` LIKE 'shop\_%' OR `TABLE_NAME` LIKE 'blog\_%' OR `TABLE_NAME` LIKE 'ads\_%'
            OR `TABLE_NAME` LIKE 'frm\_%' OR `TABLE_NAME` REGEXP '^form_[0-9]+'
            OR (`TABLE_NAME` LIKE 'mail\_%' AND `TABLE_NAME` NOT LIKE 'mail\_templates%')
            OR `TABLE_NAME` IN ('site_address', 'site_country', 'site_country_translation',
                                'share_sitemap_comment', 'apps_news_comment', 'share_sites_uploads'))
);
SET @sql := IF(@cut_tables IS NULL, 'DO 0', CONCAT('DROP TABLE IF EXISTS ', @cut_tables));
SET FOREIGN_KEY_CHECKS = 0;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;

-- 3. Страницы вырезанных модулей: сайт, админка, путеводитель «Возможности».
--    Родитель ищется от корня, поэтому одноимённые разделы глубже не задеваются
--    (например, features/admin). Поддеревья, переводы, права, тексты и вложения
--    удаляются каскадом.
CREATE TEMPORARY TABLE `cut_pages` (`smap_id` INT UNSIGNED NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` root ON root.`smap_id` = s.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` IN ('catalog', 'blogs', 'form-example', 'subscribe', 'subscriptions',
                                'my-orders', 'search', 'cart', 'wishlist', 'banners');
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` p ON p.`smap_id` = s.`smap_pid` AND p.`smap_segment` = 'admin'
      JOIN `share_sitemap` root ON root.`smap_id` = p.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` IN ('comments-editor', 'form-builder', 'mail-subscriptions', 'mail-subscribers',
                                'mail-crm', 'ads-types', 'ads-items', 'blogs', 'shop');
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` p ON p.`smap_id` = s.`smap_pid` AND p.`smap_segment` = 'features'
      JOIN `share_sitemap` root ON root.`smap_id` = p.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` IN ('blogs', 'shop', 'forms', 'comments', 'mail', 'ads');
DELETE s FROM `share_sitemap` s JOIN `cut_pages` c USING (`smap_id`);
DROP TEMPORARY TABLE `cut_pages`;

-- 4. Виджет «Баннер».
DELETE FROM `share_widgets` WHERE LOCATE('Energine\\ads\\', `widget_xml`) > 0;

-- 5. Место под баннерный виджет в XML страниц. В базе оно записано так, как его
--    сериализует DOM (<container ...></container>), в шаблонах — пустым тегом.
UPDATE `share_sitemap`
   SET `smap_content_xml` = REPLACE(REPLACE(`smap_content_xml`,
           '<container name="leftAdBlock"></container>', ''), '<container name="leftAdBlock"/>', '')
 WHERE `smap_content_xml` LIKE '%leftAdBlock%';
UPDATE `share_sitemap`
   SET `smap_layout_xml` = REPLACE(REPLACE(`smap_layout_xml`,
           '<container name="leftAdBlock"></container>', ''), '<container name="leftAdBlock"/>', '')
 WHERE `smap_layout_xml` LIKE '%leftAdBlock%';

-- 6. Шаблоны писем рассылок. Остаются регистрация, восстановление пароля
--    и два письма обратной связи.
DELETE FROM `mail_templates`
 WHERE `template_sysname` IN ('mail_news', 'mail_news_item', 'mail_crm', 'mail_crm_item');

-- 7. Демо-файлы, на которые после вырезания никто не ссылается: фото товаров,
--    которых нет ни в новостях, ни в галерее, и картинки категорий каталога.
DELETE u FROM `share_uploads` u
 WHERE u.`upl_path` LIKE 'uploads/public/demo/%'
   AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `apps_feed_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `apps_tops_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `user_users` x WHERE x.`u_avatar_img` = u.`upl_path`)
   AND NOT EXISTS (SELECT 1 FROM `apps_branding` x WHERE x.`brand_main_img` = u.`upl_path`)
   AND NOT EXISTS (SELECT 1 FROM `share_widgets` x WHERE x.`widget_icon_img` = u.`upl_path`);

-- 8. Переводы вырезанных модулей: подписи, которые встречались только в их коде,
--    и FIELD_… колонок их таблиц. Список собран tests/tools/cut-constants.php:
--    в оставшемся коде этих имён нет, и динамически (FIELD_<колонка>, TXT_<компонент>,
--    TXT_<право>) оставшийся код их не собирает. Переводы удаляются каскадом.
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (
    'BTN_APPROVE', 'BTN_BUY', 'BTN_COMPARE', 'BTN_COPY', 'BTN_CREATE', 'BTN_DOWN', 'BTN_EDIT_FORM',
    'BTN_EDIT_PROPERTIES', 'BTN_EDIT_VALUES', 'BTN_EXPORT_CSV', 'BTN_MOVE_BASKET', 'BTN_ORDER',
    'BTN_RESET_FILTER', 'BTN_SAVE_FILTER', 'BTN_SEARCH', 'BTN_SHOW_RESULTS', 'BTN_UP',
    'BTN_WISHLIST', 'COMMENT_DO', 'COMMENT_DO_NEWS', 'COMMENT_REALY_REMOVE', 'COMMENT_REMAIN',
    'COMMENT_SYMBOL1', 'COMMENT_SYMBOL2', 'COMMENT_SYMBOL3', 'ERROR_NO_FORM', 'ERR_BAD_EMAIL',
    'ERR_BAD_FORM_ID', 'ERR_BAD_USER', 'ERR_DUPLICATE_FILTER_DATA', 'ERR_DUPLICATE_FILTER_NAME',
    'ERR_MAIL_EXISTS', 'ERR_NO_CATALOGUE', 'ERR_NO_CURRENCY', 'ERR_NO_CURR_DATA', 'ERR_NO_EMAIL',
    'ERR_NO_FILTER_NAME', 'ERR_NO_SHOP', 'ERR_WRONG_FIELD_ID', 'FIELD_ADS_ITEM_HTML',
    'FIELD_ADS_ITEM_ID', 'FIELD_ADS_ITEM_IMG', 'FIELD_ADS_ITEM_IS_ACTIVE', 'FIELD_ADS_ITEM_MODE',
    'FIELD_ADS_ITEM_MODE_ENUM_HTML', 'FIELD_ADS_ITEM_MODE_ENUM_IMAGE', 'FIELD_ADS_ITEM_NAME',
    'FIELD_ADS_ITEM_SITE_MULTI', 'FIELD_ADS_ITEM_SMAP_MULTI', 'FIELD_ADS_ITEM_URL',
    'FIELD_ADS_TYPE_HEIGHT', 'FIELD_ADS_TYPE_ID', 'FIELD_ADS_TYPE_NAME', 'FIELD_ADS_TYPE_SYSNAME',
    'FIELD_ADS_TYPE_WIDTH', 'FIELD_BLOG_ID', 'FIELD_BLOG_NAME', 'FIELD_CART_GOODS_COUNT',
    'FIELD_COMMENT_APPROVED', 'FIELD_COMMENT_CREATED', 'FIELD_COMMENT_ID', 'FIELD_COMMENT_NAME',
    'FIELD_COMMENT_NICK', 'FIELD_COUNTRY_ID', 'FIELD_COUNTRY_NAME', 'FIELD_COUNTRY_TEL_CODE',
    'FIELD_COUNTRY_TEL_FORMAT', 'FIELD_CRM_DATE', 'FIELD_CRM_ID', 'FIELD_CRM_IS_ACTIVE',
    'FIELD_CRM_NAME', 'FIELD_CRM_TEXT_RTF', 'FIELD_CURRENCY_CODE', 'FIELD_CURRENCY_ID',
    'FIELD_CURRENCY_IS_ACTIVE', 'FIELD_CURRENCY_IS_DEFAULT', 'FIELD_CURRENCY_NAME',
    'FIELD_CURRENCY_RATE', 'FIELD_CURRENCY_SHORTNAME', 'FIELD_CURRENCY_SHORTNAME_ORDER',
    'FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_AFTER', 'FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_BEFORE',
    'FIELD_DELIVERY_TYPE_ID', 'FIELD_FEATURE_DESCRIPTION', 'FIELD_FEATURE_FILTER_TYPE',
    'FIELD_FEATURE_FILTER_TYPE_ENUM_CHECKBOXGROUP', 'FIELD_FEATURE_FILTER_TYPE_ENUM_DEFAULT',
    'FIELD_FEATURE_FILTER_TYPE_ENUM_RADIOGROUP', 'FIELD_FEATURE_FILTER_TYPE_ENUM_RANGE',
    'FIELD_FEATURE_FILTER_TYPE_ENUM_SELECT', 'FIELD_FEATURE_ID', 'FIELD_FEATURE_IS_ACTIVE',
    'FIELD_FEATURE_IS_FILTER', 'FIELD_FEATURE_IS_MAIN', 'FIELD_FEATURE_IS_ORDER_PARAM',
    'FIELD_FEATURE_NAME', 'FIELD_FEATURE_ORDER_NUM', 'FIELD_FEATURE_SITE_MULTI',
    'FIELD_FEATURE_SMAP_MULTI', 'FIELD_FEATURE_SYSNAME', 'FIELD_FEATURE_TITLE',
    'FIELD_FEATURE_TYPE', 'FIELD_FEATURE_TYPE_ENUM_BOOL', 'FIELD_FEATURE_TYPE_ENUM_INT',
    'FIELD_FEATURE_TYPE_ENUM_MULTIOPTION', 'FIELD_FEATURE_TYPE_ENUM_OPTION',
    'FIELD_FEATURE_TYPE_ENUM_STRING', 'FIELD_FEATURE_TYPE_ENUM_VARIANT', 'FIELD_FEATURE_UNIT',
    'FIELD_FK_NAME', 'FIELD_FORM_ANNOTATION_RTF', 'FIELD_FORM_CREATION_DATE', 'FIELD_FORM_DATE',
    'FIELD_FORM_EMAIL_ADRESSES', 'FIELD_FORM_ID', 'FIELD_FORM_IS_ACTIVE', 'FIELD_FORM_NAME',
    'FIELD_FORM_POST_ANNOTATION_RTF', 'FIELD_FPV_DATA', 'FIELD_FPV_ID', 'FIELD_GOODS_AMOUNT',
    'FIELD_GOODS_CODE', 'FIELD_GOODS_DESCRIPTION', 'FIELD_GOODS_DESCRIPTION_RTF',
    'FIELD_GOODS_FROM_ID', 'FIELD_GOODS_ID', 'FIELD_GOODS_IS_ACTIVE', 'FIELD_GOODS_NAME',
    'FIELD_GOODS_PRICE', 'FIELD_GOODS_PRICE_OLD', 'FIELD_GOODS_QUANTITY', 'FIELD_GOODS_REAL_PRICE',
    'FIELD_GOODS_SEGMENT', 'FIELD_GOODS_SEO_DESCRIPTION', 'FIELD_GOODS_SEO_KEYWORDS',
    'FIELD_GOODS_SEO_TITLE', 'FIELD_GOODS_SHORT_DESCRIPTION', 'FIELD_GOODS_TITLE',
    'FIELD_GOODS_TO_ID', 'FIELD_GOODS_TYPE', 'FIELD_GP_ID', 'FIELD_GROUP_DESCRIPTION',
    'FIELD_GROUP_IS_ACTIVE', 'FIELD_MES_ID', 'FIELD_ME_DATE', 'FIELD_ME_ID', 'FIELD_ME_NAME',
    'FIELD_OG_ID', 'FIELD_OPTION_ID', 'FIELD_OPTION_IMG', 'FIELD_OPTION_ORDER_NUM',
    'FIELD_OPTION_VALUE', 'FIELD_ORDER_ADDRESS', 'FIELD_ORDER_AMOUNT', 'FIELD_ORDER_CITY',
    'FIELD_ORDER_COMMENT', 'FIELD_ORDER_CREATED', 'FIELD_ORDER_DISCOUNT', 'FIELD_ORDER_EMAIL',
    'FIELD_ORDER_GOODS_COUNT', 'FIELD_ORDER_ID', 'FIELD_ORDER_PHONE', 'FIELD_ORDER_PROMOCODE',
    'FIELD_ORDER_TOTAL', 'FIELD_ORDER_UPDATED', 'FIELD_ORDER_USER_NAME', 'FIELD_PAYMENT_TYPE_ID',
    'FIELD_PK_ID', 'FIELD_POST_CREATED', 'FIELD_POST_ID', 'FIELD_POST_NAME', 'FIELD_POST_TEXT_RTF',
    'FIELD_PRODUCER_ID', 'FIELD_PRODUCER_IS_ACTIVE', 'FIELD_PRODUCER_NAME',
    'FIELD_PRODUCER_SEGMENT', 'FIELD_PRODUCER_SITE_MULTI', 'FIELD_PROMOTION_END_DATE',
    'FIELD_PROMOTION_ID', 'FIELD_PROMOTION_IS_ACTIVE', 'FIELD_PROMOTION_NAME',
    'FIELD_PROMOTION_START_DATE', 'FIELD_RELATION_ID', 'FIELD_RELATION_TYPE',
    'FIELD_RELATION_TYPE_ENUM_ACCESSORY', 'FIELD_RELATION_TYPE_ENUM_SIMILAR',
    'FIELD_SELL_STATUS_ID', 'FIELD_SELL_STATUS_NAME', 'FIELD_SF_DATA', 'FIELD_SF_ID',
    'FIELD_SF_NAME', 'FIELD_SMAP_FEATURES_MULTI', 'FIELD_STATUS_ID', 'FIELD_STATUS_IS_ACTIVE',
    'FIELD_STATUS_IS_CANCELLABLE', 'FIELD_STATUS_NAME', 'FIELD_STATUS_SYSNAME',
    'FIELD_SUBSCRIPTION_DESCRIPTION', 'FIELD_SUBSCRIPTION_ID', 'FIELD_SUBSCRIPTION_IS_ACTIVE',
    'FIELD_SUBSCRIPTION_IS_DEFAULT', 'FIELD_SUBSCRIPTION_IS_HIDDEN', 'FIELD_SUBSCRIPTION_NAME',
    'FIELD_SUBSCRIPTION_PERIOD', 'FIELD_SUBSCRIPTION_PERIOD_ENUM_DAILY',
    'FIELD_SUBSCRIPTION_PERIOD_ENUM_HOURLY', 'FIELD_SUBSCRIPTION_PERIOD_ENUM_MONTHLY',
    'FIELD_SUBSCRIPTION_PERIOD_ENUM_WEEKLY', 'FIELD_SUBSCRIPTION_SENT_DATE',
    'FIELD_SUBSCRIPTION_TYPE', 'FIELD_SUBSCRIPTION_TYPE_ENUM_CRM',
    'FIELD_SUBSCRIPTION_TYPE_ENUM_NEWS', 'FIELD_SU_ID', 'FIELD_TARGET_ID', 'FIELD_TYPE_ID',
    'FIELD_TYPE_IS_ACTIVE', 'FIELD_TYPE_IS_ONLINE', 'FIELD_TYPE_NAME', 'FIELD_TYPE_SYSNAME',
    'FILTER_PRICE', 'FILTER_PRODUCERS', 'FPV_ORDER_NUM', 'MSG_BAD_CHECK_FEATURE_NAME',
    'MSG_BAD_CHECK_FEATURE_TITLE', 'MSG_BAD_CHECK_GROUP_ID', 'MSG_BAD_CHECK_SITE_MULTI',
    'MSG_ERR_BAD_PLACEHOLDER', 'MSG_SUBSCRIBED', 'SHOW_AS_LIST', 'SHOW_AS_TILE',
    'TAB_FEATURE_OPTIONS', 'TAB_GOODS_FEATURES', 'TAB_GOODS_RELATIONS', 'TAB_ORDER_GOODS',
    'TAB_PROMOTION_GOODS', 'TAB_SITE_LOGO_FILES', 'TAB_SUBSCRIBED_EMAILS', 'TAB_SUBSCRIBED_USERS',
    'TXT_ACCESSORIES', 'TXT_ADD_TO_COMPARE', 'TXT_ADS_ITEMS_EDITOR', 'TXT_ADS_TYPES_EDITOR',
    'TXT_ALL_FEATURES', 'TXT_ALL_SEARCH_RESULTS', 'TXT_BLOG_ALL_POSTS', 'TXT_BLOG_COMMENTS',
    'TXT_BLOG_EDITOR', 'TXT_BLOG_EMPTY', 'TXT_BLOG_NEW_POST', 'TXT_BLOG_POST_EDITOR', 'TXT_CART',
    'TXT_CATEGORIES', 'TXT_COMMENT_NICK_IS_REQUIRED', 'TXT_COMPARE', 'TXT_COMPARE_CLEAR',
    'TXT_COMPARE_EMPTY', 'TXT_COMPARE_SELECTED', 'TXT_COMPARE_WORD_GOODS',
    'TXT_COMPARE_WORD_GOODS_MANY', 'TXT_DAYS', 'TXT_EMAIL_FROM_FORM', 'TXT_EMAIL_USER',
    'TXT_EMPTY_SAVED_FILTER', 'TXT_FEATURES', 'TXT_FILTER_LIB', 'TXT_FORM_SUCCESS_SEND',
    'TXT_LAST_SEEN_GOODS', 'TXT_MAIL_SUBSCRIPTION_EDITOR', 'TXT_MAIN_FEATURES',
    'TXT_MY_ORDERS_EMPTY', 'TXT_REMOVE_FROM_COMPARE', 'TXT_SAVED_FILTERS', 'TXT_SAVE_FILTER_FORM',
    'TXT_SAVE_FILTER_NAME', 'TXT_SIMILAR_GOODS', 'TXT_SORT', 'TXT_SUBSCRIBE', 'TXT_SUBSCRIBED',
    'TXT_TITLE_SAVE_FILTER_FORM', 'TXT_UNSUBSCRIBED', 'TXT_WISHLIST'
);
