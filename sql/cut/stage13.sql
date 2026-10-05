-- Energine Simple, удобство, этап 3 (docs/superpowers/plans/2026-10-05-energine-simple-c3-owner.md). Переход базы после
-- sql/cut/stage12.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage13.sql

-- 1. Страница админки «Битые ссылки» (/admin/links/): только администраторам, последней в меню админки. Номер строки
--    задан явно — как в файлах установки (fresh-check сверяет площадку с установкой).
INSERT INTO `share_sitemap` (`smap_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_in_menu`, `smap_order_num`)
    SELECT 3726, 'default.layout.xml', 'broken_links.content.xml', a.`smap_id`, 'links', 1,
           (SELECT IFNULL(MAX(c.`smap_order_num`), 0) + 1 FROM `share_sitemap` c WHERE c.`smap_pid` = a.`smap_id`)
      FROM `share_sitemap` a JOIN `share_sitemap` r ON r.`smap_id` = a.`smap_pid` AND r.`smap_pid` IS NULL
     WHERE a.`smap_segment` = 'admin'
       AND NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = a.`smap_id` AND x.`smap_segment` = 'links');
SET @links = (SELECT s.`smap_id` FROM `share_sitemap` s JOIN `share_sitemap` a ON a.`smap_id` = s.`smap_pid` AND a.`smap_segment` = 'admin'
              JOIN `share_sitemap` r ON r.`smap_id` = a.`smap_pid` AND r.`smap_pid` IS NULL WHERE s.`smap_segment` = 'links');
INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
    SELECT @links, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Биті посилання', 'Битые ссылки'), 0 FROM `share_languages` l;
-- права — как у журнала действий (только администраторы)
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
    SELECT @links, a.`group_id`, a.`right_id` FROM `share_access_level` a JOIN `share_sitemap` s USING (`smap_id`)
     WHERE s.`smap_segment` = 'action-log';

-- 2. Переводы страницы «Битые ссылки».
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_BROKEN_LINKS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Биті посилання', 'Битые ссылки')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'CONTENT_BROKEN_LINKS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_HINT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання в текстах сторінок, що ведуть на неіснуючі або вимкнені сторінки та відсутні файли. Зовнішні сайти не перевіряються. Виправте посилання в тексті сторінки в режимі редагування.', 'Ссылки в текстах страниц, которые ведут на несуществующие или отключённые страницы и отсутствующие файлы. Внешние сайты не проверяются. Исправьте ссылку в тексте страницы в режиме редактирования.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_HINT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NONE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Битих посилань немає', 'Битых ссылок нет')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NONE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_MEMBERS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання на сторінки лише для тих, хто увійшов (гостю не відкриються)', 'Ссылки на страницы только для вошедших (гостю не откроются)')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_MEMBERS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_PAGE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сторінка', 'Страница')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_PAGE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_LANG');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Мова', 'Язык')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_LANG';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_LINK');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання', 'Ссылка')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_LINK';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_REASON');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Причина', 'Причина')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_REASON';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NO_PAGE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Немає сторінки', 'Нет страницы')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NO_PAGE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NO_FILE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Немає файлу', 'Нет файла')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NO_FILE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_DISABLED');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сторінку вимкнено', 'Страница отключена')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_DISABLED';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_OUTSIDE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Поза сайтом', 'Вне сайта')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_OUTSIDE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_MEMBERS_ONLY');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Лише для тих, хто увійшов', 'Только для вошедших')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_MEMBERS_ONLY';
