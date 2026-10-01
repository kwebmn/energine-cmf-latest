-- Energine Simple: схема базы — 21 таблица и хранимые процедуры. Ставится в пустую базу установщиком:
-- php web/index.php setup install (docs/INSTALL.md). Получена из установки полной системы и sql/cut/stage1–7.sql.

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `mail_templates` (
  `template_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `template_sysname` varchar(100) NOT NULL,
  `template_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `template_hints` text DEFAULT NULL,
  PRIMARY KEY (`template_id`),
  UNIQUE KEY `template_sysname` (`template_sysname`),
  KEY `template_is_active` (`template_is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `mail_templates_translation` (
  `template_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `template_name` varchar(255) NOT NULL,
  `template_subject` varchar(255) DEFAULT NULL,
  `template_body` text DEFAULT NULL,
  `template_body_rtf` mediumtext DEFAULT NULL,
  PRIMARY KEY (`template_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `mail_templates_translation_ibfk_1` FOREIGN KEY (`template_id`) REFERENCES `mail_templates` (`template_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_templates_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_access_level` (
  `smap_id` int(10) unsigned NOT NULL,
  `group_id` int(10) unsigned NOT NULL,
  `right_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`smap_id`,`group_id`,`right_id`),
  KEY `group_id` (`group_id`),
  KEY `right_id` (`right_id`),
  CONSTRAINT `share_access_level_ibfk_4` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_access_level_ibfk_5` FOREIGN KEY (`group_id`) REFERENCES `user_groups` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_access_level_ibfk_6` FOREIGN KEY (`right_id`) REFERENCES `user_group_rights` (`right_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_action_log` (
  `al_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `al_date` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `u_id` int(10) unsigned DEFAULT NULL,
  `al_classname` varchar(100) DEFAULT NULL,
  `al_objectname` varchar(100) DEFAULT NULL,
  `al_action` char(20) DEFAULT NULL,
  `al_data` mediumtext DEFAULT NULL,
  PRIMARY KEY (`al_id`),
  KEY `share_action_log_uid` (`u_id`),
  CONSTRAINT `share_action_log_uid` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_lang_tags` (
  `ltag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ltag_name` varchar(70) NOT NULL,
  PRIMARY KEY (`ltag_id`),
  UNIQUE KEY `ltag_name` (`ltag_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_lang_tags_translation` (
  `ltag_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `ltag_value_rtf` text NOT NULL,
  PRIMARY KEY (`ltag_id`,`lang_id`),
  KEY `FK_tranaslatelv_language` (`lang_id`),
  CONSTRAINT `FK_Reference_6` FOREIGN KEY (`ltag_id`) REFERENCES `share_lang_tags` (`ltag_id`) ON DELETE CASCADE,
  CONSTRAINT `FK_tranaslatelv_language` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_languages` (
  `lang_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `lang_locale` char(30) DEFAULT NULL,
  `lang_abbr` char(2) NOT NULL,
  `lang_name` char(20) NOT NULL,
  `lang_default` tinyint(1) NOT NULL DEFAULT 0,
  `lang_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`lang_id`),
  KEY `idx_abbr` (`lang_abbr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_session` (
  `session_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `session_native_id` char(40) NOT NULL,
  `session_last_impression` int(11) NOT NULL,
  `session_created` int(11) NOT NULL,
  `session_expires` int(11) NOT NULL,
  `session_ip` int(11) unsigned DEFAULT NULL,
  `session_user_agent` char(255) DEFAULT NULL,
  `u_id` int(10) unsigned DEFAULT NULL,
  `session_data` varchar(5000) DEFAULT NULL,
  PRIMARY KEY (`session_id`),
  UNIQUE KEY `session_native_id` (`session_native_id`),
  KEY `i_session_u_id` (`u_id`),
  KEY `i_session_ip` (`session_ip`),
  KEY `session_expires` (`session_expires`)
) ENGINE=MEMORY DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_sitemap` (
  `smap_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `smap_last_mod` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `smap_layout` char(200) NOT NULL,
  `smap_layout_xml` text DEFAULT NULL,
  `smap_content` char(200) NOT NULL,
  `smap_content_xml` text DEFAULT NULL,
  `smap_pid` int(10) unsigned DEFAULT NULL,
  `smap_segment` char(50) NOT NULL,
  `smap_in_menu` tinyint(1) NOT NULL DEFAULT 1,
  `smap_order_num` int(10) unsigned DEFAULT 1,
  `smap_redirect_url` char(250) DEFAULT NULL,
  `smap_meta_robots` set('NOINDEX','NOFOLLOW','NOARCHIVE','NOSNIPPET','NOODP') DEFAULT NULL,
  PRIMARY KEY (`smap_id`),
  UNIQUE KEY `smap_pid_segment` (`smap_pid`,`smap_segment`),
  KEY `smap_order_num` (`smap_order_num`),
  CONSTRAINT `share_sitemap_ibfk_8` FOREIGN KEY (`smap_pid`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_sitemap_translation` (
  `smap_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `smap_name` varchar(200) DEFAULT NULL,
  `smap_title` varchar(250) DEFAULT NULL,
  `smap_description_rtf` text DEFAULT NULL,
  `smap_html_title` varchar(250) DEFAULT NULL,
  `smap_meta_keywords` text DEFAULT NULL,
  `smap_meta_description` text DEFAULT NULL,
  `smap_is_disabled` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`lang_id`,`smap_id`),
  KEY `sitemaplv_sitemap_FK` (`smap_id`),
  CONSTRAINT `share_sitemap_translation_ibfk_1` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_sitemap_translation_ibfk_2` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_sites` (
  `site_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `site_meta_robots` set('NOINDEX','NOFOLLOW','NOARCHIVE','NOSNIPPET','NOODP') DEFAULT NULL,
  PRIMARY KEY (`site_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_sites_properties` (
  `prop_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `prop_name` varchar(255) NOT NULL,
  `prop_value` text NOT NULL,
  PRIMARY KEY (`prop_id`),
  UNIQUE KEY `prop_name` (`prop_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_sites_translation` (
  `site_id` int(11) unsigned NOT NULL,
  `lang_id` int(11) unsigned NOT NULL,
  `site_name` char(200) NOT NULL,
  `site_meta_keywords` text DEFAULT NULL,
  `site_meta_description` text DEFAULT NULL,
  PRIMARY KEY (`site_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `share_sites_translation_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_sites_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_textblocks` (
  `tb_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `smap_id` int(10) unsigned DEFAULT NULL,
  `tb_num` char(50) NOT NULL DEFAULT '1',
  PRIMARY KEY (`tb_id`),
  UNIQUE KEY `smap_id` (`smap_id`,`tb_num`),
  CONSTRAINT `share_textblocks_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_textblocks_translation` (
  `tb_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `tb_content` text NOT NULL,
  UNIQUE KEY `tb_id` (`tb_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `share_textblocks_translation_ibfk_1` FOREIGN KEY (`tb_id`) REFERENCES `share_textblocks` (`tb_id`) ON DELETE CASCADE,
  CONSTRAINT `share_textblocks_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `share_uploads` (
  `upl_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `upl_pid` int(10) unsigned DEFAULT NULL COMMENT 'родительский идентификатор',
  `upl_childs_count` int(10) unsigned DEFAULT NULL COMMENT 'количество наследников, 0 - могут быть[но сейчас нет, пустая папка ], NULL - не может быть вообще',
  `upl_path` varchar(250) NOT NULL COMMENT 'уникальный полный путь к файлу',
  `upl_filename` varchar(255) NOT NULL COMMENT 'реальное имя файла',
  `upl_name` varchar(250) NOT NULL COMMENT 'имя файла с расширением, с этим именем файл отдается при скачивании',
  `upl_title` varchar(250) NOT NULL DEFAULT '' COMMENT 'то как файл выводится в репозитории и в alt-ах',
  `upl_description` text DEFAULT NULL,
  `upl_publication_date` datetime DEFAULT NULL,
  `upl_data` text DEFAULT NULL,
  `upl_internal_type` char(20) DEFAULT NULL,
  `upl_mime_type` char(50) DEFAULT NULL,
  `upl_width` int(10) unsigned DEFAULT NULL,
  `upl_height` int(10) unsigned DEFAULT NULL,
  `upl_is_active` int(10) unsigned DEFAULT 1,
  PRIMARY KEY (`upl_id`),
  UNIQUE KEY `upl_path` (`upl_path`),
  KEY `upl_publication_date_index` (`upl_publication_date`),
  KEY `upl_pid` (`upl_pid`),
  KEY `upl_childs_count` (`upl_childs_count`),
  KEY `upl_filename` (`upl_filename`),
  KEY `upl_is_active` (`upl_is_active`),
  CONSTRAINT `share_uploads_ibfk_1` FOREIGN KEY (`upl_pid`) REFERENCES `share_uploads` (`upl_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_group_rights` (
  `right_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `right_name` char(20) NOT NULL,
  `right_const` char(20) NOT NULL,
  PRIMARY KEY (`right_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_groups` (
  `group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_name` char(100) NOT NULL DEFAULT '',
  `group_default` tinyint(1) NOT NULL DEFAULT 0,
  `group_user_default` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`group_id`),
  KEY `group_default` (`group_default`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_login_attempts` (
  `la_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `la_ip` varchar(45) NOT NULL,
  `la_login` varchar(250) NOT NULL,
  `la_date` int(10) unsigned NOT NULL,
  PRIMARY KEY (`la_id`),
  KEY `idx_login_date` (`la_login`,`la_date`),
  KEY `idx_ip_date` (`la_ip`,`la_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_user_groups` (
  `u_id` int(10) unsigned NOT NULL,
  `group_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`u_id`,`group_id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `user_user_groups_ibfk_3` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `user_user_groups_ibfk_4` FOREIGN KEY (`group_id`) REFERENCES `user_groups` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_users` (
  `u_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `u_name` varchar(50) NOT NULL,
  `u_phone` varchar(100) DEFAULT NULL,
  `u_password` varchar(255) NOT NULL,
  `u_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `u_fullname` varchar(250) NOT NULL,
  `u_country` varchar(255) DEFAULT NULL,
  `u_city` varchar(255) DEFAULT NULL,
  `u_avatar_img` varchar(1000) DEFAULT NULL,
  `u_person_name` varchar(100) DEFAULT NULL,
  `u_person_family_name` varchar(100) DEFAULT NULL,
  `u_person_surname` varchar(100) DEFAULT NULL,
  `u_bdate` date DEFAULT NULL,
  `u_add_phone` varchar(100) DEFAULT NULL,
  `u_address` varchar(255) DEFAULT NULL,
  `u_sex` enum('M','F') DEFAULT NULL,
  `u_restore_hash` char(64) DEFAULT NULL,
  `u_restore_until` datetime DEFAULT NULL,
  PRIMARY KEY (`u_id`),
  UNIQUE KEY `u_login` (`u_name`),
  KEY `idx_restore_hash` (`u_restore_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb3 */ ;
/*!50003 SET character_set_results = utf8mb3 */ ;
/*!50003 SET collation_connection  = utf8mb3_general_ci */ ;
DELIMITER ;;
CREATE FUNCTION `get_upl_parent`(`in_id` INT(10) UNSIGNED) RETURNS int(10) unsigned
    READS SQL DATA
RETURN (select ifnull(`upl_pid`, 0) from `share_uploads` where `upl_id` = in_id) ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb3 */ ;
/*!50003 SET character_set_results = utf8mb3 */ ;
/*!50003 SET collation_connection  = utf8mb3_general_ci */ ;
DELIMITER ;;
CREATE PROCEDURE `proc_get_upl_pid_list`(IN `in_id` INT(10) UNSIGNED)
    MODIFIES SQL DATA
BEGIN
    create temporary table if not exists temp (id int(10) UNSIGNED, title varchar(255)) DEFAULT CHARSET=utf8;
    set @_pid = in_id;

    while @_pid > 0 do
    insert into `temp` select upl_id, upl_title from `share_uploads` where upl_id = @_pid;
    set @_pid = get_upl_parent(@_pid);
    end while;
    select * from `temp`;
    drop table if exists `temp`;
  END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb3 */ ;
/*!50003 SET character_set_results = utf8mb3 */ ;
/*!50003 SET collation_connection  = utf8mb3_general_ci */ ;
DELIMITER ;;
CREATE PROCEDURE `proc_update_dir_date`(IN `in_id` INT UNSIGNED, IN `in_date` DATETIME)
    MODIFIES SQL DATA
BEGIN
	set @_pid = get_upl_parent(in_id);

    while @_pid > 0 do
	update share_uploads set upl_publication_date=in_date where upl_id=@_pid;
	set @_pid = get_upl_parent(@_pid);
    end while;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

