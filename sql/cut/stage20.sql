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

-- 2. Страница результатов поиска (/search/): служебная (SYSTEM_SEGMENTS у DivisionEditor и SearchIndex), не в меню,
--    закрыта от поисковиков (NOINDEX: её нет и в картах сайта), права — как у карты сайта. Номер строки — как в файлах
--    установки (fresh-check сверяет площадку с установкой); занят на площадке — следующий свободный.
INSERT INTO `share_sitemap` (`smap_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_in_menu`, `smap_order_num`, `smap_meta_robots`)
    SELECT IF(EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_id` = 3732), NULL, 3732), 'default.layout.xml',
           'search.content.xml', r.`smap_id`, 'search', 0, 220, 'NOINDEX'
      FROM `share_sitemap` r
     WHERE r.`smap_pid` IS NULL
       AND NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = r.`smap_id` AND x.`smap_segment` = 'search');
-- (своя страница владельца с сегментом search у корня — не трогается: ни названий, ни прав)
SET @search = (SELECT s.`smap_id` FROM `share_sitemap` s JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` AND r.`smap_pid` IS NULL
                WHERE s.`smap_segment` = 'search' AND s.`smap_content` = 'search.content.xml');
INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
    SELECT @search, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Пошук по сайту', 'Поиск по сайту'), 0 FROM `share_languages` l
     WHERE @search IS NOT NULL;
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
    SELECT @search, a.`group_id`, a.`right_id` FROM `share_access_level` a JOIN `share_sitemap` s USING (`smap_id`)
      JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` AND r.`smap_pid` IS NULL
     WHERE s.`smap_segment` = 'sitemap' AND @search IS NOT NULL;

-- 3. Переводы: поле в шапке (TXT_SEARCH, BTN_SEARCH — MainMenu.component.xml), страница результатов, шаблон
--    содержимого search.content.xml в редакторе структуры (CONTENT_SEARCH).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_SEARCH');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Пошук по сайту', 'Поиск по сайту')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'CONTENT_SEARCH';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SEARCH');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Пошук по сайту', 'Поиск по сайту')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_SEARCH';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('BTN_SEARCH');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Знайти', 'Найти')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'BTN_SEARCH';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SEARCH_FOUND');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Знайдено сторінок', 'Найдено страниц')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_SEARCH_FOUND';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SEARCH_HINT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Введіть слова, які є на потрібній сторінці: знайдуться сторінки з усіма цими словами в будь-якій формі.',
           'Введите слова, которые есть на нужной странице: найдутся страницы со всеми этими словами в любой форме.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_SEARCH_HINT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SEARCH_NOTHING');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Нічого не знайдено. Спробуйте інші слова або менше слів.',
           'Ничего не найдено. Попробуйте другие слова или меньше слов.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_SEARCH_NOTHING';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SEARCH_PAGES');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сторінки результатів', 'Страницы результатов')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_SEARCH_PAGES';
