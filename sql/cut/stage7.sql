-- Energine Simple, этап 7: чистое ядро (docs/superpowers/specs/2026-10-01-energine-simple-stage7-core-design.md, раздел 5).
-- Переход базы сайта после sql/cut/stage6.sql; повторный прогон ничего не меняет.
--   mariadb БАЗА < sql/cut/stage7.sql
-- Файлы установки (sql/structure.sql, data.sql, demo.sql) получаются из этого скрипта: tests/tools/regen-sql.sh.
-- Внешние ключи share_sitemap, mail_templates и share_lang_tags — ON DELETE CASCADE: вместе со строкой уходят
-- подразделы, переводы, права, текстовые блоки.
-- Разделы, которые переход меняет, он перечисляет в выводе: проверьте их страницы.
SET NAMES utf8mb4;

-- 1. Модуль apps: новости и обратная связь.
-- Разделы админки новостей и обратной связи (feedback_list.content.xml — только у админки) удаляются.
DELETE FROM `share_sitemap` WHERE `smap_content` IN ('main/news_repository.content.xml', 'news_repository.content.xml',
  'main/news_categories_editor.content.xml', 'feedback_list.content.xml', 'main/feedback_recipients_editor.content.xml');

-- Разделы сайта на шаблонах новостей и обратной связи — текстовые страницы (их тексты остаются).
SELECT CONCAT('этап 7: раздел ', `smap_id`, ' (', `smap_segment`, ') переведён на textblock.content.xml') AS `переход`
  FROM `share_sitemap`
  WHERE `smap_content` IN ('news.content.xml', 'feedback_form.content.xml');
UPDATE `share_sitemap` SET `smap_content` = 'textblock.content.xml', `smap_content_xml` = NULL
  WHERE `smap_content` IN ('news.content.xml', 'feedback_form.content.xml');

-- Почтовые шаблоны обратной связи (переводы — каскадом).
DELETE FROM `mail_templates` WHERE `template_sysname` IN ('feedback_form', 'feedback_form_admin');

-- Строки переводов, которые использовали только новости и обратная связь (переводы — каскадом).
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN ('BTN_ADD_NEWS', 'BTN_DELETE_NEWS', 'BTN_EDIT_NEWS',
  'BTN_GOTONEWS', 'BTN_PUBLISH', 'BTN_RETURN_LIST', 'BTN_UNPUBLISH', 'CONTENT_FEEDBACK_FORM', 'CONTENT_FEEDBACK_LIST',
  'CONTENT_FEEDBACK_RECIPIENTS_EDITOR', 'CONTENT_NEWS', 'CONTENT_NEWS_CATEGORIES_EDITOR', 'CONTENT_NEWS_REPOSITORY',
  'CONTENT_PROJECT_NEWS', 'FEEDBACK_MAIL_AUTHOR', 'FEEDBACK_MAIL_EMAIL', 'FEEDBACK_MAIL_PHONE', 'FEEDBACK_MAIL_TEXT',
  'FEEDBACK_MAIL_THEME', 'FIELD_FEED_AUTHOR', 'FIELD_FEED_DATE', 'FIELD_FEED_EMAIL', 'FIELD_FEED_ID',
  'FIELD_FEED_PHONE', 'FIELD_FEED_TEXT', 'FIELD_FEED_THEME', 'FIELD_FEED_TOPIC', 'FIELD_FEED_TYPE',
  'FIELD_FEED_TYPE_EMAIL', 'FIELD_FEED_TYPE_NAME', 'FIELD_NEWS_ADDITIONAL_TITLE', 'FIELD_NEWS_ANNOUNCE_RTF',
  'FIELD_NEWS_CATEGORIES', 'FIELD_NEWS_DATE', 'FIELD_NEWS_FOOTER_RTF', 'FIELD_NEWS_ID', 'FIELD_NEWS_IS_ACTIVE',
  'FIELD_NEWS_IS_DISABLED', 'FIELD_NEWS_MAIN', 'FIELD_NEWS_PUBLISH_DATE', 'FIELD_NEWS_SEGMENT', 'FIELD_NEWS_SOURCE',
  'FIELD_NEWS_TEXT_RTF', 'FIELD_NEWS_TITLE', 'FIELD_NEWS_TOP', 'FIELD_RCP_ID', 'FIELD_RCP_NAME',
  'FIELD_RCP_RECIPIENTS', 'FIELD_VFEED_DATE', 'FIELD_VFEED_EMAIL', 'FIELD_VFEED_FILE', 'FIELD_VFEED_NAME',
  'FIELD_VFEED_PHONE', 'FIELD_VFEED_TEXT', 'TXT_ALL_NEWS', 'TXT_ALL_NEWS_CATEGORIES', 'TXT_BACK_TO_LIST',
  'TXT_BODY_FEEDBACK_USER', 'TXT_CAT_NEWS_ALL', 'TXT_DAY_MAIN_NEWS', 'TXT_FEED', 'TXT_FEEDBACKARTISTSEDITOR',
  'TXT_FEEDBACKCOMMONLIST', 'TXT_FEEDBACK_FORM', 'TXT_FEEDBACK_FROM_AUTHOR', 'TXT_FEEDBACK_FROM_EMAIL',
  'TXT_FEEDBACK_FROM_PHONE', 'TXT_FEEDBACK_FROM_TEXT', 'TXT_FEEDBACKLIST', 'TXT_FEEDBACK_SUCCESS_SEND',
  'TXT_FIND_NEWS', 'TXT_MAIN_NEWS', 'TXT_MORE_PARTNER_NEWS', 'TXT_NEWS_BY_CATEGORY', 'TXT_NEWS_BY_DATE',
  'TXT_NEWS_SUBSCRIBE_TO', 'TXT_NO_EMAIL_ENTERED', 'TXT_PARTNER_NEWS', 'TXT_PROJECT_NEWS', 'TXT_READ_MORE',
  'TXT_SHORT_NEWS', 'TXT_SUBJ_FEEDBACK_ADMIN', 'TXT_SUBJ_FEEDBACK_COMMON', 'TXT_SUBJ_FEEDBACK_USER', 'TXT_TOP_NEWS',
  'TXT_TOPNEWS', 'TXT_VACANCIESFEEDBACKLIST');

