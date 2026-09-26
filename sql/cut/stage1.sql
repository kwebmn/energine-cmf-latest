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
