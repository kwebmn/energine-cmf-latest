-- Демо-контент витрины new.energine.org.
-- Импортируется ПОСЛЕ starter.*.sql и modules.*.sql: опирается на уже созданные
-- структуру сайта, языки (ru = 1, ua = 2) и демо-новости стартового набора.
-- Файл рассчитан на повторный прогон: везде INSERT IGNORE либо ON DUPLICATE KEY UPDATE.

-- ---------------------------------------------------------------------------
-- Теги контента
-- ---------------------------------------------------------------------------
-- Теги живут в общем пуле share_tags вместе со служебными (menu, user, shop...),
-- отличаются только тем, что их назначают материалам, а не страницам.

INSERT IGNORE INTO `share_tags` (`tag_code`) VALUES
  ('energine'), ('linux'), ('compilers'), ('opensource'), ('releases'), ('webdev');

INSERT INTO `share_tags_translation` (`tag_id`, `lang_id`, `tag_name`)
  SELECT t.`tag_id`, l.`lang_id`,
         CASE t.`tag_code`
           WHEN 'energine'   THEN IF(l.`lang_abbr` = 'ua', 'Energine',    'Energine')
           WHEN 'linux'      THEN IF(l.`lang_abbr` = 'ua', 'Linux',       'Linux')
           WHEN 'compilers'  THEN IF(l.`lang_abbr` = 'ua', 'Компілятори', 'Компиляторы')
           WHEN 'opensource' THEN IF(l.`lang_abbr` = 'ua', 'Відкритий код', 'Открытый код')
           WHEN 'releases'   THEN IF(l.`lang_abbr` = 'ua', 'Релізи',      'Релизы')
           WHEN 'webdev'     THEN IF(l.`lang_abbr` = 'ua', 'Веб-розробка', 'Веб-разработка')
         END
    FROM `share_tags` t
    CROSS JOIN `share_languages` l
   WHERE t.`tag_code` IN ('energine', 'linux', 'compilers', 'opensource', 'releases', 'webdev')
      ON DUPLICATE KEY UPDATE `tag_name` = VALUES(`tag_name`);

-- Привязка тегов к демо-новостям стартового набора.
-- Теги пересекаются, чтобы блок «Похожие новости» подбирал материалы по смыслу.
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT n.`news_id`, t.`tag_id`
    FROM `apps_news` n
    JOIN `share_tags` t
   WHERE (n.`news_segment` = 'dobro-pozhalovaty'
            AND t.`tag_code` IN ('energine', 'releases', 'webdev'))
      OR (n.`news_segment` = 'new-gcc-4-8-0'
            AND t.`tag_code` IN ('compilers', 'opensource', 'releases'))
      OR (n.`news_segment` = 'richard-stollman-protiv-c'
            AND t.`tag_code` IN ('compilers', 'opensource'))
      OR (n.`news_segment` = 'linuxfmonlajn-radio-veshhajushheje-iskhodnyj-kod-jadra-linux'
            AND t.`tag_code` IN ('linux', 'opensource'));

-- ===========================================================================
-- Магазин: категории, производители, характеристики, товары, связи, акции
-- ===========================================================================

SET @catalog := (SELECT smap_id FROM `share_sitemap` WHERE `smap_segment` = 'catalog' LIMIT 1);
SET @site := (SELECT site_id FROM `share_sites` WHERE `site_is_default` = 1 LIMIT 1);
SET @cur := (SELECT currency_id FROM `shop_currencies` WHERE `currency_is_default` = 1 LIMIT 1);

-- Категории - страницы под /catalog/. Существующая страница «Товары» становится
-- первой категорией, чтобы не оставлять пустой раздел.
UPDATE `share_sitemap` SET `smap_segment` = 'phones'
  WHERE `smap_pid` = @catalog AND `smap_segment` = 'products';

INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'catalog_products.content.xml', @catalog, 'phones', COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @catalog), 0) + 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @catalog AND x.`smap_segment` = 'phones');
SET @cat_phones := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @catalog AND `smap_segment` = 'phones');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @cat_phones, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Смартфони', 'Смартфоны'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @cat_phones, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;

INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'catalog_products.content.xml', @catalog, 'laptops', COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @catalog), 0) + 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @catalog AND x.`smap_segment` = 'laptops');
SET @cat_laptops := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @catalog AND `smap_segment` = 'laptops');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @cat_laptops, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Ноутбуки', 'Ноутбуки'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @cat_laptops, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;

INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'catalog_products.content.xml', @catalog, 'audio', COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @catalog), 0) + 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @catalog AND x.`smap_segment` = 'audio');
SET @cat_audio := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @catalog AND `smap_segment` = 'audio');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @cat_audio, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Навушники', 'Наушники'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @cat_audio, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;

-- Папка и файлы демо-изображений в репозитории
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  SELECT r.`upl_id`, 'uploads/public/demo', 'demo', 'demo', 'Демо-каталог', 'folder', '', 1, 1, NOW()
    FROM `share_uploads` r WHERE r.`upl_path` = 'uploads/public';
SET @dir := (SELECT upl_id FROM `share_uploads` WHERE `upl_path` = 'uploads/public/demo');

INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/aurora-x5.jpg', 'aurora-x5.jpg', 'aurora-x5.jpg', 'Аврора X5', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/aurora-x7-pro.jpg', 'aurora-x7-pro.jpg', 'aurora-x7-pro.jpg', 'Аврора X7 Pro', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/kvark-neo.jpg', 'kvark-neo.jpg', 'kvark-neo.jpg', 'Кварк Нео', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/kvark-neo-plus.jpg', 'kvark-neo-plus.jpg', 'kvark-neo-plus.jpg', 'Кварк Нео Плюс', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/lumen-air.jpg', 'lumen-air.jpg', 'lumen-air.jpg', 'Люмен Эйр', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/nord-solid.jpg', 'nord-solid.jpg', 'nord-solid.jpg', 'Норд Солид', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/vektor-one.jpg', 'vektor-one.jpg', 'vektor-one.jpg', 'Вектор Уан', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/vektor-one-max.jpg', 'vektor-one-max.jpg', 'vektor-one-max.jpg', 'Вектор Уан Макс', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/aurora-book-13.jpg', 'aurora-book-13.jpg', 'aurora-book-13.jpg', 'Аврора Бук 13', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/aurora-book-15.jpg', 'aurora-book-15.jpg', 'aurora-book-15.jpg', 'Аврора Бук 15', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/kvark-lite-14.jpg', 'kvark-lite-14.jpg', 'kvark-lite-14.jpg', 'Кварк Лайт 14', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/lumen-studio-15.jpg', 'lumen-studio-15.jpg', 'lumen-studio-15.jpg', 'Люмен Студио 15', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/nord-work-14.jpg', 'nord-work-14.jpg', 'nord-work-14.jpg', 'Норд Ворк 14', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/vektor-pro-15.jpg', 'vektor-pro-15.jpg', 'vektor-pro-15.jpg', 'Вектор Про 15', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/lumen-buds.jpg', 'lumen-buds.jpg', 'lumen-buds.jpg', 'Люмен Бадс', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/lumen-buds-pro.jpg', 'lumen-buds-pro.jpg', 'lumen-buds-pro.jpg', 'Люмен Бадс Про', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/nord-studio-h1.jpg', 'nord-studio-h1.jpg', 'nord-studio-h1.jpg', 'Норд Студио H1', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/vektor-move.jpg', 'vektor-move.jpg', 'vektor-move.jpg', 'Вектор Мув', 'image', 'image/jpeg', 600, 450, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/cat-phones.jpg', 'cat-phones.jpg', 'cat-phones.jpg', 'Смартфоны', 'image', 'image/jpeg', 400, 300, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/cat-laptops.jpg', 'cat-laptops.jpg', 'cat-laptops.jpg', 'Ноутбуки', 'image', 'image/jpeg', 400, 300, 1, 1, NOW());
INSERT IGNORE INTO `share_uploads` (`upl_pid`, `upl_path`, `upl_filename`, `upl_name`, `upl_title`, `upl_internal_type`, `upl_mime_type`, `upl_width`, `upl_height`, `upl_is_ready`, `upl_is_active`, `upl_publication_date`)
  VALUES (@dir, 'uploads/public/demo/cat-audio.jpg', 'cat-audio.jpg', 'cat-audio.jpg', 'Наушники', 'image', 'image/jpeg', 400, 300, 1, 1, NOW());
-- upl_path объявлен уникальным, поэтому INSERT IGNORE выше достаточно.

-- Картинка категории: без неё плитки на /catalog/ выводят битые изображения
INSERT INTO `share_sitemap_uploads` (`smap_id`, `upl_id`)
  SELECT @cat_phones, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/cat-phones.jpg'
     AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x WHERE x.`smap_id` = @cat_phones AND x.`upl_id` = u.`upl_id`);
INSERT INTO `share_sitemap_uploads` (`smap_id`, `upl_id`)
  SELECT @cat_laptops, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/cat-laptops.jpg'
     AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x WHERE x.`smap_id` = @cat_laptops AND x.`upl_id` = u.`upl_id`);
INSERT INTO `share_sitemap_uploads` (`smap_id`, `upl_id`)
  SELECT @cat_audio, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/cat-audio.jpg'
     AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x WHERE x.`smap_id` = @cat_audio AND x.`upl_id` = u.`upl_id`);

-- Производители (вымышленные марки)
INSERT INTO `shop_producers` (`producer_segment`, `producer_is_active`)
  SELECT 'avrora', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_producers` x WHERE x.`producer_segment` = 'avrora');
INSERT INTO `shop_producers_translation` (`producer_id`, `lang_id`, `producer_name`)
  SELECT p.`producer_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Аврора', 'Аврора')
    FROM `shop_producers` p CROSS JOIN `share_languages` l WHERE p.`producer_segment` = 'avrora'
      ON DUPLICATE KEY UPDATE `producer_name` = VALUES(`producer_name`);
INSERT INTO `shop_producers` (`producer_segment`, `producer_is_active`)
  SELECT 'kvark', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_producers` x WHERE x.`producer_segment` = 'kvark');
INSERT INTO `shop_producers_translation` (`producer_id`, `lang_id`, `producer_name`)
  SELECT p.`producer_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Кварк', 'Кварк')
    FROM `shop_producers` p CROSS JOIN `share_languages` l WHERE p.`producer_segment` = 'kvark'
      ON DUPLICATE KEY UPDATE `producer_name` = VALUES(`producer_name`);
INSERT INTO `shop_producers` (`producer_segment`, `producer_is_active`)
  SELECT 'lumen', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_producers` x WHERE x.`producer_segment` = 'lumen');
INSERT INTO `shop_producers_translation` (`producer_id`, `lang_id`, `producer_name`)
  SELECT p.`producer_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Люмен', 'Люмен')
    FROM `shop_producers` p CROSS JOIN `share_languages` l WHERE p.`producer_segment` = 'lumen'
      ON DUPLICATE KEY UPDATE `producer_name` = VALUES(`producer_name`);
INSERT INTO `shop_producers` (`producer_segment`, `producer_is_active`)
  SELECT 'nord', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_producers` x WHERE x.`producer_segment` = 'nord');
INSERT INTO `shop_producers_translation` (`producer_id`, `lang_id`, `producer_name`)
  SELECT p.`producer_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Норд', 'Норд')
    FROM `shop_producers` p CROSS JOIN `share_languages` l WHERE p.`producer_segment` = 'nord'
      ON DUPLICATE KEY UPDATE `producer_name` = VALUES(`producer_name`);
INSERT INTO `shop_producers` (`producer_segment`, `producer_is_active`)
  SELECT 'vektor', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_producers` x WHERE x.`producer_segment` = 'vektor');
INSERT INTO `shop_producers_translation` (`producer_id`, `lang_id`, `producer_name`)
  SELECT p.`producer_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вектор', 'Вектор')
    FROM `shop_producers` p CROSS JOIN `share_languages` l WHERE p.`producer_segment` = 'vektor'
      ON DUPLICATE KEY UPDATE `producer_name` = VALUES(`producer_name`);
INSERT IGNORE INTO `shop_producers2sites` (`producer_id`, `site_id`) SELECT `producer_id`, @site FROM `shop_producers`;

-- Группы характеристик
INSERT IGNORE INTO `shop_feature_groups` (`group_id`, `group_is_active`, `group_order_num`) VALUES (1, 1, 1);
INSERT INTO `shop_feature_groups_translation` (`group_id`, `lang_id`, `group_name`)
  SELECT 1, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Основні', 'Основные') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `group_name` = VALUES(`group_name`);
INSERT IGNORE INTO `shop_feature_groups` (`group_id`, `group_is_active`, `group_order_num`) VALUES (2, 1, 2);
INSERT INTO `shop_feature_groups_translation` (`group_id`, `lang_id`, `group_name`)
  SELECT 2, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Додаткові', 'Дополнительные') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `group_name` = VALUES(`group_name`);

