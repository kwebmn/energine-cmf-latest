-- Energine Simple, этап 2: из модуля apps остаются только новости и обратная связь.
-- Вырезаны врезки раздела, брендинг, подборки, опросы, общая лента проектов,
-- облако тегов, похожие новости и RSS.
--
-- Переходный скрипт. Применяется после sql/cut/stage1.sql, на свежей установке и на
-- базе этапа 1; повторный прогон на той же базе ничего не меняет. Правки демо-контента
-- рассчитаны на демо-базу. Сведение установки в один файл — этап 5.

SET SESSION group_concat_max_len = 65535;

-- 1. Колонка брендинга в дереве разделов вместе с внешним ключом.
ALTER TABLE `share_sitemap` DROP FOREIGN KEY IF EXISTS `share_sitemap_ibfk_11`;
ALTER TABLE `share_sitemap` DROP COLUMN IF EXISTS `brand_id`;

-- 2. Таблицы вырезанных частей apps. Список берётся из information_schema; внешние ключи
--    между ними отключаются только на время удаления.
SET @cut_tables := (
    SELECT GROUP_CONCAT(CONCAT('`', `TABLE_NAME`, '`') SEPARATOR ', ')
      FROM `information_schema`.`TABLES`
     WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_TYPE` = 'BASE TABLE'
       AND (`TABLE_NAME` IN ('apps_ads', 'apps_branding', 'apps_feed', 'apps_feed_tags', 'apps_feed_translation',
                             'apps_feed_uploads', 'test_feed')
            OR `TABLE_NAME` LIKE 'apps\_tops%' OR `TABLE_NAME` LIKE 'apps\_top\_groups%'
            OR `TABLE_NAME` LIKE 'apps\_vote%')
);
SET @sql := IF(@cut_tables IS NULL, 'DO 0', CONCAT('DROP TABLE IF EXISTS ', @cut_tables));
SET FOREIGN_KEY_CHECKS = 0;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET FOREIGN_KEY_CHECKS = 1;

-- 3. Страницы: лента проектов на сайте, опросы, подборки и оформление разделов в админке.
--    Родитель ищется от корня; поддеревья, переводы, права и тексты удаляются каскадом.
CREATE TEMPORARY TABLE `cut_pages` (`smap_id` INT UNSIGNED NOT NULL PRIMARY KEY);
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` root ON root.`smap_id` = s.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` = 'test-feed';
INSERT IGNORE INTO `cut_pages`
    SELECT s.`smap_id` FROM `share_sitemap` s
      JOIN `share_sitemap` p ON p.`smap_id` = s.`smap_pid` AND p.`smap_segment` = 'admin'
      JOIN `share_sitemap` root ON root.`smap_id` = p.`smap_pid` AND root.`smap_pid` IS NULL
     WHERE s.`smap_segment` IN ('polls', 'branding', 'tops', 'tops-groups');
DELETE s FROM `share_sitemap` s JOIN `cut_pages` c USING (`smap_id`);
DROP TEMPORARY TABLE `cut_pages`;

-- 4. Виджет «Опрос».
DELETE FROM `share_widgets` WHERE LOCATE('Energine\\apps\\components\\Vote"', `widget_xml`) > 0;

-- 5. Опрос на главной — отдельный контейнер-виджет в XML страницы.
UPDATE `share_sitemap`
   SET `smap_content_xml` = REPLACE(`smap_content_xml`,
       '<container name="VoteContainer5748" block="beta" widget="widget"><component class="Energine\\apps\\components\\Vote" name="Vote6093"><params><param name="title">TXT_VOTE</param></params></component></container>',
       '')
 WHERE LOCATE('Energine\\apps\\components\\Vote"', `smap_content_xml`) > 0;

-- 6. Демо-контент: путеводитель «Возможности» не описывает вырезанное и не ведёт
--    в удалённые разделы админки; новость о подборках уходит из ленты.
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'виджетов — опрос, текстовый блок.', 'виджетов — текстовый блок.')
 WHERE `tb_id` = 61 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '</a> — текстовые блоки, опрос, подборки</li>', '</a> — текстовые блоки</li>')
 WHERE `tb_id` = 61 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'віджетів — опитування, текстовий блок.', 'віджетів — текстовий блок.')
 WHERE `tb_id` = 61 AND `lang_id` = 2;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'теги и облако тегов, архив по датам и лента RSS.', 'теги, архив по датам.')
 WHERE `tb_id` = 62 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/news/rss/">Лента RSS</a></li>', '')
 WHERE `tb_id` = 62 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '</a> — облако тегов слева</li>', '</a></li>')
 WHERE `tb_id` = 62 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'теги й хмара тегів, архів за датами і стрічка RSS.', 'теги, архів за датами.')
 WHERE `tb_id` = 62 AND `lang_id` = 2;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/ua/news/rss/">Стрічка RSS</a></li>', '')
 WHERE `tb_id` = 62 AND `lang_id` = 2;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       'редактор сайтов и доменов, подборки и оформление разделов.', 'редактор сайтов и доменов.')
 WHERE `tb_id` = 73 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/admin/tops/">Подборки</a> и <a href="/admin/tops-groups/">их группы</a></li><li><a href="/admin/branding/">Оформление разделов</a></li>', '')
 WHERE `tb_id` = 73 AND `lang_id` = 1;
UPDATE `share_textblocks_translation` SET `tb_content` = REPLACE(`tb_content`,
       '<li><a href="/ua/admin/branding/">Оформлення розділів</a></li>', '')
 WHERE `tb_id` = 73 AND `lang_id` = 2;
DELETE FROM `apps_news` WHERE `news_segment` = 'podborki-na-glavnoj';

-- 7. Демо-файлы, на которые после вырезания никто не ссылается (картинки подборок).
--    Брендов в файловом репозитории нет — их файлы перечислены в stage2.files.
DELETE u FROM `share_uploads` u
 WHERE u.`upl_path` LIKE 'uploads/public/demo/%'
   AND NOT EXISTS (SELECT 1 FROM `share_sitemap_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `apps_news_uploads` x WHERE x.`upl_id` = u.`upl_id`)
   AND NOT EXISTS (SELECT 1 FROM `user_users` x WHERE x.`u_avatar_img` = u.`upl_path`)
   AND NOT EXISTS (SELECT 1 FROM `share_widgets` x WHERE x.`widget_icon_img` = u.`upl_path`);

