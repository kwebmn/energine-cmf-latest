-- Energine Simple, поиск по сайту (docs/superpowers/plans/2026-10-06-energine-simple-search.md).
-- Переход базы после sql/cut/stage19.sql. Повторный запуск ничего не меняет. После него — индекс:
--   mariadb БАЗА < sql/cut/stage20.sql && php web/index.php setup reindex

-- 1. Индекс поиска: страница на языке — название и текст для отрывка, основы слов для FULLTEXT (SearchIndex); журнал
--    поиска: что искали (в нижнем регистре), сколько раз, сколько нашлось в последний раз, когда (SiteSearch::log).
--    Строк в файлах установки нет: индекс строит setup reindex (и setup install, setup demo), журнал пишут посетители.
CREATE TABLE IF NOT EXISTS `share_search_index` (
  `smap_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `title` varchar(250) NOT NULL DEFAULT '',
  `body` mediumtext NOT NULL,
  `title_stems` text NOT NULL,
  `body_stems` mediumtext NOT NULL,
  PRIMARY KEY (`smap_id`, `lang_id`),
  KEY `i_search_index_lang` (`lang_id`),
  FULLTEXT KEY `ft_search_title` (`title_stems`),
  FULLTEXT KEY `ft_search_body` (`body_stems`),
  FULLTEXT KEY `ft_search_all` (`title_stems`, `body_stems`),
  CONSTRAINT `share_search_index_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE,
  CONSTRAINT `share_search_index_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
CREATE TABLE IF NOT EXISTS `share_search_log` (
  `log_query` varchar(200) NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `log_count` int(10) unsigned NOT NULL DEFAULT 1,
  `log_results` int(10) unsigned NOT NULL DEFAULT 0,
  `log_last` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`log_query`, `lang_id`),
  KEY `i_search_log_last` (`log_last`),
  CONSTRAINT `share_search_log_ibfk_1` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