-- Характеристики. В фильтр попадает та, у которой есть привязка к сайту и к
-- категории, перевод, feature_is_active и feature_is_filter.
INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'OPTION', 1, 1, 'memory', 'RANGE', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'memory');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Пам’ять', 'Память'), 'ГБ'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '64', '64') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '128', '128') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '256', '256') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 4);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 4);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '512', '512') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'OPTION', 1, 1, 'ram', 'RANGE', 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'ram');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Оперативна пам’ять', 'Оперативная память'), 'ГБ'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '8', '8') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '16', '16') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '32', '32') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'MULTIOPTION', 1, 1, 'color', 'CHECKBOXGROUP', 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'color');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Колір', 'Цвет'), ''
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_audio, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Чорний', 'Чёрный') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Білий', 'Белый') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Синій', 'Синий') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 4);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 4);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Зелений', 'Зелёный') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 5);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 5);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сріблястий', 'Серебристый') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'OPTION', 1, 1, 'screen', 'CHECKBOXGROUP', 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'screen');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Екран', 'Экран'), '"'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '6.1', '6.1') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '6.5', '6.5') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '6.7', '6.7') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'OPTION', 1, 1, 'diagonal', 'CHECKBOXGROUP', 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'diagonal');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Діагональ', 'Диагональ'), '"'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '13', '13') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '14', '14') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '15.6', '15.6') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'OPTION', 1, 1, 'headtype', 'CHECKBOXGROUP', 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'headtype');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'headtype');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Тип', 'Тип'), ''
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_audio, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Повнорозмірні', 'Полноразмерные') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вкладиші', 'Вкладыши') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 3);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 3);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Накладні', 'Накладные') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 2, 'OPTION', 1, 1, 'warranty', 'RADIOGROUP', 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'warranty');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Гарантія', 'Гарантия'), 'мес'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 1);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 1);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '12', '12') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);
INSERT INTO `shop_feature_options` (`feature_id`, `option_order_num`)
  SELECT @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature_options` x WHERE x.`feature_id` = @f AND x.`option_order_num` = 2);
SET @opt := (SELECT o.`option_id` FROM `shop_feature_options` o WHERE o.`feature_id` = @f AND o.`option_order_num` = 2);
INSERT INTO `shop_feature_options_translation` (`option_id`, `lang_id`, `option_value`)
  SELECT @opt, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '24', '24') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `option_value` = VALUES(`option_value`);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 2, 'BOOL', 1, 0, 'nfc', 'DEFAULT', 8 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'nfc');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'NFC', 'NFC'), ''
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 2, 'BOOL', 1, 0, 'wireless', 'DEFAULT', 9 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'wireless');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'wireless');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Бездротові', 'Беспроводные'), ''
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_audio, @f);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 1, 'STRING', 1, 0, 'cpu', 'DEFAULT', 10 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'cpu');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Процесор', 'Процессор'), ''
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);

INSERT INTO `shop_features` (`group_id`, `feature_type`, `feature_is_active`, `feature_is_filter`, `feature_sysname`, `feature_filter_type`, `feature_order_num`)
  SELECT 2, 'INT', 1, 0, 'weight', 'DEFAULT', 11 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_features` x WHERE x.`feature_sysname` = 'weight');
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_features_translation` (`feature_id`, `lang_id`, `feature_name`, `feature_unit`)
  SELECT @f, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вага', 'Вес'), 'г'
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `feature_name` = VALUES(`feature_name`), `feature_unit` = VALUES(`feature_unit`);
INSERT IGNORE INTO `shop_features2sites` (`feature_id`, `site_id`) VALUES (@f, @site);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_phones, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_laptops, @f);
INSERT IGNORE INTO `shop_sitemap2features` (`smap_id`, `feature_id`) VALUES (@cat_audio, @f);

-- Товары. Сегмент не должен начинаться с цифры: поиск товара сначала пробует id.

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'aurora-x5', p.`producer_id`, 1, 'E888DC37', @cur, 18999, NULL, 1, NOW() - INTERVAL 60 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'avrora'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'aurora-x5');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'aurora-x5');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Аврора X5', 'Аврора X5'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Аврора X5. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Аврора X5. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/aurora-x5.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '128' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.1' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Aurora A5' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '178' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'aurora-x7-pro', p.`producer_id`, 1, '1940C85F', @cur, 27499, NULL, 1, NOW() - INTERVAL 57 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'avrora'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'aurora-x7-pro');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'aurora-x7-pro');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Аврора X7 Pro', 'Аврора X7 Pro'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Аврора X7 Pro. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Аврора X7 Pro. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/aurora-x7-pro.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '256' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Синий' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.7' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Aurora A7' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '195' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'kvark-neo', p.`producer_id`, 1, '4F4F2446', @cur, 12499, 13999, 1, NOW() - INTERVAL 54 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'kvark'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'kvark-neo');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'kvark-neo');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Кварк Нео', 'Кварк Нео'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Кварк Нео. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Кварк Нео. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/kvark-neo.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '64' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.1' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '12' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '0' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Kvark K3' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '168' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'kvark-neo-plus', p.`producer_id`, 1, '22FDD258', @cur, 15999, NULL, 1, NOW() - INTERVAL 51 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'kvark'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'kvark-neo-plus');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'kvark-neo-plus');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Кварк Нео Плюс', 'Кварк Нео Плюс'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Кварк Нео Плюс. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Кварк Нео Плюс. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/kvark-neo-plus.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '128' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Белый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.5' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '12' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Kvark K4' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '182' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'lumen-air', p.`producer_id`, 1, 'BDD8346C', @cur, 21999, 24999, 1, NOW() - INTERVAL 48 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'lumen'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'lumen-air');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'lumen-air');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Люмен Ейр', 'Люмен Эйр'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Люмен Ейр. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Люмен Эйр. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/lumen-air.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '256' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Белый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.5' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Lumen L2' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '171' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'nord-solid', p.`producer_id`, 2, '20F2A018', @cur, 9999, NULL, 1, NOW() - INTERVAL 45 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'nord'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'nord-solid');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'nord-solid');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Норд Солід', 'Норд Солид'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Норд Солід. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Норд Солид. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/nord-solid.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '64' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Зелёный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.1' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '12' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '0' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Nord N1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '205' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'vektor-one', p.`producer_id`, 1, 'B7C2D95A', @cur, 16499, NULL, 1, NOW() - INTERVAL 42 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'vektor'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'vektor-one');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'vektor-one');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вектор Уан', 'Вектор Уан'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Вектор Уан. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Вектор Уан. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/vektor-one.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '128' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Синий' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.5' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Vektor V2' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '186' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_phones, 'vektor-one-max', p.`producer_id`, 1, 'C28E9D38', @cur, 23999, NULL, 1, NOW() - INTERVAL 39 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'vektor'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'vektor-one-max');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'vektor-one-max');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вектор Уан Макс', 'Вектор Уан Макс'),
         IF(l.`lang_abbr` = 'ua', 'Смартфон з ємним акумулятором і швидкою зарядкою.', 'Смартфон с ёмким аккумулятором и быстрой зарядкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Вектор Уан Макс. Смартфон з ємним акумулятором і швидкою зарядкою.</p>', '<p>Вектор Уан Макс. Смартфон с ёмким аккумулятором и быстрой зарядкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/vektor-one-max.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'memory');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '512' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'screen');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '6.7' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'nfc');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Vektor V3' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '210' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'aurora-book-13', p.`producer_id`, 1, '8D4C3759', @cur, 34999, NULL, 1, NOW() - INTERVAL 36 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'avrora'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'aurora-book-13');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'aurora-book-13');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Аврора Бук 13', 'Аврора Бук 13'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Аврора Бук 13. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Аврора Бук 13. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/aurora-book-13.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '16' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '13' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Серебристый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Aurora A9' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1200' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'aurora-book-15', p.`producer_id`, 1, '20CE2B2D', @cur, 42999, 45999, 1, NOW() - INTERVAL 33 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'avrora'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'aurora-book-15');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'aurora-book-15');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Аврора Бук 15', 'Аврора Бук 15'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Аврора Бук 15. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Аврора Бук 15. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/aurora-book-15.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '32' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '15.6' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Серебристый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Aurora A11' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1650' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'kvark-lite-14', p.`producer_id`, 1, 'FBEF6040', @cur, 27999, NULL, 1, NOW() - INTERVAL 30 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'kvark'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'kvark-lite-14');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'kvark-lite-14');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Кварк Лайт 14', 'Кварк Лайт 14'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Кварк Лайт 14. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Кварк Лайт 14. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/kvark-lite-14.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '8' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '14' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '12' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Kvark K7' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1400' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'lumen-studio-15', p.`producer_id`, 3, '083DF922', @cur, 51999, NULL, 1, NOW() - INTERVAL 27 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'lumen'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'lumen-studio-15');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'lumen-studio-15');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Люмен Студіо 15', 'Люмен Студио 15'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Люмен Студіо 15. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Люмен Студио 15. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/lumen-studio-15.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '32' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '15.6' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Lumen L9' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1800' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'nord-work-14', p.`producer_id`, 1, '977F043E', @cur, 24999, NULL, 1, NOW() - INTERVAL 24 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'nord'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'nord-work-14');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'nord-work-14');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Норд Ворк 14', 'Норд Ворк 14'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Норд Ворк 14. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Норд Ворк 14. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/nord-work-14.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '8' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '14' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '12' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Nord N5' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1520' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_laptops, 'vektor-pro-15', p.`producer_id`, 1, '22B9A24D', @cur, 46999, NULL, 1, NOW() - INTERVAL 21 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'vektor'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'vektor-pro-15');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'vektor-pro-15');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вектор Про 15', 'Вектор Про 15'),
         IF(l.`lang_abbr` = 'ua', 'Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.', 'Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.'),
         IF(l.`lang_abbr` = 'ua', '<p>Вектор Про 15. Ноутбук для роботи й навчання, тонкий корпус, тихе охолодження.</p>', '<p>Вектор Про 15. Ноутбук для работы и учёбы, тонкий корпус, тихое охлаждение.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/vektor-pro-15.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'ram');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '16' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'diagonal');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '15.6' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Белый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'warranty');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = '24' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'cpu');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, 'Vektor V9' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1700' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_audio, 'lumen-buds', p.`producer_id`, 1, 'C581C6D0', @cur, 2499, NULL, 1, NOW() - INTERVAL 18 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'lumen'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'lumen-buds');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'lumen-buds');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Люмен Бадс', 'Люмен Бадс'),
         IF(l.`lang_abbr` = 'ua', 'Навушники з чистим звуком і зручною посадкою.', 'Наушники с чистым звуком и удобной посадкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Люмен Бадс. Навушники з чистим звуком і зручною посадкою.</p>', '<p>Люмен Бадс. Наушники с чистым звуком и удобной посадкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/lumen-buds.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'headtype');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Вкладыши' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'wireless');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Белый' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '45' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_audio, 'lumen-buds-pro', p.`producer_id`, 1, '8B431590', @cur, 3999, 4499, 1, NOW() - INTERVAL 15 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'lumen'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'lumen-buds-pro');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'lumen-buds-pro');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Люмен Бадс Про', 'Люмен Бадс Про'),
         IF(l.`lang_abbr` = 'ua', 'Навушники з чистим звуком і зручною посадкою.', 'Наушники с чистым звуком и удобной посадкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Люмен Бадс Про. Навушники з чистим звуком і зручною посадкою.</p>', '<p>Люмен Бадс Про. Наушники с чистым звуком и удобной посадкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/lumen-buds-pro.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'headtype');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Вкладыши' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'wireless');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '48' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_audio, 'nord-studio-h1', p.`producer_id`, 1, 'B5EE86B8', @cur, 5499, NULL, 1, NOW() - INTERVAL 12 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'nord'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'nord-studio-h1');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'nord-studio-h1');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Норд Студіо H1', 'Норд Студио H1'),
         IF(l.`lang_abbr` = 'ua', 'Навушники з чистим звуком і зручною посадкою.', 'Наушники с чистым звуком и удобной посадкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Норд Студіо H1. Навушники з чистим звуком і зручною посадкою.</p>', '<p>Норд Студио H1. Наушники с чистым звуком и удобной посадкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/nord-studio-h1.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'headtype');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Полноразмерные' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'wireless');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '0' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Чёрный' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '290' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

INSERT INTO `shop_goods` (`smap_id`, `goods_segment`, `producer_id`, `sell_status_id`, `goods_code`, `currency_id`, `goods_price`, `goods_price_old`, `goods_is_active`, `goods_date`)
  SELECT @cat_audio, 'vektor-move', p.`producer_id`, 2, '9C378212', @cur, 1899, NULL, 1, NOW() - INTERVAL 9 DAY FROM `shop_producers` p WHERE p.`producer_segment` = 'vektor'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods` x WHERE x.`goods_segment` = 'vektor-move');
SET @g := (SELECT goods_id FROM `shop_goods` WHERE `goods_segment` = 'vektor-move');
INSERT INTO `shop_goods_translation` (`goods_id`, `lang_id`, `goods_name`, `goods_short_description`, `goods_description_rtf`)
  SELECT @g, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Вектор Мув', 'Вектор Мув'),
         IF(l.`lang_abbr` = 'ua', 'Навушники з чистим звуком і зручною посадкою.', 'Наушники с чистым звуком и удобной посадкой.'),
         IF(l.`lang_abbr` = 'ua', '<p>Вектор Мув. Навушники з чистим звуком і зручною посадкою.</p>', '<p>Вектор Мув. Наушники с чистым звуком и удобной посадкой.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `goods_name` = VALUES(`goods_name`),
       `goods_short_description` = VALUES(`goods_short_description`), `goods_description_rtf` = VALUES(`goods_description_rtf`);
INSERT INTO `shop_goods_uploads` (`goods_id`, `upl_id`)
  SELECT @g, u.`upl_id` FROM `share_uploads` u WHERE u.`upl_path` = 'uploads/public/demo/vektor-move.jpg'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_uploads` x WHERE x.`goods_id` = @g AND x.`upl_id` = u.`upl_id`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'headtype');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Накладные' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'wireless');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '1' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'color');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, (SELECT o.`option_id` FROM `shop_feature_options` o
      JOIN `shop_feature_options_translation` ot ON ot.`option_id` = o.`option_id` AND ot.`lang_id` = 1
     WHERE o.`feature_id` = @f AND ot.`option_value` = 'Синий' LIMIT 1)
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);
SET @f := (SELECT feature_id FROM `shop_features` WHERE `feature_sysname` = 'weight');
INSERT INTO `shop_feature2good_values` (`goods_id`, `feature_id`, `fpv_order_num`)
  SELECT @g, @f, 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `shop_feature2good_values` x WHERE x.`goods_id` = @g AND x.`feature_id` = @f);
SET @v := (SELECT fpv_id FROM `shop_feature2good_values` WHERE `goods_id` = @g AND `feature_id` = @f);
INSERT INTO `shop_feature2good_values_translation` (`fpv_id`, `lang_id`, `fpv_data`)
  SELECT @v, l.`lang_id`, '180' FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `fpv_data` = VALUES(`fpv_data`);

-- Связанные товары: похожие и аксессуары
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x5' AND t.`goods_segment` = 'aurora-x7-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x5' AND t.`goods_segment` = 'vektor-one'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x7-pro' AND t.`goods_segment` = 'aurora-x5'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x7-pro' AND t.`goods_segment` = 'vektor-one-max'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo' AND t.`goods_segment` = 'kvark-neo-plus'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo' AND t.`goods_segment` = 'nord-solid'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo-plus' AND t.`goods_segment` = 'kvark-neo'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo-plus' AND t.`goods_segment` = 'vektor-one'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-air' AND t.`goods_segment` = 'aurora-x7-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-air' AND t.`goods_segment` = 'kvark-neo-plus'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-solid' AND t.`goods_segment` = 'kvark-neo'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-solid' AND t.`goods_segment` = 'vektor-one'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one' AND t.`goods_segment` = 'vektor-one-max'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one' AND t.`goods_segment` = 'aurora-x5'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one-max' AND t.`goods_segment` = 'vektor-one'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one-max' AND t.`goods_segment` = 'aurora-x7-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-book-13' AND t.`goods_segment` = 'aurora-book-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-book-13' AND t.`goods_segment` = 'kvark-lite-14'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-book-15' AND t.`goods_segment` = 'aurora-book-13'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-book-15' AND t.`goods_segment` = 'vektor-pro-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-lite-14' AND t.`goods_segment` = 'nord-work-14'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-lite-14' AND t.`goods_segment` = 'aurora-book-13'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-studio-15' AND t.`goods_segment` = 'vektor-pro-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-studio-15' AND t.`goods_segment` = 'aurora-book-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-work-14' AND t.`goods_segment` = 'kvark-lite-14'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-work-14' AND t.`goods_segment` = 'vektor-pro-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-pro-15' AND t.`goods_segment` = 'lumen-studio-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-pro-15' AND t.`goods_segment` = 'aurora-book-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-buds' AND t.`goods_segment` = 'lumen-buds-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-buds' AND t.`goods_segment` = 'vektor-move'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-buds-pro' AND t.`goods_segment` = 'lumen-buds'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-buds-pro' AND t.`goods_segment` = 'nord-studio-h1'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-studio-h1' AND t.`goods_segment` = 'lumen-buds-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'similar', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-move' AND t.`goods_segment` = 'lumen-buds'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'similar');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x5' AND t.`goods_segment` = 'lumen-buds'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x5' AND t.`goods_segment` = 'vektor-move'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x7-pro' AND t.`goods_segment` = 'lumen-buds-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 2 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'aurora-x7-pro' AND t.`goods_segment` = 'nord-studio-h1'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo' AND t.`goods_segment` = 'vektor-move'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'kvark-neo-plus' AND t.`goods_segment` = 'lumen-buds'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'lumen-air' AND t.`goods_segment` = 'lumen-buds-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'nord-solid' AND t.`goods_segment` = 'vektor-move'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one' AND t.`goods_segment` = 'lumen-buds'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');
INSERT INTO `shop_goods_relations` (`goods_from_id`, `goods_to_id`, `relation_type`, `relation_order_num`)
  SELECT f.`goods_id`, t.`goods_id`, 'accessory', 1 FROM `shop_goods` f, `shop_goods` t WHERE f.`goods_segment` = 'vektor-one-max' AND t.`goods_segment` = 'nord-studio-h1'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods_relations` x WHERE x.`goods_from_id` = f.`goods_id` AND x.`goods_to_id` = t.`goods_id` AND x.`relation_type` = 'accessory');