-- 8. Переводы вырезанных частей apps: подписи их кода, названия шаблонов и компонентов,
--    поля их таблиц. Список собран tests/tools/cut-constants.php; оставшийся код эти имена
--    не использует и динамически не собирает. Переводы удаляются каскадом.
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (
    'BTN_ADD_ARTICLE', 'BTN_DELETE_ARTICLE', 'BTN_EDIT_ARTICLE', 'CONTENT_BRANDING_EDITOR',
    'CONTENT_EXTFEED', 'CONTENT_VOTE_REPOSITORY', 'FIELD_BRAND_BGCOLOR', 'FIELD_BRAND_CSS_RULE',
    'FIELD_BRAND_ID', 'FIELD_BRAND_LAYOUT_CCLASS', 'FIELD_BRAND_MAIN_IMG', 'FIELD_BRAND_MIN_HEIGHT',
    'FIELD_BRAND_NAME', 'FIELD_TF_ANNOTATION_RTF', 'FIELD_TF_DATE', 'FIELD_TF_NAME',
    'FIELD_TF_TEXT_RTF', 'FIELD_TG_ID', 'FIELD_TG_NAME', 'FIELD_TOP_ID', 'FIELD_TOP_IS_ACTIVE',
    'FIELD_TOP_LINK', 'FIELD_TOP_NAME', 'FIELD_TOP_TEXT_RTF', 'FIELD_VOTE_DATE', 'FIELD_VOTE_ID',
    'FIELD_VOTE_IS_ACTIVE', 'FIELD_VOTE_NAME', 'FIELD_VOTE_QUESTION_COUNTER',
    'FIELD_VOTE_QUESTION_ID', 'FIELD_VOTE_QUESTION_TITLE', 'TAB_ANSWERS', 'TAB_VOTE_QUESTIONS',
    'TXT_BEDITOR', 'TXT_READ_ALL_NEWS', 'TXT_RSS_NEWS_TITLE', 'TXT_SIMILAR_NEWS', 'TXT_VOTE',
    'TXT_VOTE_COUNT'
);
