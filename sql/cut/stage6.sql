-- Energine Simple, этап 6: мультисайт — одна установка, один сайт (docs/superpowers/specs/2026-09-26-energine-simple-design.md,
-- раздел 6). Переход базы сайта после sql/cut/stage5.sql; каждый раздел можно запускать повторно.
--   mariadb БАЗА < sql/cut/stage6.sql
-- Файлы установки (sql/structure.sql, data.sql, demo.sql) получаются из этого скрипта: tests/tools/regen-sql.sh.

-- 0. До любых изменений: в базе один сайт и одно дерево разделов. Иначе — отказ, база не тронута.
DELIMITER //
BEGIN NOT ATOMIC
    IF (SELECT COUNT(*) FROM `share_sites`) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stage6.sql: в базе не один сайт. Оставьте один (разделы — под его корень) и запустите снова.';
    END IF;
    IF (SELECT COUNT(*) FROM `share_sitemap` WHERE `smap_pid` IS NULL) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stage6.sql: в дереве разделов не один корень. Оставьте один и запустите снова.';
    END IF;
END //
DELIMITER ;

-- 1. Адрес сайта — из конфига (site.domain, site.root): записи доменов не читаются и не пишутся.
DELETE FROM `share_domain2site`;
DELETE FROM `share_domains`;

-- 2. «Настройки сайта» (admin/settings/) вместо редактора сайтов и доменов (admin/structure/sites/): та же страница
--    переезжает в корень админки, её права остаются. Сайт не добавляется и не удаляется — константы редактора сайтов,
--    доменов, копирования структуры и сброса шаблонов всего сайта удаляются.
SET @admin := (SELECT a.`smap_id` FROM `share_sitemap` a JOIN `share_sitemap` r ON a.`smap_pid` = r.`smap_id`
                WHERE r.`smap_pid` IS NULL AND a.`smap_segment` = 'admin');
UPDATE `share_sitemap`
   SET `smap_pid` = @admin, `smap_segment` = 'settings', `smap_content` = 'main/site_settings.content.xml', `smap_order_num` = 3
 WHERE `smap_content` = 'main/sites.content.xml' AND @admin IS NOT NULL;
UPDATE `share_sitemap_translation` t JOIN `share_sitemap` s USING (`smap_id`) JOIN `share_languages` l USING (`lang_id`)
   SET t.`smap_name` = IF(l.`lang_abbr` = 'ua', 'Налаштування сайту', 'Настройки сайта')
 WHERE s.`smap_content` = 'main/site_settings.content.xml';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES
    ('BTN_SITE_SETTINGS'), ('CONTENT_SITE_SETTINGS'), ('TAB_SITE_PROPERTIES'), ('ERR_BAD_PROPERTY_NAME');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'TAB_SITE_PROPERTIES' THEN IF(l.`lang_abbr` = 'ua', 'Додаткові параметри', 'Дополнительные параметры')
               WHEN 'ERR_BAD_PROPERTY_NAME' THEN IF(l.`lang_abbr` = 'ua',
                   'Ім’я параметра — латинські літери, цифри, крапка та підкреслення',
                   'Имя параметра — латинские буквы, цифры, точка и подчёркивание')
               ELSE IF(l.`lang_abbr` = 'ua', 'Налаштування сайту', 'Настройки сайта')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('BTN_SITE_SETTINGS', 'CONTENT_SITE_SETTINGS', 'TAB_SITE_PROPERTIES', 'ERR_BAD_PROPERTY_NAME');
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN ('BTN_SITE_EDITOR', 'CONTENT_SITES', 'TAB_DOMAINS', 'TXT_DOMAINEDITOR',
    'FIELD_DOMAIN_ID', 'FIELD_DOMAIN_URL', 'FIELD_DOMAIN_PROTOCOL', 'FIELD_DOMAIN_PORT', 'FIELD_DOMAIN_HOST', 'FIELD_DOMAIN_ROOT',
    'FIELD_SITE_PROTOCOL', 'FIELD_SITE_HOST', 'FIELD_SITE_ROOT', 'FIELD_SITE_PORT', 'FIELD_COPY_SITE_STRUCTURE', 'TXT_SITELIST',
    'FIELD_SITE_LOGO', 'FIELD_SITE_GA_CODE', 'BTN_RESET_TEMPLATES', 'MSG_CONFIRM_TEMPLATES_RESET', 'MSG_TEMPLATES_RESET',
    'BTN_PROPERTIES');