-- Акции: одна идёт сейчас, вторая уже завершилась
SET @p := (SELECT p.`promotion_id` FROM `shop_promotions` p
             JOIN `shop_promotions_translation` pt ON pt.`promotion_id` = p.`promotion_id` AND pt.`lang_id` = 1
            WHERE pt.`promotion_name` = 'Осенняя распродажа' LIMIT 1);
INSERT INTO `shop_promotions` (`site_id`, `promotion_is_active`, `promotion_start_date`, `promotion_end_date`)
  SELECT @site, 1, NOW() - INTERVAL 10 DAY, NOW() + INTERVAL 20 DAY FROM DUAL WHERE @p IS NULL;
SET @p := COALESCE(@p, LAST_INSERT_ID());
INSERT INTO `shop_promotions_translation` (`promotion_id`, `lang_id`, `promotion_name`)
  SELECT @p, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Осінній розпродаж', 'Осенняя распродажа') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `promotion_name` = VALUES(`promotion_name`);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'kvark-neo'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'lumen-air'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'aurora-book-15'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'lumen-buds-pro'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);

SET @p := (SELECT p.`promotion_id` FROM `shop_promotions` p
             JOIN `shop_promotions_translation` pt ON pt.`promotion_id` = p.`promotion_id` AND pt.`lang_id` = 1
            WHERE pt.`promotion_name` = 'Весенние скидки' LIMIT 1);
INSERT INTO `shop_promotions` (`site_id`, `promotion_is_active`, `promotion_start_date`, `promotion_end_date`)
  SELECT @site, 0, NOW() - INTERVAL 120 DAY, NOW() - INTERVAL 90 DAY FROM DUAL WHERE @p IS NULL;
SET @p := COALESCE(@p, LAST_INSERT_ID());
INSERT INTO `shop_promotions_translation` (`promotion_id`, `lang_id`, `promotion_name`)
  SELECT @p, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Весняні знижки', 'Весенние скидки') FROM `share_languages` l
    ON DUPLICATE KEY UPDATE `promotion_name` = VALUES(`promotion_name`);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'nord-solid'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);
INSERT INTO `shop_goods2promotions` (`goods_id`, `promotion_id`)
  SELECT g.`goods_id`, @p FROM `shop_goods` g WHERE g.`goods_segment` = 'vektor-move'
     AND NOT EXISTS (SELECT 1 FROM `shop_goods2promotions` x WHERE x.`goods_id` = g.`goods_id` AND x.`promotion_id` = @p);


-- ---------------------------------------------------------------------------
-- Валюты: кроме гривны добавляем доллар и евро, чтобы переключатель имел смысл.
-- currency_rate - сколько базовой валюты в одной единице этой валюты.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `shop_currencies`
  (`currency_code`, `currency_shortname`, `currency_shortname_order`, `currency_rate`, `currency_is_default`, `currency_is_active`)
  VALUES ('USD', '$', 'before', 41.0000, 0, 1),
         ('EUR', '€', 'before', 44.5000, 0, 1);

INSERT INTO `shop_currencies_translation` (`currency_id`, `lang_id`, `currency_name`)
  SELECT c.`currency_id`, l.`lang_id`,
         CASE c.`currency_code`
           WHEN 'USD' THEN IF(l.`lang_abbr` = 'ua', 'Долар США', 'Доллар США')
           WHEN 'EUR' THEN IF(l.`lang_abbr` = 'ua', 'Євро',      'Евро')
         END
    FROM `shop_currencies` c CROSS JOIN `share_languages` l
   WHERE c.`currency_code` IN ('USD', 'EUR')
      ON DUPLICATE KEY UPDATE `currency_name` = VALUES(`currency_name`);

-- Константы, которых нет в стартовом наборе переводов
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_ACCESSORIES'), ('TXT_ERROR_GO_HOME'), ('TXT_RSS_NEWS_TITLE');
INSERT INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`,
         CASE t.`ltag_name`
           WHEN 'TXT_ACCESSORIES'    THEN IF(l.`lang_abbr` = 'ua', 'Аксесуари',           'Аксессуары')
           WHEN 'TXT_ERROR_GO_HOME'  THEN IF(l.`lang_abbr` = 'ua', 'На головну сторінку', 'На главную страницу')
           WHEN 'TXT_RSS_NEWS_TITLE' THEN IF(l.`lang_abbr` = 'ua', 'Новини Energine',     'Новости Energine')
         END
    FROM `share_lang_tags` t CROSS JOIN `share_languages` l
   WHERE t.`ltag_name` IN ('TXT_ACCESSORIES', 'TXT_ERROR_GO_HOME', 'TXT_RSS_NEWS_TITLE')
      ON DUPLICATE KEY UPDATE `ltag_value_rtf` = VALUES(`ltag_value_rtf`);

-- ---------------------------------------------------------------------------
-- Демо-пользователи: два автора блогов и покупатель.
-- Пароль у всех demo (тот же, что у демо-администратора) - стенд публичный.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `user_users` (`u_name`, `u_password`, `u_is_active`, `u_fullname`, `u_city`, `u_phone`)
  VALUES ('anna@example.com',  '$2y$12$sVart6BzfqUBeTH8Z4wyvOHfZCsyWmoFNhSh9OAZSL9diMo0LogTO', 1, 'Анна Ковальчук', 'Киев',  '+380671234567'),
         ('petro@example.com', '$2y$12$sVart6BzfqUBeTH8Z4wyvOHfZCsyWmoFNhSh9OAZSL9diMo0LogTO', 1, 'Пётр Мельник',   'Львов', '+380509876543'),
         ('olena@example.com', '$2y$12$sVart6BzfqUBeTH8Z4wyvOHfZCsyWmoFNhSh9OAZSL9diMo0LogTO', 1, 'Елена Шевченко', 'Одесса','+380631112233');

-- группа «Пользователь» (group_user_default)
INSERT IGNORE INTO `user_user_groups` (`u_id`, `group_id`)
  SELECT u.`u_id`, g.`group_id`
    FROM `user_users` u CROSS JOIN `user_groups` g
   WHERE u.`u_name` IN ('anna@example.com', 'petro@example.com', 'olena@example.com')
     AND g.`group_user_default` = 1;

-- ---------------------------------------------------------------------------
-- Заказы. Публичного оформления заказа в движке нет, заказы заводит менеджер,
-- поэтому демо-заказы создаются здесь: три у покупателя и два гостевых.
-- ---------------------------------------------------------------------------
SET @buyer := (SELECT u_id FROM `user_users` WHERE `u_name` = 'olena@example.com');
SET @site := (SELECT site_id FROM `share_sites` WHERE `site_is_default` = 1 LIMIT 1);
SET @cur := (SELECT currency_id FROM `shop_currencies` WHERE `currency_is_default` = 1 LIMIT 1);

DROP TEMPORARY TABLE IF EXISTS `tmp_orders`;
CREATE TEMPORARY TABLE `tmp_orders` (
  `code` varchar(20) NOT NULL PRIMARY KEY,   -- ключ, по которому цепляем строки заказа
  `u_id` int(10) unsigned NULL,
  `status` int(10) unsigned NOT NULL,
  `delivery` int(10) unsigned NOT NULL,
  `payment` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `city` varchar(255) NOT NULL,
  `address` varchar(255) NOT NULL,
  `days_ago` int NOT NULL
);
INSERT INTO `tmp_orders` VALUES
  ('D-1001', @buyer, 3, 2, 1, 'Елена Шевченко', 'olena@example.com', '+380631112233', 'Одесса', 'ул. Дерибасовская, 10', 21),
  ('D-1002', @buyer, 2, 3, 3, 'Елена Шевченко', 'olena@example.com', '+380631112233', 'Одесса', 'ул. Дерибасовская, 10', 7),
  ('D-1003', @buyer, 1, 1, 2, 'Елена Шевченко', 'olena@example.com', '+380631112233', 'Одесса', 'ул. Дерибасовская, 10', 1),
  ('D-1004', NULL,   3, 2, 1, 'Игорь Бондаренко', 'igor@example.com', '+380661234567', 'Харьков', 'пр. Науки, 5', 14),
  ('D-1005', NULL,   4, 1, 1, 'Мария Ткаченко',   'maria@example.com','+380931234567', 'Днепр',   'ул. Короленко, 3', 3);

-- строки заказов: код заказа -> сегмент товара -> количество
DROP TEMPORARY TABLE IF EXISTS `tmp_order_goods`;
CREATE TEMPORARY TABLE `tmp_order_goods` (
  `code` varchar(20) NOT NULL,
  `segment` varchar(255) NOT NULL,
  `qty` int(10) unsigned NOT NULL
);
INSERT INTO `tmp_order_goods` VALUES
  ('D-1001', 'aurora-x5', 1), ('D-1001', 'lumen-buds', 2),
  ('D-1002', 'kvark-lite-14', 1),
  ('D-1003', 'vektor-move', 1), ('D-1003', 'nord-studio-h1', 1),
  ('D-1004', 'aurora-book-15', 1),
  ('D-1005', 'kvark-neo', 1);

INSERT INTO `shop_orders`
  (`site_id`, `u_id`, `status_id`, `delivery_type_id`, `payment_type_id`, `currency_id`,
   `order_user_name`, `order_email`, `order_phone`, `order_city`, `order_address`,
   `order_created`, `order_updated`, `order_amount`, `order_total`, `order_goods_count`, `order_comment`)
  SELECT @site, o.`u_id`, o.`status`, o.`delivery`, o.`payment`, @cur,
         o.`name`, o.`email`, o.`phone`, o.`city`, o.`address`,
         NOW() - INTERVAL o.`days_ago` DAY, NOW() - INTERVAL o.`days_ago` DAY,
         t.`amount`, t.`amount`, t.`cnt`, CONCAT('Демо-заказ ', o.`code`)
    FROM `tmp_orders` o
    JOIN (SELECT og.`code`, SUM(g.`goods_price` * og.`qty`) AS `amount`, SUM(og.`qty`) AS `cnt`
            FROM `tmp_order_goods` og JOIN `shop_goods` g ON g.`goods_segment` = og.`segment`
           GROUP BY og.`code`) t ON t.`code` = o.`code`
   WHERE NOT EXISTS (SELECT 1 FROM `shop_orders` x WHERE x.`order_comment` = CONCAT('Демо-заказ ', o.`code`));

INSERT INTO `shop_orders_goods`
  (`order_id`, `goods_id`, `goods_title`, `goods_real_price`, `goods_price`, `goods_quantity`, `goods_amount`)
  SELECT so.`order_id`, g.`goods_id`, gt.`goods_name`, g.`goods_price`, g.`goods_price`,
         og.`qty`, g.`goods_price` * og.`qty`
    FROM `tmp_order_goods` og
    JOIN `shop_goods` g ON g.`goods_segment` = og.`segment`
    JOIN `shop_goods_translation` gt ON gt.`goods_id` = g.`goods_id` AND gt.`lang_id` = 1
    JOIN `shop_orders` so ON so.`order_comment` = CONCAT('Демо-заказ ', og.`code`)
   WHERE NOT EXISTS (SELECT 1 FROM `shop_orders_goods` x
                      WHERE x.`order_id` = so.`order_id` AND x.`goods_id` = g.`goods_id`);

DROP TEMPORARY TABLE `tmp_order_goods`;
DROP TEMPORARY TABLE `tmp_orders`;

-- ---------------------------------------------------------------------------
-- Блоги. Записи блога не имеют таблицы переводов: текст один на оба языка -
-- это ограничение схемы движка, а не пробел в наполнении.
-- Одна запись датирована будущим: так видно отложенную публикацию.
-- ---------------------------------------------------------------------------
INSERT INTO `blog_title` (`blog_name`, `u_id`)
  SELECT 'Записки разработчика', u.`u_id` FROM `user_users` u
   WHERE u.`u_name` = 'anna@example.com'
     AND NOT EXISTS (SELECT 1 FROM `blog_title` x WHERE x.`blog_name` = 'Записки разработчика');
INSERT INTO `blog_title` (`blog_name`, `u_id`)
  SELECT 'Заметки о вёрстке', u.`u_id` FROM `user_users` u
   WHERE u.`u_name` = 'petro@example.com'
     AND NOT EXISTS (SELECT 1 FROM `blog_title` x WHERE x.`blog_name` = 'Заметки о вёрстке');
INSERT INTO `blog_title` (`blog_name`, `u_id`)
  SELECT 'Дневник покупателя', u.`u_id` FROM `user_users` u
   WHERE u.`u_name` = 'olena@example.com'
     AND NOT EXISTS (SELECT 1 FROM `blog_title` x WHERE x.`blog_name` = 'Дневник покупателя');

DROP TEMPORARY TABLE IF EXISTS `tmp_posts`;
CREATE TEMPORARY TABLE `tmp_posts` (
  `blog` varchar(255) NOT NULL,
  `days_ago` int NOT NULL,          -- отрицательное значение = публикация в будущем
  `name` varchar(255) NOT NULL,
  `text` mediumtext NOT NULL
);
INSERT INTO `tmp_posts` VALUES
  ('Записки разработчика', 41, 'Почему мы выбрали XML и XSLT',
   '<p>Шаблонизация через XSLT кажется архаичной, пока не появляется вторая языковая версия и третий дизайн. Разделение данных и представления перестаёт быть теорией: компонент отдаёт данные, шаблон решает, как их показать.</p>'),
  ('Записки разработчика', 33, 'Компоненты и их состояния',
   '<p>Состояние компонента — это одновременно и метод, и адрес. Забыли объявить состояние в конфиге — метод есть, а адреса нет, и функция просто не существует для посетителя.</p>'),
  ('Записки разработчика', 24, 'Как мы храним настройки сайта',
   '<p>Свойства сайта лежат в базе и переопределяются для каждого сайта отдельно. Значение без привязки к сайту работает как значение по умолчанию.</p>'),
  ('Записки разработчика', 12, 'Кэш и режим отладки',
   '<p>В режиме отладки JavaScript отдаётся по файлам, а не одним собранным пакетом. Это удобно при разработке и заметно медленнее в бою.</p>'),
  ('Записки разработчика', 4,  'Обновление ядра без сюрпризов',
   '<p>Ядро живёт отдельной веткой, правки проекта — своей. Тогда обновление превращается в слияние, а не в археологию.</p>'),
  ('Заметки о вёрстке', 37, 'Сетка каталога на трёх колонках',
   '<p>Плитка товаров держится на процентных ширинах и отрицательном отступе контейнера. Никакого фреймворка для этого не нужно.</p>'),
  ('Заметки о вёрстке', 28, 'Формы, которые не бесят',
   '<p>Обязательные поля отмечаем до отправки, ошибки показываем рядом с полем, а не общим списком сверху.</p>'),
  ('Заметки о вёрстке', 19, 'Изображения и ресайзер',
   '<p>Картинки отдаём через ресайзер: один исходник и любые размеры в разметке. Это экономит и трафик, и нервы редактора.</p>'),
  ('Заметки о вёрстке', 9,  'Тёмная тема: стоит ли',
   '<p>Тёмная тема — это не инверсия цветов, а отдельный набор контрастов. Если нет времени сделать честно, лучше не делать вовсе.</p>'),
  ('Заметки о вёрстке', 2,  'Шрифты и кириллица',
   '<p>Проверяйте начертания на «щ», «ж» и «ф»: именно там обычно ломается ритм строки.</p>'),
  ('Дневник покупателя', 30, 'Как я выбирала ноутбук',
   '<p>Сравнение по характеристикам помогло больше, чем обзоры: три модели рядом в таблице — и решение принимается за минуту.</p>'),
  ('Дневник покупателя', 16, 'Наушники для дороги',
   '<p>Вкладыши против полноразмерных: в метро выигрывают первые, дома — вторые. Пришлось оставить и те, и другие.</p>'),
  ('Дневник покупателя', 6,  'Заказ приехал раньше срока',
   '<p>Статус заказа менялся в личном кабинете, так что звонить в поддержку не пришлось ни разу.</p>'),
  ('Дневник покупателя', -3, 'Что я жду от новой прошивки',
   '<p>Эта запись опубликуется позже: в блоге видно только тем, кто может редактировать, пока не наступит дата.</p>');

INSERT INTO `blog_post` (`blog_id`, `post_created`, `post_name`, `post_text_rtf`)
  SELECT b.`blog_id`, NOW() - INTERVAL p.`days_ago` DAY, p.`name`, p.`text`
    FROM `tmp_posts` p JOIN `blog_title` b ON b.`blog_name` = p.`blog`
   WHERE NOT EXISTS (SELECT 1 FROM `blog_post` x WHERE x.`post_name` = p.`name`);
DROP TEMPORARY TABLE `tmp_posts`;

-- Комментарии к записям блога: только от зарегистрированных (так настроена страница)
DROP TEMPORARY TABLE IF EXISTS `tmp_blog_comments`;
CREATE TEMPORARY TABLE `tmp_blog_comments` (
  `post` varchar(255) NOT NULL,
  `author` varchar(50) NOT NULL,
  `days_ago` int NOT NULL,
  `text` varchar(250) NOT NULL,
  `reply_to` varchar(250) NULL      -- текст родительского комментария, если это ответ
);
INSERT INTO `tmp_blog_comments` VALUES
  ('Почему мы выбрали XML и XSLT', 'petro@example.com', 40, 'А как быть с производительностью на больших выборках?', NULL),
  ('Почему мы выбрали XML и XSLT', 'anna@example.com',  39, 'Кэшируем результат трансформации, на списках разница незаметна.', 'А как быть с производительностью на больших выборках?'),
  ('Компоненты и их состояния',    'olena@example.com', 32, 'Теперь понятно, почему часть ссылок вела в никуда.', NULL),
  ('Сетка каталога на трёх колонках', 'anna@example.com', 36, 'Отрицательный отступ — старый приём, но работает.', NULL),
  ('Формы, которые не бесят',      'olena@example.com', 27, 'Подписи рядом с полем действительно удобнее.', NULL),
  ('Как я выбирала ноутбук',       'anna@example.com',  29, 'Сравнение до сих пор недооценено покупателями.', NULL),
  ('Наушники для дороги',          'petro@example.com', 15, 'Полноразмерные в метро — это боль, согласен.', NULL),
  ('Заказ приехал раньше срока',   'petro@example.com', 5,  'Хороший показатель для склада.', NULL);

INSERT INTO `blog_post_comment` (`target_id`, `u_id`, `comment_created`, `comment_name`, `comment_approved`)
  SELECT p.`post_id`, u.`u_id`, NOW() - INTERVAL c.`days_ago` DAY, c.`text`, 1
    FROM `tmp_blog_comments` c
    JOIN `blog_post` p ON p.`post_name` = c.`post`
    JOIN `user_users` u ON u.`u_name` = c.`author`
   WHERE c.`reply_to` IS NULL
     AND NOT EXISTS (SELECT 1 FROM `blog_post_comment` x WHERE x.`comment_name` = c.`text`);

-- ответы: родителя ищем по тексту
INSERT INTO `blog_post_comment` (`comment_parent_id`, `target_id`, `u_id`, `comment_created`, `comment_name`, `comment_approved`)
  SELECT parent.`comment_id`, p.`post_id`, u.`u_id`, NOW() - INTERVAL c.`days_ago` DAY, c.`text`, 1
    FROM `tmp_blog_comments` c
    JOIN `blog_post` p ON p.`post_name` = c.`post`
    JOIN `user_users` u ON u.`u_name` = c.`author`
    JOIN `blog_post_comment` parent ON parent.`comment_name` = c.`reply_to`
   WHERE c.`reply_to` IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM `blog_post_comment` x WHERE x.`comment_name` = c.`text`);
DROP TEMPORARY TABLE `tmp_blog_comments`;

-- ---------------------------------------------------------------------------
-- Комментарии к новостям. Здесь анонимные разрешены, поэтому часть без автора.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_news_comments`;
CREATE TEMPORARY TABLE `tmp_news_comments` (
  -- apps_news.news_segment - единственная колонка схемы с сортировкой unicode_ci;
  -- объявляем так же, иначе соединение упирается в несовместимые сортировки
  `segment` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `author` varchar(50) NULL,            -- NULL = анонимный, тогда берётся ник
  `nick` varchar(255) NULL,
  `days_ago` int NOT NULL,
  `text` varchar(250) NOT NULL,
  `reply_to` varchar(250) NULL,
  `approved` tinyint(1) NOT NULL DEFAULT 1
);
INSERT INTO `tmp_news_comments` VALUES
  ('new-gcc-4-8-0', 'anna@example.com', NULL, 26, 'Наконец-то поддержка новых стандартов из коробки.', NULL, 1),
  ('new-gcc-4-8-0', NULL, 'Гость', 25, 'А сборка стала заметно дольше?', 'Наконец-то поддержка новых стандартов из коробки.', 1),
  ('new-gcc-4-8-0', 'petro@example.com', NULL, 24, 'На больших проектах — да, минут на десять.', 'А сборка стала заметно дольше?', 1),
  ('dobro-pozhalovaty', 'olena@example.com', NULL, 20, 'Обновление поставилось без единой правки конфигов.', NULL, 1),
  ('dobro-pozhalovaty', NULL, 'Читатель', 18, 'Где посмотреть список изменений?', NULL, 1),
  ('richard-stollman-protiv-c', NULL, 'Аноним', 15, 'Спор старый, а аргументы всё те же.', NULL, 1),
  ('richard-stollman-protiv-c', 'anna@example.com', NULL, 14, 'Зато формулировки стали мягче.', 'Спор старый, а аргументы всё те же.', 1),
  ('linuxfmonlajn-radio-veshhajushheje-iskhodnyj-kod-jadra-linux', NULL, 'Слушатель', 10, 'Слушал полчаса, засыпает лучше белого шума.', NULL, 1),
  ('linuxfmonlajn-radio-veshhajushheje-iskhodnyj-kod-jadra-linux', NULL, 'Спам-бот', 9, 'Этот комментарий не одобрен и виден только в админке.', NULL, 0);