DROP TABLE IF EXISTS `apps_news_uploads`, `apps_news_translation`, `apps_news`,
  `apps_feedback`, `apps_feedback_recipient_translation`, `apps_feedback_recipient`;

-- 2. Галерея и вложения разделов.
-- Разделы на шаблоне галереи — текстовые страницы (их тексты остаются). У шаблона галереи был второй текстовый блок
-- (num 2), у текстовой страницы — только первый: такие разделы названы отдельно.
SELECT CONCAT('этап 7: у раздела ', s.`smap_id`, ' (', s.`smap_segment`, ') второй текстовый блок больше не показывается — ',
    'перенесите его текст в первый') AS `переход`
  FROM `share_sitemap` s JOIN `share_textblocks` t ON t.`smap_id` = s.`smap_id` AND t.`tb_num` = '2'
  WHERE s.`smap_content` = 'media_textblock.content.xml';
SELECT CONCAT('этап 7: раздел ', `smap_id`, ' (', `smap_segment`, ') переведён на textblock.content.xml') AS `переход`
  FROM `share_sitemap`
  WHERE `smap_content` = 'media_textblock.content.xml';
UPDATE `share_sitemap` SET `smap_content` = 'textblock.content.xml', `smap_content_xml` = NULL
  WHERE `smap_content` = 'media_textblock.content.xml';

-- Строки переводов, которые использовали только галерея и вложения (переводы — каскадом).
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN ('BTN_ADD_GALLERY', 'BTN_MOVE_CANCEL', 'CONTENT_GALLERY',
  'CONTENT_MEDIA_TEXTBLOCK', 'FIELD_ATTACHEDFILES', 'FIELD_ATTACHMENTS', 'FIELD_IMG_FILENAME_IMG',
  'MSG_EMPTY_GALLERY', 'MSG_NO_ATTACHED_FILES', 'TAB_ATTACHED_FILES', 'TXT_ATTACHMENTEDITOR', 'TXT_GALLERY');

-- Вложения разделов (файлы остаются в репозитории).
DROP TABLE IF EXISTS `share_sitemap_uploads`;

-- 3. Мёртвый код ядра и свой XML разделов.
-- Шаблоны, удалённые с мёртвым кодом ядра: default.content.xml повторял main.content.xml, new.layout.xml —
-- default.layout.xml.
UPDATE `share_sitemap` SET `smap_content` = 'main.content.xml' WHERE `smap_content` = 'default.content.xml';
UPDATE `share_sitemap` SET `smap_layout` = 'default.layout.xml' WHERE `smap_layout` = 'new.layout.xml';

-- Компоненты, удалённые на этапе 7: модуль apps целиком и из share — галерея (PageMedia), вложения (AttachmentEditor),
-- выбор раздела для новостей (LinkingEditor), мёртвый код (PageInfo, Remover, SiteProperties, TextBlockSource).
-- Раздел со своим XML, где назван один из них, — текстовая страница (его тексты остаются); своя раскладка с ним
-- сбрасывается на шаблон раздела. Граница слова после имени: живые SitePropertiesEditor и т. п. не задеваются.
SET @stage7_removed = 'apps\\\\components\\\\|\\\\(PageMedia|AttachmentEditor|LinkingEditor|PageInfo|Remover|SiteProperties|TextBlockSource)\\b';
SELECT CONCAT('этап 7: раздел ', `smap_id`, ' (', `smap_segment`, ') переведён на textblock.content.xml') AS `переход`
  FROM `share_sitemap`
  WHERE `smap_content_xml` REGEXP @stage7_removed;
SELECT CONCAT('этап 7: у раздела ', `smap_id`, ' (', `smap_segment`, ') своя раскладка сброшена на шаблон ', `smap_layout`) AS `переход`
  FROM `share_sitemap`
  WHERE `smap_layout_xml` REGEXP @stage7_removed;
UPDATE `share_sitemap` SET `smap_content` = 'textblock.content.xml', `smap_content_xml` = NULL
  WHERE `smap_content_xml` REGEXP @stage7_removed;
UPDATE `share_sitemap` SET `smap_layout_xml` = NULL WHERE `smap_layout_xml` REGEXP @stage7_removed;
