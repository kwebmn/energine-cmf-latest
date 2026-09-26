-- Energine Simple, этап 3: из share уходят теги, виджеты и редактор блоков, нелокальные
-- хранилища файлов, водяные знаки, видео и Flash, выбор записей из справочника (Lookup),
-- колонки, на которые код не ссылается. Меню сайта строится по флагу страницы.
--
-- Переходный скрипт. Применяется после sql/cut/stage2.sql, на свежей установке и на базе
-- этапа 2; повторный прогон на той же базе ничего не меняет. Правки демо-контента
-- рассчитаны на демо-базу. Сведение установки в один файл — этап 5.

SET SESSION group_concat_max_len = 65535;

-- 1. Флаг «Показывать в меню» вместо тега menu. Новая страница по умолчанию в меню — как раньше,
--    когда форма раздела подставляла тег. Перенос: флаг снимается у страниц без тега menu;
--    только пока таблицы тегов есть, поэтому повторный прогон ничего не меняет.
ALTER TABLE `share_sitemap` ADD COLUMN IF NOT EXISTS `smap_in_menu` TINYINT(1) NOT NULL DEFAULT 1 AFTER `smap_segment`;
SET @sql := IF((SELECT COUNT(*) FROM `information_schema`.`TABLES`
                 WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` IN ('share_tags', 'share_sitemap_tags')) = 2,
    'UPDATE `share_sitemap` s SET s.`smap_in_menu` = 0 WHERE NOT EXISTS (
         SELECT 1 FROM `share_sitemap_tags` st JOIN `share_tags` t USING (`tag_id`)
          WHERE st.`smap_id` = s.`smap_id` AND t.`tag_code` = ''menu'')',
    'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2. XML страниц: меню с параметром tags=menu получает menu=1.
UPDATE `share_sitemap`
   SET `smap_content_xml` = REPLACE(`smap_content_xml`, '<param name="tags">menu</param>', '<param name="menu">1</param>'),
       `smap_layout_xml` = REPLACE(`smap_layout_xml`, '<param name="tags">menu</param>', '<param name="menu">1</param>')
 WHERE LOCATE('<param name="tags">menu</param>', CONCAT_WS(' ', `smap_content_xml`, `smap_layout_xml`)) > 0;

-- 3. Подпись флага в форме раздела.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('FIELD_SMAP_IN_MENU');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Показувати в меню', 'Показывать в меню')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'FIELD_SMAP_IN_MENU';