INSERT INTO `apps_news_comment` (`target_id`, `u_id`, `comment_nick`, `comment_created`, `comment_name`, `comment_approved`)
  SELECT n.`news_id`, u.`u_id`, c.`nick`, NOW() - INTERVAL c.`days_ago` DAY, c.`text`, c.`approved`
    FROM `tmp_news_comments` c
    JOIN `apps_news` n ON n.`news_segment` = c.`segment`
    LEFT JOIN `user_users` u ON u.`u_name` = c.`author`
   WHERE c.`reply_to` IS NULL
     AND NOT EXISTS (SELECT 1 FROM `apps_news_comment` x WHERE x.`comment_name` = c.`text`);

INSERT INTO `apps_news_comment` (`comment_parent_id`, `target_id`, `u_id`, `comment_nick`, `comment_created`, `comment_name`, `comment_approved`)
  SELECT parent.`comment_id`, n.`news_id`, u.`u_id`, c.`nick`, NOW() - INTERVAL c.`days_ago` DAY, c.`text`, c.`approved`
    FROM `tmp_news_comments` c
    JOIN `apps_news` n ON n.`news_segment` = c.`segment`
    LEFT JOIN `user_users` u ON u.`u_name` = c.`author`
    JOIN `apps_news_comment` parent ON parent.`comment_name` = c.`reply_to`
   WHERE c.`reply_to` IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM `apps_news_comment` x WHERE x.`comment_name` = c.`text`);

-- второй проход: ответ на ответ не видит родителя, вставленного тем же запросом
INSERT INTO `apps_news_comment` (`comment_parent_id`, `target_id`, `u_id`, `comment_nick`, `comment_created`, `comment_name`, `comment_approved`)
  SELECT parent.`comment_id`, n.`news_id`, u.`u_id`, c.`nick`, NOW() - INTERVAL c.`days_ago` DAY, c.`text`, c.`approved`
    FROM `tmp_news_comments` c
    JOIN `apps_news` n ON n.`news_segment` = c.`segment`
    LEFT JOIN `user_users` u ON u.`u_name` = c.`author`
    JOIN `apps_news_comment` parent ON parent.`comment_name` = c.`reply_to`
   WHERE c.`reply_to` IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM `apps_news_comment` x WHERE x.`comment_name` = c.`text`);
DROP TEMPORARY TABLE `tmp_news_comments`;

-- ---------------------------------------------------------------------------
-- Второй опрос (показывается самый свежий активный) и правдоподобные счётчики
-- ---------------------------------------------------------------------------
INSERT INTO `apps_vote` (`vote_date`, `vote_is_active`)
  SELECT NOW() - INTERVAL 5 DAY, 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_vote_translation` x WHERE x.`vote_name` = 'Чем вы пользуетесь для вёрстки?');
SET @vote := (SELECT v.`vote_id` FROM `apps_vote` v
                LEFT JOIN `apps_vote_translation` vt ON vt.`vote_id` = v.`vote_id` AND vt.`lang_id` = 1
               WHERE vt.`vote_name` = 'Чем вы пользуетесь для вёрстки?'
               ORDER BY v.`vote_id` DESC LIMIT 1);
SET @vote := COALESCE(@vote, LAST_INSERT_ID());
INSERT INTO `apps_vote_translation` (`vote_id`, `lang_id`, `vote_name`)
  SELECT @vote, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Чим ви користуєтесь для верстки?', 'Чем вы пользуетесь для вёрстки?')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `vote_name` = VALUES(`vote_name`);

DROP TEMPORARY TABLE IF EXISTS `tmp_vote_answers`;
CREATE TEMPORARY TABLE `tmp_vote_answers` (
  `num` int NOT NULL, `cnt` int NOT NULL, `ru` varchar(250) NOT NULL, `ua` varchar(250) NOT NULL
);
INSERT INTO `tmp_vote_answers` VALUES
  (1, 34, 'Чистый CSS',        'Чистий CSS'),
  (2, 61, 'Препроцессор',      'Препроцесор'),
  (3, 18, 'CSS-фреймворк',     'CSS-фреймворк'),
  (4,  7, 'Конструктор',       'Конструктор');
INSERT INTO `apps_vote_question` (`vote_id`, `vote_question_counter`, `vote_question_order_num`)
  SELECT @vote, a.`cnt`, a.`num` FROM `tmp_vote_answers` a
   WHERE NOT EXISTS (SELECT 1 FROM `apps_vote_question` x
                      WHERE x.`vote_id` = @vote AND x.`vote_question_order_num` = a.`num`);
INSERT INTO `apps_vote_question_translation` (`vote_question_id`, `lang_id`, `vote_question_title`)
  SELECT q.`vote_question_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', a.`ua`, a.`ru`)
    FROM `apps_vote_question` q
    JOIN `tmp_vote_answers` a ON a.`num` = q.`vote_question_order_num`
    CROSS JOIN `share_languages` l
   WHERE q.`vote_id` = @vote
      ON DUPLICATE KEY UPDATE `vote_question_title` = VALUES(`vote_question_title`);
DROP TEMPORARY TABLE `tmp_vote_answers`;

-- счётчики старого опроса, чтобы результаты выглядели правдоподобно
UPDATE `apps_vote_question` q
   JOIN `apps_vote` v ON v.`vote_id` = q.`vote_id`
    SET q.`vote_question_counter` = 12 + q.`vote_question_order_num` * 9
  WHERE v.`vote_id` <> @vote AND q.`vote_question_counter` = 0;

-- ---------------------------------------------------------------------------
-- Обратная связь: получатели и сообщения
-- ---------------------------------------------------------------------------
INSERT INTO `apps_feedback_recipient` (`rcp_recipients`, `rcp_order_num`)
  SELECT 'sales@example.com', 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_feedback_recipient` x WHERE x.`rcp_recipients` = 'sales@example.com');
INSERT INTO `apps_feedback_recipient` (`rcp_recipients`, `rcp_order_num`)
  SELECT 'support@example.com', 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_feedback_recipient` x WHERE x.`rcp_recipients` = 'support@example.com');

INSERT INTO `apps_feedback_recipient_translation` (`rcp_id`, `lang_id`, `rcp_name`)
  SELECT r.`rcp_id`, l.`lang_id`,
         CASE r.`rcp_recipients`
           WHEN 'sales@example.com'   THEN IF(l.`lang_abbr` = 'ua', 'Відділ продажів', 'Отдел продаж')
           WHEN 'support@example.com' THEN IF(l.`lang_abbr` = 'ua', 'Технічна підтримка', 'Техническая поддержка')
         END
    FROM `apps_feedback_recipient` r CROSS JOIN `share_languages` l
   WHERE r.`rcp_recipients` IN ('sales@example.com', 'support@example.com')
      ON DUPLICATE KEY UPDATE `rcp_name` = VALUES(`rcp_name`);

DROP TEMPORARY TABLE IF EXISTS `tmp_feedback`;
CREATE TEMPORARY TABLE `tmp_feedback` (
  `rcp` varchar(300) NOT NULL, `days_ago` int NOT NULL, `author` varchar(250) NOT NULL,
  `email` varchar(200) NOT NULL, `phone` varchar(10) NOT NULL,
  `theme` varchar(250) NOT NULL, `text` text NOT NULL
);
INSERT INTO `tmp_feedback` VALUES
  ('sales@example.com',   12, 'Игорь Бондаренко', 'igor@example.com',  '0661234567', 'Оптовый заказ',      'Интересует поставка партии ноутбуков для офиса. Какие условия?'),
  ('sales@example.com',    8, 'Мария Ткаченко',   'maria@example.com', '0931234567', 'Наличие товара',     'Когда снова появится «Люмен Студио 15»?'),
  ('support@example.com',  6, 'Андрей Кравец',    'andrey@example.com','0501112233', 'Не приходит письмо', 'Не получил подтверждение регистрации, проверьте, пожалуйста.'),
  ('support@example.com',  3, 'Ольга Литвин',     'olga@example.com',  '0672223344', 'Вопрос по гарантии', 'Гарантия считается с даты покупки или с даты доставки?'),
  ('sales@example.com',    1, 'Сергей Волков',    'sergey@example.com','0443334455', 'Самовывоз',          'Можно забрать заказ в выходные?');

INSERT INTO `apps_feedback` (`feed_date`, `rcp_id`, `feed_email`, `feed_phone`, `feed_author`, `feed_theme`, `feed_text`)
  SELECT NOW() - INTERVAL f.`days_ago` DAY, r.`rcp_id`, f.`email`, f.`phone`, f.`author`, f.`theme`, f.`text`
    FROM `tmp_feedback` f JOIN `apps_feedback_recipient` r ON r.`rcp_recipients` = f.`rcp`
   WHERE NOT EXISTS (SELECT 1 FROM `apps_feedback` x WHERE x.`feed_theme` = f.`theme` AND x.`feed_email` = f.`email`);
DROP TEMPORARY TABLE `tmp_feedback`;

