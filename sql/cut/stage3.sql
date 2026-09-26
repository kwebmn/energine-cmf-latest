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

-- 4. Теги: таблицы (список из information_schema; внешние ключи между ними отключаются только
--    на время удаления) и упоминание в путеводителе «Возможности».
SET @cut_tables := (
    SELECT GROUP_CONCAT(CONCAT('`', `TABLE_NAME`, '`') SEPARATOR ', ')
      FROM `information_schema`.`TABLES`
     WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_TYPE` = 'BASE TABLE'
       AND `TABLE_NAME` IN ('share_tags', 'share_tags_translation', 'share_sitemap_tags', 'share_sites_tags',
                            'share_uploads_tags', 'apps_news_tags')
);
SET @sql := IF(@cut_tables IS NULL, 'DO 0', CONCAT('DROP TABLE IF EXISTS ', @cut_tables));
SET FOREIGN_KEY_CHECKS = 0;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'вложения, теги, архив по датам.', 'вложения, архив по датам.')
 WHERE `tb_id` = 62 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'вкладення, теги, архів за датами.', 'вкладення, архів за датами.')
 WHERE `tb_id` = 62 AND `lang_id` = 2;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/news/tag/13/">Новости по тегу</a></li>', '')
 WHERE `tb_id` = 62 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/ua/news/tag/13/">Новини за тегом</a></li>', '')
 WHERE `tb_id` = 62 AND `lang_id` = 2;

-- 5. Виджеты и редактор блоков: таблица, раздел админки (родитель ищется от корня), атрибуты
--    редактора блоков в XML страниц (widget="widget|static", column="column" — выражением,
--    а не точной строкой), путеводитель «Структура и тексты».
DROP TABLE IF EXISTS `share_widgets`;
CREATE TEMPORARY TABLE `cut_pages` (`smap_id` INT UNSIGNED NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` p ON p.`smap_id` = s.`smap_pid` AND p.`smap_segment` = 'admin'
      JOIN `share_sitemap` root ON root.`smap_id` = p.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` = 'widgets';
DELETE s FROM `share_sitemap` s JOIN `cut_pages` c USING (`smap_id`);
DROP TEMPORARY TABLE `cut_pages`;
UPDATE `share_sitemap`
   SET `smap_content_xml` = REGEXP_REPLACE(`smap_content_xml`, ' (widget|column)="[a-z]+"', ''),
       `smap_layout_xml` = REGEXP_REPLACE(`smap_layout_xml`, ' (widget|column)="[a-z]+"', '')
 WHERE CONCAT_WS(' ', `smap_content_xml`, `smap_layout_xml`) REGEXP ' (widget|column)="';
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<p>Блоки можно перетаскивать между колонками и добавлять из набора виджетов — текстовый блок.</p>', '')
 WHERE `tb_id` = 61 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<p>Блоки можна перетягувати між колонками й додавати з набору віджетів — текстовий блок.</p>', '')
 WHERE `tb_id` = 61 AND `lang_id` = 2;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/admin/widgets/">Виджеты</a></li>', '')
 WHERE `tb_id` = 61 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/ua/admin/widgets/">Віджети</a></li>', '')
 WHERE `tb_id` = 61 AND `lang_id` = 2;

-- 6. Нелокальные хранилища файлов (FTP, FTP только для чтения, только для чтения) вместе с
--    содержимым (upl_pid удаляется каскадом) и пункт о них в «Инструкции по установке». В
--    украинской версии текста внутри пункта переводы строк, поэтому пункт заменяется выражением.
DELETE FROM `share_uploads` WHERE `upl_mime_type` IN ('repo/ftp', 'repo/ftpro', 'repo/ro');
UPDATE `share_textblocks_translation`
   SET `tb_content` = REGEXP_REPLACE(`tb_content`, '<li>Управление файлами\\.[^<]*FTP[^<]*</li>',
       '<li>Управление файлами. Файлы хранятся в репозитории на сервере сайта и используются в текстах страниц, новостях и галерее раздела.</li>')
 WHERE `tb_id` = 59 AND `tb_content` LIKE '%FTP%';

-- 7. Видео: флаги форматов, длительность и готовность (перекодировка) и счётчик просмотров
--    upl_views, который нигде не используется. Индекс abc (upl_id, upl_is_ready, upl_views) без
--    этих колонок повторял бы первичный ключ. Видеофайлы становятся обычными файлами; фраза о
--    перекодировке уходит из путеводителя «Файлы и медиа».
UPDATE `share_uploads` SET `upl_internal_type` = 'unknown' WHERE `upl_internal_type` = 'video';
ALTER TABLE `share_uploads` DROP INDEX IF EXISTS `abc`;
ALTER TABLE `share_uploads`
    DROP COLUMN IF EXISTS `upl_is_mp4`, DROP COLUMN IF EXISTS `upl_is_webm`, DROP COLUMN IF EXISTS `upl_is_flv`,
    DROP COLUMN IF EXISTS `upl_duration`, DROP COLUMN IF EXISTS `upl_is_ready`, DROP COLUMN IF EXISTS `upl_views`;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<p>Перекодировка видео требует ffmpeg, на этом хосте он не установлен.</p>', '')
 WHERE `tb_id` = 69 AND `lang_id` = 1;

-- 8. Колонки, на которые код не ссылается: вход через соцсети удалён раньше (u_fbid, u_vkid),
--    компания и должность пользователя нигде не выводятся, news_show_image ничего не
--    переключает, флажок news_is_top только ставил тег top, который никто не читал (главная
--    выводит последние новости). Индексы этих колонок удаляются вместе с ними.
ALTER TABLE `user_users`
    DROP COLUMN IF EXISTS `u_fbid`, DROP COLUMN IF EXISTS `u_vkid`,
    DROP COLUMN IF EXISTS `u_company`, DROP COLUMN IF EXISTS `u_position`;
ALTER TABLE `apps_news` DROP COLUMN IF EXISTS `news_show_image`, DROP COLUMN IF EXISTS `news_is_top`;

-- 9. Переводы вырезанного на этапе 3: подписи его кода, названия шаблонов и компонентов, поля
--    вырезанных таблиц и колонок (список tests/tools/cut-constants.php — удалённые файлы и
--    удалённые строки изменённых), а также строки тегов, видео и Flash, которых не было ни в
--    каком коде этой системы (поиск по именам в справочнике). Переводы удаляются каскадом.
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (
    'BTN_APPLY', 'BTN_EDIT_BLOCKS', 'BTN_EXT_FLASH', 'BTN_INSERT_VIDEO', 'BTN_INSERT_WIDGET',
    'CONTENT_TAG_EDITOR', 'CONTENT_VIDEO', 'CONTENT_VIDEO_LIBRARY', 'CONTENT_WIDGETS_REPOSITORY',
    'ERR_BAD_DATA', 'ERR_BAD_PREPARE_FUNCTION', 'ERR_BAD_XML', 'ERR_BAD_XML_DESCR',
    'ERR_MISSING_ALTS_FTP_CONFIG', 'ERR_MISSING_MEDIA_FTP_CONFIG', 'ERR_READ_ONLY_FTP_REPO',
    'ERR_UPL_NOT_READY', 'FIELD_CONTENT_FILE_TITLE', 'FIELD_NEWS_IS_TOP', 'FIELD_NEWS_SHOW_IMAGE',
    'FIELD_TAGS', 'FIELD_TAG_CODE', 'FIELD_TAG_ID', 'FIELD_TAG_NAME', 'FIELD_UPL_DURATION',
    'FIELD_UPL_IS_FLV', 'FIELD_UPL_IS_MP4', 'FIELD_UPL_IS_READY', 'FIELD_UPL_IS_WEBM',
    'FIELD_UPL_VIEWS', 'FIELD_U_COMPANY', 'FIELD_U_FBID', 'FIELD_U_POSITION', 'FIELD_U_VKID',
    'FIELD_WIDGET_ICON_IMG', 'FIELD_WIDGET_ID', 'FIELD_WIDGET_NAME', 'FIELD_WIDGET_XML',
    'TXT_ABOUT_VIDEO', 'TXT_ACTION_SELECTOR', 'TXT_ERROR_NOT_VIDEO_FILE', 'TXT_LOOKUPEDITOR',
    'TXT_NEWS_BY_TAG', 'TXT_NEW_VIDEO', 'TXT_NOT_READY', 'TXT_POPULAR_VIDEO', 'TXT_RELATED_VIDEO',
    'TXT_REVERT_CONTENT', 'TXT_SAVE_CONTENT', 'TXT_SAVE_TO_CURRENT_CONTENT',
    'TXT_SAVE_TO_NEW_CONTENT', 'TXT_TOP_VIDEO', 'TXT_VIDEO', 'TXT_VIDEOS', 'TXT_VIDEO_LIBRARY',
    'TXT_VIEW_VIDEO', 'TXT_WATCH_ALL_VIDEO', 'TXT_WIDGETEDITOR', 'TXT_WIDGETSREPOSITORY'
);
