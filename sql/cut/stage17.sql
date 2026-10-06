-- Energine Simple, надёжность, этап 5: адреса и интерфейс (docs/superpowers/plans/2026-10-06-energine-simple-r5-urls-ui.md).
-- Переход базы после sql/cut/stage16.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage17.sql

-- 1. Старые адреса страниц: прежний путь страницы без языка и краевых слешей (about/team) → страница. Пишет форма
--    раздела, когда меняется сегмент или родитель (сама страница и её подразделы; PageAliases::remember), читает
--    обработчик 404 — переадресация 301 на нынешний адрес (PageAliases::find). Путь, снова занятый страницей,
--    из таблицы удаляется; удаление страницы уносит её строки каскадом.
CREATE TABLE IF NOT EXISTS `share_sitemap_aliases` (
  `alias_path` varchar(255) NOT NULL,
  `smap_id` int(10) unsigned NOT NULL,
  `alias_date` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`alias_path`),
  KEY `smap_id` (`smap_id`),
  CONSTRAINT `share_sitemap_aliases_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