-- ---------------------------------------------------------------------------
-- Баннеры: рекламные места и сами баннеры.
-- Изображения лежат файлами, компонент собирает адрес как MEDIA_URL + путь.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `ads_types` (`ads_type_sysname`, `ads_type_name`, `ads_type_width`, `ads_type_height`) VALUES
  ('top',    'Шапка сайта',    728, 90),
  ('center', 'Центр страницы', 468, 60);

DROP TEMPORARY TABLE IF EXISTS `tmp_ads`;
CREATE TEMPORARY TABLE `tmp_ads` (
  `type` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `active` tinyint(1) NOT NULL,
  `mode` enum('image','html') NOT NULL,
  `img` varchar(255) NULL,
  `url` varchar(255) NULL,
  `html` text NULL,
  `order_num` int NOT NULL,
  `pages` varchar(255) NULL     -- сегменты страниц через запятую; пусто = на всех
);
INSERT INTO `tmp_ads` VALUES
  ('sidebar', 'Новинки каталога', 1, 'image', 'uploads/public/demo/banner-sidebar-1.jpg', '/catalog/', NULL, 1, NULL),
  ('sidebar', 'Осенняя распродажа', 1, 'image', 'uploads/public/demo/banner-sidebar-2.jpg', '/catalog/phones/', NULL, 2, NULL),
  ('sidebar', 'Снятый с показа баннер', 0, 'image', 'uploads/public/demo/banner-sidebar-1.jpg', '/catalog/', NULL, 3, NULL),
  ('top',     'Energine Platform', 1, 'image', 'uploads/public/demo/banner-top.jpg', '/info/', NULL, 1, NULL),
  ('center',  'Подписка на новости', 1, 'html', NULL, NULL,
   '<a class="ads_promo" href="/subscribe/">Подпишитесь на рассылку — раз в неделю, без спама</a>', 1, 'news'),
  ('center',  'Баннер только для блогов', 1, 'html', NULL, NULL,
   '<a class="ads_promo" href="/catalog/">Гаджеты для работы и учёбы — в нашем каталоге</a>', 2, 'blogs');

INSERT INTO `ads_items` (`ads_type_id`, `ads_item_name`, `ads_item_is_active`, `ads_item_mode`, `ads_item_img`, `ads_item_url`, `ads_item_html`, `ads_item_order_num`)
  SELECT t.`ads_type_id`, a.`name`, a.`active`, a.`mode`, a.`img`, a.`url`, a.`html`, a.`order_num`
    FROM `tmp_ads` a JOIN `ads_types` t ON t.`ads_type_sysname` = a.`type`
   WHERE NOT EXISTS (SELECT 1 FROM `ads_items` x WHERE x.`ads_item_name` = a.`name`);

-- привязка к сайту
INSERT IGNORE INTO `ads_items2sites` (`ads_item_id`, `site_id`)
  SELECT i.`ads_item_id`, s.`site_id` FROM `ads_items` i CROSS JOIN `share_sites` s WHERE s.`site_is_default` = 1;

-- Привязка к страницам: показываем баннер только там, где он уместен.
-- Ограничиваемся разделами верхнего уровня: сегменты news и blogs встречаются
-- ещё и в админке, и в путеводителе.
SET @root_for_ads := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
INSERT IGNORE INTO `ads_items2sitemap` (`ads_item_id`, `smap_id`)
  SELECT i.`ads_item_id`, m.`smap_id`
    FROM `tmp_ads` a
    JOIN `ads_items` i ON i.`ads_item_name` = a.`name`
    JOIN `share_sitemap` m ON FIND_IN_SET(m.`smap_segment`, a.`pages`)
   WHERE a.`pages` IS NOT NULL AND m.`smap_pid` = @root_for_ads;
DROP TEMPORARY TABLE `tmp_ads`;

-- ---------------------------------------------------------------------------
-- Рассылки. Адреса подписчиков - только example.com: стенд не должен
-- отправлять письма посторонним. Дата последней отправки выставлена «сегодня»,
-- чтобы обработчик не разослал накопившееся при первом же запуске.
-- ---------------------------------------------------------------------------
INSERT INTO `mail_subscriptions` (`subscription_type`, `subscription_period`, `subscription_sent_date`, `subscription_is_active`, `subscription_is_default`, `subscription_is_hidden`)
  SELECT 'news', 'weekly', NOW(), 1, 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `mail_subscriptions_translation` x WHERE x.`subscription_name` = 'Новости сайта');
SET @sub_news := (SELECT s.`subscription_id` FROM `mail_subscriptions` s
                    LEFT JOIN `mail_subscriptions_translation` st
                      ON st.`subscription_id` = s.`subscription_id` AND st.`lang_id` = 1
                   WHERE st.`subscription_name` = 'Новости сайта' ORDER BY s.`subscription_id` DESC LIMIT 1);
SET @sub_news := COALESCE(@sub_news, LAST_INSERT_ID());

INSERT INTO `mail_subscriptions` (`subscription_type`, `subscription_period`, `subscription_sent_date`, `subscription_is_active`, `subscription_is_default`, `subscription_is_hidden`)
  SELECT 'crm', 'monthly', NOW(), 1, 0, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `mail_subscriptions_translation` x WHERE x.`subscription_name` = 'Акции и скидки');
SET @sub_crm := (SELECT s.`subscription_id` FROM `mail_subscriptions` s
                   LEFT JOIN `mail_subscriptions_translation` st
                     ON st.`subscription_id` = s.`subscription_id` AND st.`lang_id` = 1
                  WHERE st.`subscription_name` = 'Акции и скидки' ORDER BY s.`subscription_id` DESC LIMIT 1);
SET @sub_crm := COALESCE(@sub_crm, LAST_INSERT_ID());

INSERT INTO `mail_subscriptions_translation` (`subscription_id`, `lang_id`, `subscription_name`, `subscription_description`)
  SELECT @sub_news, l.`lang_id`,
         IF(l.`lang_abbr` = 'ua', 'Новини сайту', 'Новости сайта'),
         IF(l.`lang_abbr` = 'ua', 'Щотижневий огляд нових матеріалів.', 'Еженедельный обзор новых материалов.')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `subscription_name` = VALUES(`subscription_name`),
                              `subscription_description` = VALUES(`subscription_description`);
INSERT INTO `mail_subscriptions_translation` (`subscription_id`, `lang_id`, `subscription_name`, `subscription_description`)
  SELECT @sub_crm, l.`lang_id`,
         IF(l.`lang_abbr` = 'ua', 'Акції та знижки', 'Акции и скидки'),
         IF(l.`lang_abbr` = 'ua', 'Раз на місяць - про знижки в каталозі.', 'Раз в месяц — о скидках в каталоге.')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `subscription_name` = VALUES(`subscription_name`),
                              `subscription_description` = VALUES(`subscription_description`);

-- подписчики по e-mail
INSERT IGNORE INTO `mail_email_subscribers` (`me_name`, `me_date`) VALUES
  ('reader1@example.com', NOW() - INTERVAL 40 DAY),
  ('reader2@example.com', NOW() - INTERVAL 25 DAY),
  ('reader3@example.com', NOW() - INTERVAL 11 DAY),
  ('reader4@example.com', NOW() - INTERVAL 2 DAY);

INSERT INTO `mail_email2subscriptions` (`me_id`, `subscription_id`)
  SELECT e.`me_id`, @sub_news FROM `mail_email_subscribers` e
   WHERE e.`me_name` LIKE 'reader%@example.com'
     AND NOT EXISTS (SELECT 1 FROM `mail_email2subscriptions` x
                      WHERE x.`me_id` = e.`me_id` AND x.`subscription_id` = @sub_news);
INSERT INTO `mail_email2subscriptions` (`me_id`, `subscription_id`)
  SELECT e.`me_id`, @sub_crm FROM `mail_email_subscribers` e
   WHERE e.`me_name` IN ('reader1@example.com', 'reader3@example.com')
     AND NOT EXISTS (SELECT 1 FROM `mail_email2subscriptions` x
                      WHERE x.`me_id` = e.`me_id` AND x.`subscription_id` = @sub_crm);

-- Подписки зарегистрированных пользователей.
-- У связующей таблицы суррогатный ключ без уникального индекса, поэтому
-- INSERT IGNORE не спасает от повторов - проверяем явно.
INSERT INTO `mail_subscriptions2users` (`subscription_id`, `u_id`)
  SELECT @sub_news, u.`u_id` FROM `user_users` u
   WHERE u.`u_name` IN ('anna@example.com', 'olena@example.com')
     AND NOT EXISTS (SELECT 1 FROM `mail_subscriptions2users` x
                      WHERE x.`subscription_id` = @sub_news AND x.`u_id` = u.`u_id`);
INSERT INTO `mail_subscriptions2users` (`subscription_id`, `u_id`)
  SELECT @sub_crm, u.`u_id` FROM `user_users` u
   WHERE u.`u_name` = 'olena@example.com'
     AND NOT EXISTS (SELECT 1 FROM `mail_subscriptions2users` x
                      WHERE x.`subscription_id` = @sub_crm AND x.`u_id` = u.`u_id`);

-- Выпуски рассылки «Акции и скидки». Идентификатор берём явно: у mail_crm
-- нет естественного ключа, а дата вставки и дата в переводе разошлись бы.

SET @crm := (SELECT m.`crm_id` FROM `mail_crm` m
               JOIN `mail_crm_translation` mt ON mt.`crm_id` = m.`crm_id` AND mt.`lang_id` = 1
              WHERE mt.`crm_name` = 'Осенняя распродажа началась' LIMIT 1);
INSERT INTO `mail_crm` (`crm_date`, `crm_is_active`)
  SELECT NOW() - INTERVAL 34 DAY, 1 FROM DUAL WHERE @crm IS NULL;
SET @crm := COALESCE(@crm, LAST_INSERT_ID());
INSERT INTO `mail_crm_translation` (`crm_id`, `lang_id`, `crm_name`, `crm_text_rtf`)
  SELECT @crm, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Осінній розпродаж почався', 'Осенняя распродажа началась'),
         IF(l.`lang_abbr` = 'ua', '<p>Знижки на смартфони та навушники до 10%. Пропозиція діє два тижні.</p>', '<p>Скидки на смартфоны и наушники до 10%. Предложение действует две недели.</p>')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `crm_name` = VALUES(`crm_name`), `crm_text_rtf` = VALUES(`crm_text_rtf`);

SET @crm := (SELECT m.`crm_id` FROM `mail_crm` m
               JOIN `mail_crm_translation` mt ON mt.`crm_id` = m.`crm_id` AND mt.`lang_id` = 1
              WHERE mt.`crm_name` = 'Новые ноутбуки в каталоге' LIMIT 1);
INSERT INTO `mail_crm` (`crm_date`, `crm_is_active`)
  SELECT NOW() - INTERVAL 18 DAY, 1 FROM DUAL WHERE @crm IS NULL;
SET @crm := COALESCE(@crm, LAST_INSERT_ID());
INSERT INTO `mail_crm_translation` (`crm_id`, `lang_id`, `crm_name`, `crm_text_rtf`)
  SELECT @crm, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Нові ноутбуки в каталозі', 'Новые ноутбуки в каталоге'),
         IF(l.`lang_abbr` = 'ua', '<p>Додали шість моделей для роботи й навчання — від компактних до продуктивних.</p>', '<p>Добавили шесть моделей для работы и учёбы — от компактных до производительных.</p>')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `crm_name` = VALUES(`crm_name`), `crm_text_rtf` = VALUES(`crm_text_rtf`);

SET @crm := (SELECT m.`crm_id` FROM `mail_crm` m
               JOIN `mail_crm_translation` mt ON mt.`crm_id` = m.`crm_id` AND mt.`lang_id` = 1
              WHERE mt.`crm_name` = 'Сравнение товаров стало удобнее' LIMIT 1);
INSERT INTO `mail_crm` (`crm_date`, `crm_is_active`)
  SELECT NOW() - INTERVAL 5 DAY, 1 FROM DUAL WHERE @crm IS NULL;
SET @crm := COALESCE(@crm, LAST_INSERT_ID());
INSERT INTO `mail_crm_translation` (`crm_id`, `lang_id`, `crm_name`, `crm_text_rtf`)
  SELECT @crm, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Порівняння товарів стало зручнішим', 'Сравнение товаров стало удобнее'),
         IF(l.`lang_abbr` = 'ua', '<p>Тепер характеристики обраних товарів показуються однією таблицею.</p>', '<p>Теперь характеристики выбранных товаров показываются одной таблицей.</p>')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `crm_name` = VALUES(`crm_name`), `crm_text_rtf` = VALUES(`crm_text_rtf`);

SET @crm := (SELECT m.`crm_id` FROM `mail_crm` m
               JOIN `mail_crm_translation` mt ON mt.`crm_id` = m.`crm_id` AND mt.`lang_id` = 1
              WHERE mt.`crm_name` = 'Черновик следующего выпуска' LIMIT 1);
INSERT INTO `mail_crm` (`crm_date`, `crm_is_active`)
  SELECT NOW() - INTERVAL 1 DAY, 0 FROM DUAL WHERE @crm IS NULL;
SET @crm := COALESCE(@crm, LAST_INSERT_ID());
INSERT INTO `mail_crm_translation` (`crm_id`, `lang_id`, `crm_name`, `crm_text_rtf`)
  SELECT @crm, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Чернетка наступного випуску', 'Черновик следующего выпуска'),
         IF(l.`lang_abbr` = 'ua', '<p>Цей випуск неактивний і в розсилку не потрапить.</p>', '<p>Этот выпуск неактивен и в рассылку не попадёт.</p>')
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `crm_name` = VALUES(`crm_name`), `crm_text_rtf` = VALUES(`crm_text_rtf`);

-- ---------------------------------------------------------------------------
-- Подборки («топы»): группы выводятся вкладками, позиции - каруселью.
-- Картинки берём у товаров: подборки как раз на них и ссылаются.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_top_groups`;
CREATE TEMPORARY TABLE `tmp_top_groups` (
  `num` int NOT NULL, `ru` varchar(255) NOT NULL, `ua` varchar(255) NOT NULL
);
INSERT INTO `tmp_top_groups` VALUES
  (1, 'Выбор редакции', 'Вибір редакції'),
  (2, 'Хиты продаж',    'Хіти продажів');

INSERT INTO `apps_top_groups` (`tg_order_num`)
  SELECT g.`num` FROM `tmp_top_groups` g
   WHERE NOT EXISTS (SELECT 1 FROM `apps_top_groups` x WHERE x.`tg_order_num` = g.`num`);
INSERT INTO `apps_top_groups_translation` (`tg_id`, `lang_id`, `tg_name`)
  SELECT t.`tg_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', g.`ua`, g.`ru`)
    FROM `apps_top_groups` t JOIN `tmp_top_groups` g ON g.`num` = t.`tg_order_num`
    CROSS JOIN `share_languages` l
   WHERE 1   -- иначе MariaDB принимает ON DUPLICATE KEY за условие соединения
      ON DUPLICATE KEY UPDATE `tg_name` = VALUES(`tg_name`);
DROP TEMPORARY TABLE `tmp_top_groups`;

DROP TEMPORARY TABLE IF EXISTS `tmp_tops`;
CREATE TEMPORARY TABLE `tmp_tops` (
  `group_num` int NOT NULL, `num` int NOT NULL, `goods` varchar(255) NOT NULL,
  `ru_name` varchar(255) NOT NULL, `ua_name` varchar(255) NOT NULL,
  `ru_text` text NOT NULL, `ua_text` text NOT NULL
);
INSERT INTO `tmp_tops` VALUES
  (1, 1, 'aurora-x7-pro',   'Аврора X7 Pro',   'Аврора X7 Pro',
      'Лучший экран в подборке и три дня автономной работы.',
      'Найкращий екран у добірці та три дні автономної роботи.'),
  (1, 2, 'lumen-studio-15', 'Люмен Студио 15', 'Люмен Студіо 15',
      'Для монтажа и тяжёлых задач: 32 ГБ памяти.',
      'Для монтажу та важких задач: 32 ГБ пам’яті.'),
  (1, 3, 'nord-studio-h1',  'Норд Студио H1',  'Норд Студіо H1',
      'Полноразмерные наушники с честным звуком.',
      'Повнорозмірні навушники з чесним звуком.'),
  (2, 1, 'kvark-neo',       'Кварк Нео',       'Кварк Нео',
      'Самый заказываемый смартфон месяца.',
      'Найбільш замовлюваний смартфон місяця.'),
  (2, 2, 'lumen-buds',      'Люмен Бадс',      'Люмен Бадс',
      'Вкладыши, которые берут вместе с телефоном.',
      'Вкладиші, які беруть разом із телефоном.'),
  (2, 3, 'nord-work-14',    'Норд Ворк 14',    'Норд Ворк 14',
      'Недорогой ноутбук для учёбы.',
      'Недорогий ноутбук для навчання.');

INSERT INTO `apps_tops` (`top_is_active`, `tg_id`, `top_link`, `top_order_num`)
  SELECT 1, g.`tg_id`,
         CONCAT('/catalog/', (SELECT s.`smap_segment` FROM `share_sitemap` s WHERE s.`smap_id` = gd.`smap_id`),
                '/view/', gd.`goods_segment`, '/'),
         t.`num`
    FROM `tmp_tops` t
    JOIN `apps_top_groups` g ON g.`tg_order_num` = t.`group_num`
    JOIN `shop_goods` gd ON gd.`goods_segment` = t.`goods`
   WHERE NOT EXISTS (SELECT 1 FROM `apps_tops` x WHERE x.`tg_id` = g.`tg_id` AND x.`top_order_num` = t.`num`);

INSERT INTO `apps_tops_translation` (`top_id`, `lang_id`, `top_name`, `top_text_rtf`)
  SELECT p.`top_id`, l.`lang_id`,
         IF(l.`lang_abbr` = 'ua', t.`ua_name`, t.`ru_name`),
         IF(l.`lang_abbr` = 'ua', t.`ua_text`, t.`ru_text`)
    FROM `tmp_tops` t
    JOIN `apps_top_groups` g ON g.`tg_order_num` = t.`group_num`
    JOIN `apps_tops` p ON p.`tg_id` = g.`tg_id` AND p.`top_order_num` = t.`num`
    CROSS JOIN `share_languages` l
   WHERE 1   -- иначе MariaDB принимает ON DUPLICATE KEY за условие соединения
      ON DUPLICATE KEY UPDATE `top_name` = VALUES(`top_name`), `top_text_rtf` = VALUES(`top_text_rtf`);

-- картинка позиции - та же, что у товара
INSERT INTO `apps_tops_uploads` (`top_id`, `upl_id`)
  SELECT p.`top_id`, u.`upl_id`
    FROM `tmp_tops` t
    JOIN `apps_top_groups` g ON g.`tg_order_num` = t.`group_num`
    JOIN `apps_tops` p ON p.`tg_id` = g.`tg_id` AND p.`top_order_num` = t.`num`
    JOIN `share_uploads` u ON u.`upl_path` = CONCAT('uploads/public/demo/', t.`goods`, '.jpg')
   WHERE NOT EXISTS (SELECT 1 FROM `apps_tops_uploads` x WHERE x.`top_id` = p.`top_id` AND x.`upl_id` = u.`upl_id`);
DROP TEMPORARY TABLE `tmp_tops`;

-- ---------------------------------------------------------------------------
-- Оформление разделов: бренд назначается странице и наследуется дочерними.
-- ---------------------------------------------------------------------------
INSERT INTO `apps_branding` (`brand_name`, `brand_main_img`, `brand_bgcolor`, `brand_min_height`, `brand_css_rule`)
  SELECT 'Каталог', 'uploads/public/demo/brand-catalog.jpg', '#2f6fed', 140,
         '.branding .branding_image { display: block; width: 100%; height: auto; }'
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `apps_branding` x WHERE x.`brand_name` = 'Каталог');
INSERT INTO `apps_branding` (`brand_name`, `brand_main_img`, `brand_bgcolor`, `brand_min_height`, `brand_css_rule`)
  SELECT 'Блоги', 'uploads/public/demo/brand-blogs.jpg', '#7a3ea8', 140,
         '.branding .branding_image { display: block; width: 100%; height: auto; }'
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `apps_branding` x WHERE x.`brand_name` = 'Блоги');

-- только публичные разделы верхнего уровня: сегмент blogs есть и в админке
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
UPDATE `share_sitemap` s
   JOIN `apps_branding` b ON b.`brand_name` = 'Каталог'
    SET s.`brand_id` = b.`brand_id`
  WHERE s.`smap_segment` = 'catalog' AND s.`smap_pid` = @root AND s.`brand_id` IS NULL;
UPDATE `share_sitemap` s
   JOIN `apps_branding` b ON b.`brand_name` = 'Блоги'
    SET s.`brand_id` = b.`brand_id`
  WHERE s.`smap_segment` = 'blogs' AND s.`smap_pid` = @root AND s.`brand_id` IS NULL;

-- ---------------------------------------------------------------------------
-- HTML-врезки на конкретной странице (apps\Ads). Наследуются дочерними,
-- поэтому достаточно задать их разделу.
-- ---------------------------------------------------------------------------
INSERT INTO `apps_ads` (`smap_id`, `ad_content_468_60`)
  SELECT s.`smap_id`,
         '<div class="page_promo">Этот блок задан прямо на странице «Информация» и наследуется её подразделами.</div>'
    FROM `share_sitemap` s
   WHERE s.`smap_segment` = 'info'
     AND NOT EXISTS (SELECT 1 FROM `apps_ads` x WHERE x.`smap_id` = s.`smap_id`);

-- ---------------------------------------------------------------------------
-- Страница с медиа: галерея вложений раздела (компонент PageMedia).
-- Видео на этом хосте не показываем: перекодировка требует ffmpeg,
-- которого нет, и параметр video.ffmpeg не задан.
-- ---------------------------------------------------------------------------
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'media_textblock.content.xml', @root, 'media',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @root), 0) + 1
    FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @root AND x.`smap_segment` = 'media');
SET @media := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'media');

INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_description_rtf`, `smap_is_disabled`)
  SELECT @media, l.`lang_id`,
         IF(l.`lang_abbr` = 'ua', 'Галерея', 'Галерея'),
         IF(l.`lang_abbr` = 'ua',
            'Вкладення розділу: рушій показує їх галереєю з перемиканням.',
            'Вложения раздела: движок показывает их галереей с перелистыванием.'),
         0
    FROM `share_languages` l
      ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`),
                              `smap_description_rtf` = VALUES(`smap_description_rtf`);

INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @media, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @media, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- вложения страницы: берём картинки товаров, они уже в репозитории
INSERT INTO `share_sitemap_uploads` (`smap_id`, `upl_id`, `ssu_order_num`)
  SELECT @media, u.`upl_id`, ROW_NUMBER() OVER (ORDER BY u.`upl_path`)
    FROM `share_uploads` u
   WHERE u.`upl_path` IN ('uploads/public/demo/aurora-x7-pro.jpg',
                          'uploads/public/demo/lumen-studio-15.jpg',
                          'uploads/public/demo/nord-studio-h1.jpg',
                          'uploads/public/demo/vektor-one-max.jpg')
     AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x
                      WHERE x.`smap_id` = @media AND x.`upl_id` = u.`upl_id`);

-- ---------------------------------------------------------------------------
-- Украинские переводы демо-новостей и проектов.
-- В стартовом наборе украинские записи были копией русских.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `tmp_news_ua`;
CREATE TEMPORARY TABLE `tmp_news_ua` (
  -- сортировка как у apps_news.news_segment, иначе соединение несовместимо
  `segment` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL,
  `title` varchar(255) NOT NULL,
  `announce` text NOT NULL
);
INSERT INTO `tmp_news_ua` VALUES
  ('dobro-pozhalovaty', 'Глобальне оновлення Energine',
   'Раді повідомити про випуск нової версії Energine 2.11.1.beta.'),
  ('new-gcc-4-8-0', 'Вийшов GCC 4.8.0',
   'Вийшла нова версія набору компіляторів GNU — 4.8.0.'),
  ('richard-stollman-protiv-c', 'Річард Столлман проти C#',
   'Річард Столлман застеріг від використання середовища Mono для створення вільного програмного забезпечення.'),
  ('linuxfmonlajn-radio-veshhajushheje-iskhodnyj-kod-jadra-linux',
   'Linux.fm — онлайн-радіо, що озвучує вихідний код ядра Linux',
   'В інтернеті з’явилося радіо, яке зачитує вихідний код ядра Linux.');

UPDATE `apps_news_translation` t
  JOIN `apps_news` n ON n.`news_id` = t.`news_id`
  JOIN `tmp_news_ua` u ON u.`segment` = n.`news_segment`
   SET t.`news_title` = u.`title`, t.`news_announce_rtf` = u.`announce`
 WHERE t.`lang_id` = (SELECT `lang_id` FROM `share_languages` WHERE `lang_abbr` = 'ua');
DROP TEMPORARY TABLE `tmp_news_ua`;

-- Проекты: в стартовом наборе украинская версия дублировала русскую
DROP TEMPORARY TABLE IF EXISTS `tmp_feed_ua`;
CREATE TEMPORARY TABLE `tmp_feed_ua` (
  `ru_name` varchar(256) NOT NULL,
  `ua_name` varchar(256) NOT NULL,
  `ua_annotation` text NOT NULL
);
INSERT INTO `tmp_feed_ua` VALUES
  ('Проект запуска Energine на ZX Spectrum',
   'Проєкт запуску Energine на ZX Spectrum',
   'Уперше нам вдалося запустити полегшену версію Energine на комп’ютері, сумісному із ZX Spectrum, під керуванням прошивки Pentagon 1024SL.'),
  ('Проект Energine Starter',
   'Проєкт Energine Starter',
   'Короткий опис проєкту Energine Starter.');

UPDATE `apps_feed_translation` t
  JOIN `apps_feed_translation` ru ON ru.`tf_id` = t.`tf_id`
   AND ru.`lang_id` = (SELECT `lang_id` FROM `share_languages` WHERE `lang_abbr` = 'ru')
  JOIN `tmp_feed_ua` u ON u.`ru_name` = ru.`tf_name`
   SET t.`tf_name` = u.`ua_name`, t.`tf_annotation_rtf` = u.`ua_annotation`
 WHERE t.`lang_id` = (SELECT `lang_id` FROM `share_languages` WHERE `lang_abbr` = 'ua');
DROP TEMPORARY TABLE `tmp_feed_ua`;

-- ===========================================================================
-- Путеводитель «Возможности»: по странице на модуль.
-- Каждая страница - текстовый блок с описанием и ссылками «где посмотреть»
-- и «где управлять». Раздел добавляется в главное меню.
-- ===========================================================================

SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
SET @site := (SELECT site_id FROM `share_sites` WHERE `site_is_default` = 1 LIMIT 1);

INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'childs.content.xml', @root, 'features',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @root), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @root AND x.`smap_segment` = 'features');
SET @features := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'features');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_description_rtf`, `smap_is_disabled`)
  SELECT @features, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Можливості', 'Возможности'),
         IF(l.`lang_abbr` = 'ua', 'Путівник: що вміє система і де це подивитися.', 'Путеводитель: что умеет система и где это посмотреть.'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`), `smap_description_rtf` = VALUES(`smap_description_rtf`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @features, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @features, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Структура и тексты
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'content', 1 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'content');
SET @f_content := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'content');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_content, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Структура і тексти', 'Структура и тексты'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_content, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_content, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_content AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_content AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Сайт складається з розділів; у кожного є шаблон розмітки та набір компонентів. Тексти правляться просто на сторінці: адміністратор вмикає режим редагування та змінює вміст без окремої форми.</p>
  <p>Блоки можна перетягувати між колонками й додавати з набору віджетів — опитування, банер, текстовий блок.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/">Головна сторінка</a></li><li><a href="/ua/sitemap/">Карта сайту</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/structure/">Керування структурою</a></li><li><a href="/ua/admin/widgets/">Віджети</a></li></ul>', '<p>Сайт состоит из разделов; у каждого раздела есть шаблон разметки и набор компонентов. Тексты правятся прямо на странице: администратор включает режим редактирования и меняет содержимое без отдельной формы.</p>
  <p>Блоки можно перетаскивать между колонками и добавлять из набора виджетов — опрос, баннер, текстовый блок.</p>
  <h3>Посмотреть</h3><ul><li><a href="/">Главная страница</a> — текстовые блоки, опрос, подборки</li><li><a href="/sitemap/">Карта сайта</a> — всё дерево разделов</li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/structure/">Управление структурой</a></li><li><a href="/admin/widgets/">Виджеты</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Новости
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'news', 2 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'news');
SET @f_news := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'news');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_news, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Новини', 'Новости'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_news, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_news, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_news AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_news AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Стрічка з посторінковою навігацією, сторінка новини, вкладення, теги й хмара тегів, архів за датами, календар і стрічка RSS. Новини з майбутньою датою та зняті з публікації бачить лише редактор.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/news/">Стрічка новин</a></li><li><a href="/ua/news/tag/13/">Новини за тегом</a></li><li><a href="/ua/news/2013/4/">Архів за квітень 2013</a></li><li><a href="/ua/news/rss/">Стрічка RSS</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/news-editor/">Редактор новин</a></li></ul>', '<p>Лента с постраничной навигацией, страница новости, вложения, теги и облако тегов, архив по датам, календарь и лента RSS. Новости с будущей датой и снятые с публикации видны только редактору.</p>
  <h3>Посмотреть</h3><ul><li><a href="/news/">Лента новостей</a> — календарь и облако тегов слева</li><li><a href="/news/tag/13/">Новости по тегу</a></li><li><a href="/news/2013/4/">Архив за апрель 2013</a></li><li><a href="/news/rss/">Лента RSS</a></li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/news-editor/">Редактор новостей</a></li><li><a href="/admin/news-categories/">Рубрики новостей</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Блоги
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'blogs', 3 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'blogs');
SET @f_blogs := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'blogs');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_blogs, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Блоги', 'Блоги'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_blogs, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_blogs, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_blogs AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_blogs AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>У кожного автора свій блог. Записи з майбутньою датою публікуються самі — до того їх бачить лише власник. Ліворуч календар: дні із записами клікабельні.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/blogs/">Усі записи</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/blogs/">Блоги</a></li></ul>', '<p>У каждого автора свой блог. Записи с будущей датой публикуются сами — до этого их видит только владелец. Слева календарь: дни с записями кликабельны.</p>
  <p>Комментировать может только вошедший пользователь — так настроена эта страница.</p>
  <h3>Посмотреть</h3><ul><li><a href="/blogs/">Все записи</a></li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/blogs/">Блоги</a></li><li><a href="/admin/blogs/posts/">Записи</a></li><li><a href="/admin/blogs/comments/">Комментарии блогов</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Магазин
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'shop', 4 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'shop');
SET @f_shop := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'shop');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_shop, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Магазин', 'Магазин'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_shop, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_shop, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_shop AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_shop AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Каталог із категоріями, фільтром за ціною, виробником і характеристиками, сортуванням, порівнянням товарів, схожими товарами та аксесуарами, акціями, кошиком, обраним і замовленнями покупця. Ціни показуються в обраній валюті й перераховуються за курсом.</p>
  <p>Оформлення замовлення на сайті немає — у цій версії рушія замовлення заводить менеджер в адмінці.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/catalog/">Каталог</a></li><li><a href="/ua/catalog/phones/view/aurora-x7-pro/">Картка товару</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/shop/goods/">Товари</a></li></ul>', '<p>Каталог с категориями, фильтром по цене, производителю и характеристикам, сортировкой, сравнением товаров, похожими товарами и аксессуарами, акциями, корзиной, избранным и заказами покупателя. Цены показываются в выбранной валюте и пересчитываются по курсу.</p>
  <p>Оформления заказа на сайте нет — в этой версии движка заказы заводит менеджер в админке.</p>
  <h3>Посмотреть</h3><ul><li><a href="/catalog/">Каталог</a></li><li><a href="/catalog/phones/?filter=color=34">Фильтр: чёрные смартфоны</a></li><li><a href="/catalog/phones/view/aurora-x7-pro/">Карточка товара</a> — характеристики, похожие, аксессуары</li><li><a href="/search/?keyword=Аврора">Поиск</a></li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/shop/goods/">Товары</a></li><li><a href="/admin/shop/features/">Характеристики</a></li><li><a href="/admin/shop/orders/">Заказы</a></li><li><a href="/admin/shop/promotions/">Акции</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Формы
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'forms', 5 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'forms');
SET @f_forms := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'forms');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_forms, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Форми', 'Формы'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_forms, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_forms, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_forms AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_forms AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Конструктор форм створює форму й таблицю під неї: рядок, e-mail, телефон, прапорець, список, набір прапорців, дата, файл. Відповіді потрапляють в окрему таблицю.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/form-example/">Приклад форми</a></li><li><a href="/ua/contacts/">Зворотний зв’язок</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/form-builder/">Конструктор форм</a></li></ul>', '<p>Конструктор форм создаёт форму и таблицу под неё: строка, e-mail, телефон, флажок, список, набор флажков, дата, файл. Ответы попадают в отдельную таблицу, их можно посмотреть и выгрузить.</p>
  <h3>Посмотреть</h3><ul><li><a href="/form-example/">Пример формы</a></li><li><a href="/contacts/">Обратная связь</a> — отдельный компонент с выбором получателя</li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/form-builder/">Конструктор форм</a></li><li><a href="/admin/feedback-editor/">Обратная связь</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Комментарии
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'comments', 6 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'comments');
SET @f_comments := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'comments');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_comments, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Коментарі', 'Комментарии'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_comments, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_comments, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_comments AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_comments AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Коментарі підключаються до будь-якого списку: новин, записів блогу, текстових сторінок. Підтримуються відповіді, обмеження довжини, анонімні коментарі та модерація.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/news/2--new-gcc-4-8-0/">Новина з гілкою коментарів</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/comments-editor/">Редактор коментарів</a></li></ul>', '<p>Комментарии подключаются к любому списку: новостям, записям блога, текстовым страницам. Поддерживаются ответы, ограничение длины, анонимные комментарии и модерация.</p>
  <p>В новостях анонимные комментарии разрешены, в блогах — только для вошедших.</p>
  <h3>Посмотреть</h3><ul><li><a href="/news/2--new-gcc-4-8-0/">Новость с веткой комментариев</a></li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/comments-editor/">Редактор комментариев</a> — в том числе неодобренные</li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Рассылки
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'mail', 7 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'mail');
SET @f_mail := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'mail');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_mail, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Розсилки', 'Рассылки'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_mail, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_mail, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_mail AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_mail AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Два види розсилок: дайджест новин і окремі випуски. Передплатниками можуть бути і зареєстровані користувачі, і просто адреси.</p>
  <p>На цьому стенді ввімкнено режим налагодження: листи не йдуть назовні, а пишуться у файл.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/subscribe/">Підписатися</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/mail-subscriptions/">Розсилки</a></li></ul>', '<p>Два вида рассылок: дайджест новостей и отдельные выпуски. Подписчиками могут быть и зарегистрированные пользователи, и просто адреса. Письма собираются из шаблонов, которые правятся в админке.</p>
  <p>На этом стенде включён режим отладки: письма не уходят наружу, а пишутся в файл.</p>
  <h3>Посмотреть</h3><ul><li><a href="/subscribe/">Подписаться</a></li><li><a href="/subscriptions/">Мои подписки</a> — для вошедшего пользователя</li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/mail-subscriptions/">Рассылки</a></li><li><a href="/admin/mail-subscribers/">Подписчики</a></li><li><a href="/admin/mail-crm/">Выпуски</a></li><li><a href="/admin/mail-templates/">Шаблоны писем</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Баннеры
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'ads', 8 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'ads');
SET @f_ads := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'ads');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_ads, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Банери', 'Баннеры'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_ads, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_ads, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_ads AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_ads AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Два різні механізми. Перший — банерні місця: у кожного свій розмір, банери показуються по черзі або випадково і прив’язуються до сайтів і сторінок. Другий — HTML-врізки, задані розділу й успадковані його підрозділами.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/news/">Новини</a></li><li><a href="/ua/catalog/phones/">Каталог</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/ads-types/">Банерні місця</a></li></ul>', '<p>Два разных механизма. Первый — баннерные места: у каждого свой размер, баннеры показываются по очереди или случайно и привязываются к сайтам и страницам. Второй — HTML-врезки, заданные прямо на разделе и унаследованные его подразделами.</p>
  <h3>Посмотреть</h3><ul><li><a href="/news/">Новости</a> — врезка в центре страницы</li><li><a href="/catalog/phones/">Каталог</a> — баннер в боковой колонке</li><li><a href="/info/">Информация</a> и её подраздел — врезка, заданная разделу и унаследованная</li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/ads-types/">Баннерные места</a></li><li><a href="/admin/ads-items/">Баннеры</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Файлы и медиа
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'media', 9 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'media');
SET @f_media := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'media');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_media, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Файли та медіа', 'Файлы и медиа'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_media, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_media, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_media AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_media AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Файловий менеджер із деревом тек, завантаженням і мініатюрами. Зображення віддаються через ресайзер: одне джерело і будь-які розміри в розмітці.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/media/">Галерея</a></li></ul>', '<p>Файловый менеджер с деревом папок, загрузкой и миниатюрами. Изображения отдаются через ресайзер: один исходник и любые размеры в разметке. К странице, новости или товару можно прикрепить набор файлов — он выводится лентой.</p>
  <p>Перекодировка видео требует ffmpeg, на этом хосте он не установлен.</p>
  <h3>Посмотреть</h3><ul><li><a href="/media/">Галерея</a> — вложения раздела</li><li><a href="/news/1--dobro-pozhalovaty/">Новость с вложением</a></li></ul>
  <h3>В админке</h3><p>Файловый менеджер открывается из режима редактирования и из форм, где есть поле файла.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Пользователи и права
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'users', 10 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'users');
SET @f_users := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'users');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_users, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Користувачі та права', 'Пользователи и права'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_users, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_users, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_users AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_users AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Користувачі об’єднуються в групи, у групи свої права на кожен розділ: без доступу, читання, зміна, повний доступ. Є реєстрація, відновлення пароля та профіль.</p>
  <p>Демо-покупець: <b>olena@example.com</b> / <b>demo</b>.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/register/">Реєстрація</a></li></ul>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/users/">Користувачі</a></li></ul>', '<p>Пользователи объединяются в группы, у группы свои права на каждый раздел: без доступа, чтение, изменение, полный доступ. Есть регистрация, восстановление пароля и профиль.</p>
  <p>Демо-покупатель: <b>olena@example.com</b> / <b>demo</b> — у него есть заказы и подписки.</p>
  <h3>Посмотреть</h3><ul><li><a href="/register/">Регистрация</a></li><li><a href="/profile/">Профиль</a> — после входа</li><li><a href="/my-orders/">Мои заказы</a> — после входа</li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/users/">Пользователи</a></li><li><a href="/admin/users/roles/">Роли и права</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Языки и переводы
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'i18n', 11 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'i18n');
SET @f_i18n := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'i18n');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_i18n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Мови та переклади', 'Языки и переводы'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_i18n, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_i18n, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_i18n AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_i18n AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Сайт двомовний: російська та українська. Перекладається і вміст, і підписи інтерфейсу. Мова за замовчуванням іде без префікса в адресі.</p>
  <p>Чесне застереження: записи блогу, коментарі та повідомлення зворотного зв’язку зберігаються однією версією на обидві мови — у рушія в цих таблиць немає перекладів.</p>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/translations/">Переклади інтерфейсу</a></li></ul>', '<p>Сайт двуязычный: русский и украинский. Переводится и содержимое, и подписи интерфейса. Язык по умолчанию идёт без префикса в адресе, остальные — с префиксом.</p>
  <p>Честная оговорка: записи блога, комментарии и сообщения обратной связи хранятся одной версией на оба языка — в движке у этих таблиц нет переводов.</p>
  <h3>Посмотреть</h3><ul><li><a href="/ua/catalog/phones/">Каталог по-украински</a></li><li><a href="/ua/news/">Новости по-украински</a></li></ul>
  <h3>В админке</h3><ul><li><a href="/admin/translations/">Переводы интерфейса</a></li><li><a href="/admin/translations/languages/">Языки</a></li></ul>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Адреса и поисковики
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'seo', 12 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'seo');
SET @f_seo := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'seo');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_seo, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Адреси та пошуковики', 'Адреса и поисковики'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_seo, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_seo, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_seo AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_seo AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Зрозумілі адреси, окремі заголовок, ключові слова й опис для кожної сторінки та мови, налаштування індексації, карта сайту для пошуковиків і robots.</p>
  <h3>Подивитися</h3><ul><li><a href="/ua/sitemap/">Карта сайту</a></li></ul>', '<p>Человекопонятные адреса, отдельные заголовок, ключевые слова и описание для каждой страницы и языка, настройка индексации, карта сайта для поисковиков и robots.</p>
  <p>Особенность хоста: файл robots.txt отдаёт веб-сервер, поэтому компонент доступен по адресу со слешем.</p>
  <h3>Посмотреть</h3><ul><li><a href="/google-sitemap/">Карта сайта для поисковиков</a></li><li><a href="/robots.txt/">robots от движка</a></li><li><a href="/sitemap/">Карта сайта для людей</a></li></ul>
  <h3>В админке</h3><p>Метаданные страницы правятся в свойствах раздела в <a href="/admin/structure/">редакторе структуры</a>.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);

-- Админка
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'textblock.content.xml', @features, 'admin', 13 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @features AND x.`smap_segment` = 'admin');
SET @f_admin := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @features AND `smap_segment` = 'admin');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @f_admin, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Адмінка', 'Админка'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @f_admin, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;
INSERT INTO `share_textblocks` (`smap_id`, `tb_num`)
  SELECT @f_admin, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` x WHERE x.`smap_id` = @f_admin AND x.`tb_num` = '1');
SET @tb := (SELECT tb_id FROM `share_textblocks` WHERE `smap_id` = @f_admin AND `tb_num` = '1');
INSERT INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
  SELECT @tb, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Вхід: <b>demo@energine.org</b> / <b>demo</b>. Розділи адмінки зібрані на <a href="/ua/admin/">одній сторінці</a>.</p>
  <p>Це відкритий стенд: логін адміністратора опубліковано навмисно.</p>
  <h3>В адмінці</h3><ul><li><a href="/ua/admin/action-log/">Журнал дій</a></li><li><a href="/ua/admin/branding/">Оформлення розділів</a></li></ul>', '<p>Вход: <b>demo@energine.org</b> / <b>demo</b>. Разделы админки собраны на <a href="/admin/">одной странице</a>.</p>
  <p>Кроме редакторов содержимого есть журнал действий, редактор сайтов и доменов, подборки и оформление разделов.</p>
  <h3>В админке</h3><ul><li><a href="/admin/action-log/">Журнал действий</a></li><li><a href="/admin/structure/sites/">Сайты и домены</a></li><li><a href="/admin/tops/">Подборки</a> и <a href="/admin/tops-groups/">их группы</a></li><li><a href="/admin/branding/">Оформление разделов</a></li></ul>
  <p>Это открытый стенд: логин администратора опубликован намеренно. Всё, что вы измените, может быть возвращено к исходному состоянию.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `tb_content` = VALUES(`tb_content`);


-- ---------------------------------------------------------------------------
-- Константы интерфейса, добавленные вместе с доделанными компонентами
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES
  ('BTN_COMPARE'), ('TXT_COMPARE_SELECTED'), ('TXT_COMPARE_CLEAR'), ('TXT_COMPARE_EMPTY'),
  ('TXT_LAST_SEEN_GOODS'), ('TXT_MY_ORDERS_EMPTY'), ('TXT_SAVED_FILTERS'), ('TXT_SAVE_FILTER_NAME'),
  ('FIELD_EMAIL'), ('FIELD_SU_ID'), ('FIELD_MES_ID');

INSERT INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`,
         CASE t.`ltag_name`
           WHEN 'BTN_COMPARE'          THEN IF(l.`lang_abbr` = 'ua', 'Порівняти',      'Сравнить')
           WHEN 'TXT_COMPARE_SELECTED' THEN IF(l.`lang_abbr` = 'ua', 'Обрано товарів для порівняння:', 'Выбрано товаров для сравнения:')
           WHEN 'TXT_COMPARE_CLEAR'    THEN IF(l.`lang_abbr` = 'ua', 'Очистити',       'Очистить')
           WHEN 'TXT_COMPARE_EMPTY'    THEN IF(l.`lang_abbr` = 'ua', 'Немає товарів для порівняння', 'Нет товаров для сравнения')
           WHEN 'TXT_LAST_SEEN_GOODS'  THEN IF(l.`lang_abbr` = 'ua', 'Ви нещодавно дивилися', 'Вы недавно смотрели')
           WHEN 'TXT_MY_ORDERS_EMPTY'  THEN IF(l.`lang_abbr` = 'ua', 'У вас поки немає замовлень', 'У вас пока нет заказов')
           WHEN 'TXT_SAVED_FILTERS'    THEN IF(l.`lang_abbr` = 'ua', 'Збережені фільтри', 'Сохранённые фильтры')
           WHEN 'TXT_SAVE_FILTER_NAME' THEN IF(l.`lang_abbr` = 'ua', 'Назва фільтра',  'Название фильтра')
           WHEN 'FIELD_EMAIL'          THEN 'E-mail'
           WHEN 'FIELD_SU_ID'          THEN IF(l.`lang_abbr` = 'ua', 'Підписник',      'Подписчик')
           WHEN 'FIELD_MES_ID'         THEN IF(l.`lang_abbr` = 'ua', 'Адреса',         'Адрес')
         END
    FROM `share_lang_tags` t CROSS JOIN `share_languages` l
   WHERE t.`ltag_name` IN ('BTN_COMPARE', 'TXT_COMPARE_SELECTED', 'TXT_COMPARE_CLEAR', 'TXT_COMPARE_EMPTY',
                           'TXT_LAST_SEEN_GOODS', 'TXT_MY_ORDERS_EMPTY', 'TXT_SAVED_FILTERS',
                           'TXT_SAVE_FILTER_NAME', 'FIELD_EMAIL', 'FIELD_SU_ID', 'FIELD_MES_ID')
      ON DUPLICATE KEY UPDATE `ltag_value_rtf` = VALUES(`ltag_value_rtf`);

-- ---------------------------------------------------------------------------
-- Страницы, добавленные вместе с доделанными компонентами.
-- Публичные читают все, админские - только группа администраторов.
-- Страницу карты сайта для поисковиков умеет создавать сам компонент Robots,
-- но тогда она появляется лишь после первого обращения к /robots.txt/.
-- ---------------------------------------------------------------------------
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
SET @admin := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'admin');
SET @site := (SELECT site_id FROM `share_sites` WHERE `site_is_default` = 1 LIMIT 1);

-- Google sitemap
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'google_sitemap.content.xml', @root, 'google-sitemap',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @root), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @root AND x.`smap_segment` = 'google-sitemap');
SET @p_google_sitemap := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'google-sitemap');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_google_sitemap, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Google sitemap', 'Google sitemap'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @p_google_sitemap, g.`group_id`, IF(g.`group_id` = 1, 3, 1) FROM `user_groups` g;

-- Профиль пользователя
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'user_profile.content.xml', @root, 'profile',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @root), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @root AND x.`smap_segment` = 'profile');
SET @p_profile := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'profile');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_profile, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Профіль користувача', 'Профиль пользователя'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
-- профиль доступен вошедшему пользователю, гостю - нет
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT @p_profile, g.`group_id`, IF(g.`group_id` = 1, 3, 2) FROM `user_groups` g WHERE g.`group_default` = 0;
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_profile, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Журнал действий
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'log.content.xml', @admin, 'action-log',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @admin), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @admin AND x.`smap_segment` = 'action-log');
SET @p_action_log := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @admin AND `smap_segment` = 'action-log');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_action_log, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Журнал дій', 'Журнал действий'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`) VALUES (@p_action_log, 1, 3);
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_action_log, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Оформление разделов
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'branding_editor.content.xml', @admin, 'branding',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @admin), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @admin AND x.`smap_segment` = 'branding');
SET @p_branding := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @admin AND `smap_segment` = 'branding');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_branding, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Оформлення розділів', 'Оформление разделов'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`) VALUES (@p_branding, 1, 3);
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_branding, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Рубрики новостей
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'main/news_categories_editor.content.xml', @admin, 'news-categories',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @admin), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @admin AND x.`smap_segment` = 'news-categories');
SET @p_news_categories := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @admin AND `smap_segment` = 'news-categories');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_news_categories, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Рубрики новин', 'Рубрики новостей'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`) VALUES (@p_news_categories, 1, 3);
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_news_categories, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Подборки
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'totp_editor.content.xml', @admin, 'tops',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @admin), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @admin AND x.`smap_segment` = 'tops');
SET @p_tops := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @admin AND `smap_segment` = 'tops');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_tops, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Добірки', 'Подборки'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`) VALUES (@p_tops, 1, 3);
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_tops, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- Группы подборок
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', 'totp_group_editor.content.xml', @admin, 'tops-groups',
         COALESCE((SELECT MAX(s.`smap_order_num`) FROM `share_sitemap` s WHERE s.`smap_pid` = @admin), 0) + 1
    FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = @admin AND x.`smap_segment` = 'tops-groups');
SET @p_tops_groups := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @admin AND `smap_segment` = 'tops-groups');
INSERT INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
  SELECT @p_tops_groups, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Групи добірок', 'Группы подборок'), 0
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `smap_name` = VALUES(`smap_name`);
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`) VALUES (@p_tops_groups, 1, 3);
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT @p_tops_groups, t.`tag_id` FROM `share_tags` t WHERE t.`tag_code` = 'menu';

-- «Мои заказы» ниоткуда не было видно
INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT s.`smap_id`, t.`tag_id` FROM `share_sitemap` s CROSS JOIN `share_tags` t
   WHERE s.`smap_pid` = @root AND s.`smap_segment` = 'my-orders' AND t.`tag_code` = 'menu';

-- ===========================================================================
-- Свежие новости: даты за последние месяцы, теги, картинки.
-- Одна снята с публикации, одна датирована будущим - обе видны только редактору.
-- ===========================================================================
SET @news_smap := (SELECT smap_id FROM `share_sitemap` WHERE `smap_segment` = 'news' LIMIT 1);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 78 DAY, 'energine-na-php-85', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'energine-na-php-85');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'energine-na-php-85');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Energine працює на PHP 8.5', 'Energine работает на PHP 8.5'),
         IF(l.`lang_abbr` = 'ua', 'Ядро переведено з PHP 7.0 на 8.5: прибрано застарілі конструкції, виправлено попередження.', 'Ядро переведено с PHP 7.0 на 8.5: убраны устаревшие конструкции, исправлены предупреждения.'),
         IF(l.`lang_abbr` = 'ua', '<p>Перехід тривав у кілька етапів: спочатку синтаксис, потім робота з масивами й рядками, де PHP 8 став суворішим, і наприкінці — бібліотеки.</p>', '<p>Переход занял несколько этапов: сначала синтаксис, затем работа с массивами и строками, где PHP 8 стал строже, и в конце — библиотеки.</p><p>Проверка шла обходом всех страниц браузером: так находятся ошибки, которые статический анализ не видит.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'energine,releases');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/aurora-x5.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 71 DAY, 'catalog-filtry', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'catalog-filtry');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'catalog-filtry');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Фільтр каталогу: як він влаштований', 'Фильтр каталога: как он устроен'),
         IF(l.`lang_abbr` = 'ua', 'Характеристика потрапляє у фільтр, якщо має прив’язку до розділу, до сайту, переклад і ознаку «бере участь у фільтрі».', 'Характеристика попадает в фильтр, если у неё есть привязка к разделу, к сайту, перевод и признак «участвует в фильтре».'),
         IF(l.`lang_abbr` = 'ua', '<p>Тип характеристики визначає вигляд елемента: набір прапорців, повзунок діапазону або один вибір.</p>', '<p>Тип характеристики определяет вид элемента: набор флажков, ползунок диапазона или один выбор. Числовые диапазоны работают только при числовых значениях вариантов.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'webdev');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/kvark-neo-plus.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 64 DAY, 'sravnenie-tovarov', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'sravnenie-tovarov');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'sravnenie-tovarov');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Порівняння товарів', 'Сравнение товаров'),
         IF(l.`lang_abbr` = 'ua', 'Обрані товари показуються однією таблицею: рядки — характеристики, стовпці — товари.', 'Выбранные товары показываются одной таблицей: строки — характеристики, столбцы — товары.'),
         IF(l.`lang_abbr` = 'ua', '<p>Характеристики зіставляються за системним іменем, а не за підписом.</p>', '<p>Характеристики сопоставляются по системному имени, а не по подписи, поэтому в таблицу попадают и те, которых у части товаров нет — в таких клетках стоит прочерк.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'webdev');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/vektor-one-max.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 57 DAY, 'dve-valyuty', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'dve-valyuty');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'dve-valyuty');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Ціни у трьох валютах', 'Цены в трёх валютах'),
         IF(l.`lang_abbr` = 'ua', 'Відвідувач обирає валюту, і ціни перераховуються за курсом із довідника.', 'Посетитель выбирает валюту, и цены пересчитываются по курсу из справочника.'),
         IF(l.`lang_abbr` = 'ua', '<p>Товар зберігає ціну у своїй валюті. Замовлення запам’ятовує валюту, у якій було оформлене.</p>', '<p>Товар хранит цену в своей валюте. Заказ запоминает валюту, в которой был оформлен, — пересчитывать историю нельзя.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'webdev,releases');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/lumen-air.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 48 DAY, 'blogi-otlozhennye', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'blogi-otlozhennye');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'blogi-otlozhennye');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Відкладена публікація в блогах', 'Отложенная публикация в блогах'),
         IF(l.`lang_abbr` = 'ua', 'Запис із майбутньою датою бачить лише власник блогу, доки не настане термін.', 'Запись с будущей датой видна только владельцу блога, пока не наступит срок.'),
         IF(l.`lang_abbr` = 'ua', '<p>Окремого планувальника не потрібно: список записів просто не показує майбутні дати звичайним відвідувачам.</p>', '<p>Отдельного планировщика не нужно: список записей просто не показывает будущие даты обычным посетителям.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'webdev');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/aurora-book-13.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 39 DAY, 'rassylki-bez-spama', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'rassylki-bez-spama');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'rassylki-bez-spama');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Розсилки: дайджест та окремі випуски', 'Рассылки: дайджест и отдельные выпуски'),
         IF(l.`lang_abbr` = 'ua', 'Дайджест збирається з новин за період, випуски пишуться вручну.', 'Дайджест собирается из новостей за период, выпуски пишутся вручную.'),
         IF(l.`lang_abbr` = 'ua', '<p>Порожній дайджест більше не надсилається.</p>', '<p>Пустой дайджест больше не отправляется: если за период ничего не вышло, письмо не уходит, а дата последней отправки сдвигается.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'energine');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/lumen-buds.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 30 DAY, 'bannery-adresno', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'bannery-adresno');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'bannery-adresno');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Банери показуються адресно', 'Баннеры показываются адресно'),
         IF(l.`lang_abbr` = 'ua', 'Банер можна прив’язати до сайту й до конкретних сторінок; без прив’язок він вважається загальним.', 'Баннер можно привязать к сайту и к конкретным страницам; без привязок он считается общим.'),
         IF(l.`lang_abbr` = 'ua', '<p>Крім банерних місць є другий механізм — HTML-врізка, задана розділу.</p>', '<p>Кроме баннерных мест есть второй механизм — HTML-врезка, заданная разделу и унаследованная его подразделами.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'webdev');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/nord-solid.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 21 DAY, 'karta-sajta', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'karta-sajta');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'karta-sajta');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Карта сайту для пошуковиків', 'Карта сайта для поисковиков'),
         IF(l.`lang_abbr` = 'ua', 'Сторінка карти створюється сама й містить лише ті розділи, які дозволено індексувати.', 'Страница карты создаётся сама и содержит только те разделы, которые разрешено индексировать.'),
         IF(l.`lang_abbr` = 'ua', '<p>Ознака індексації береться з налаштувань сторінки.</p>', '<p>Признак индексации берётся из настроек страницы: если в них указан запрет, адрес в карту не попадёт.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'energine');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/vektor-pro-15.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() - INTERVAL 12 DAY, 'podborki-na-glavnoj', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'podborki-na-glavnoj');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'podborki-na-glavnoj');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Добірки на головній', 'Подборки на главной'),
         IF(l.`lang_abbr` = 'ua', 'Групи добірок показуються вкладками, позиції всередині — каруселлю.', 'Группы подборок показываются вкладками, позиции внутри — каруселью.'),
         IF(l.`lang_abbr` = 'ua', '<p>Кожна позиція веде на товар або матеріал і має свій опис і зображення.</p>', '<p>Каждая позиция ведёт на товар или материал и имеет своё описание и картинку.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'energine,webdev');
INSERT INTO `apps_news_uploads` (`news_id`, `upl_id`)
  SELECT @n, u.`upl_id` FROM `share_uploads` u
   WHERE u.`upl_path` = 'uploads/public/demo/lumen-studio-15.jpg'
     AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`news_id` = @n AND x.`upl_id` = u.`upl_id`);

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 0, NOW() - INTERVAL 6 DAY, 'zametka-snyataya', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'zametka-snyataya');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'zametka-snyataya');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Чернетка: знято з публікації', 'Черновик: снят с публикации'),
         IF(l.`lang_abbr` = 'ua', 'Ця новина неактивна й відвідувачам не видна — її бачить лише редактор.', 'Эта новость неактивна и посетителям не видна — её видит только редактор.'),
         IF(l.`lang_abbr` = 'ua', '<p>Зняті з публікації матеріали зручно використовувати як чернетки.</p>', '<p>Снятые с публикации материалы удобно использовать как черновики.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'energine');

INSERT INTO `apps_news` (`smap_id`, `news_is_active`, `news_date`, `news_segment`, `news_show_image`, `news_is_top`)
  SELECT @news_smap, 1, NOW() + INTERVAL 4 DAY, 'anons-otlozhennyj', 1, 0 FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `apps_news` x WHERE x.`news_segment` = 'anons-otlozhennyj');
SET @n := (SELECT news_id FROM `apps_news` WHERE `news_segment` = 'anons-otlozhennyj');
INSERT INTO `apps_news_translation` (`news_id`, `lang_id`, `news_title`, `news_announce_rtf`, `news_text_rtf`)
  SELECT @n, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Анонс: вийде пізніше', 'Анонс: выйдет позже'),
         IF(l.`lang_abbr` = 'ua', 'У цієї новини дата в майбутньому: до її настання вона видна лише редакторові.', 'У этой новости дата в будущем: до её наступления она видна только редактору.'),
         IF(l.`lang_abbr` = 'ua', '<p>Так готують матеріали заздалегідь: публікація відбудеться сама.</p>', '<p>Так готовят материалы заранее: публикация произойдёт сама.</p>')
    FROM `share_languages` l ON DUPLICATE KEY UPDATE `news_title` = VALUES(`news_title`),
       `news_announce_rtf` = VALUES(`news_announce_rtf`), `news_text_rtf` = VALUES(`news_text_rtf`);
INSERT IGNORE INTO `apps_news_tags` (`news_id`, `tag_id`)
  SELECT @n, t.`tag_id` FROM `share_tags` t WHERE FIND_IN_SET(t.`tag_code`, 'releases');


-- ---------------------------------------------------------------------------
-- Права админских разделов.
-- В стартовом наборе часть страниц админки числилась доступной гостю и
-- обычному пользователю, хотя компоненты внутри требуют полных прав: страница
-- отвечала 404. Приводим дерево прав в соответствие с тем, что происходит.
-- ---------------------------------------------------------------------------
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);
SET @admin := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` = @root AND `smap_segment` = 'admin');

DELETE a FROM `share_access_level` a
  JOIN `share_sitemap` s ON s.`smap_id` = a.`smap_id`
 WHERE a.`group_id` <> 1
   AND (s.`smap_id` = @admin
        OR s.`smap_pid` = @admin
        OR s.`smap_pid` IN (SELECT x.`smap_id` FROM (SELECT `smap_id` FROM `share_sitemap` WHERE `smap_pid` = @admin) x));

-- ---------------------------------------------------------------------------
-- Порядок разделов верхнего уровня.
-- Страницы добавлялись в разное время, и номера у части из них совпадали:
-- порядок пунктов меню получался произвольным. Задаём его явно - сначала
-- содержательные разделы, затем личный кабинет, затем служебные страницы.
-- ---------------------------------------------------------------------------
SET @root := (SELECT smap_id FROM `share_sitemap` WHERE `smap_pid` IS NULL LIMIT 1);

UPDATE `share_sitemap` SET `smap_order_num` = CASE `smap_segment`
    WHEN 'news' THEN 10
    WHEN 'catalog' THEN 20
    WHEN 'blogs' THEN 30
    WHEN 'media' THEN 40
    WHEN 'features' THEN 50
    WHEN 'info' THEN 60
    WHEN 'test-feed' THEN 70
    WHEN 'form-example' THEN 80
    WHEN 'subscribe' THEN 90
    WHEN 'contacts' THEN 100
    WHEN 'register' THEN 110
    WHEN 'profile' THEN 120
    WHEN 'subscriptions' THEN 130
    WHEN 'my-orders' THEN 140
    WHEN 'sitemap' THEN 150
    WHEN 'admin' THEN 160
    WHEN 'login' THEN 200
    WHEN 'restore-password' THEN 210
    WHEN 'search' THEN 220
    WHEN 'cart' THEN 230
    WHEN 'wishlist' THEN 240
    WHEN 'google-sitemap' THEN 250
    WHEN 'robots.txt' THEN 260
    WHEN 'banners' THEN 270
    ELSE `smap_order_num` END
 WHERE `smap_pid` = @root;
