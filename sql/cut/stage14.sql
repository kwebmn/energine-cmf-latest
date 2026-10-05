-- Energine Simple, надёжность, этап 1 (docs/superpowers/plans/2026-10-05-energine-simple-r1-perimeter.md). Переход базы после
-- sql/cut/stage13.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage14.sql

-- 1. Безопасное удаление страницы (DivisionEditor::deleteData): сообщения отказа и вопрос при ссылках на страницу.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_DIV_HAS_CHILDREN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Спочатку видаліть або перенесіть підсторінки цієї сторінки.', 'Сначала удалите или перенесите подстраницы этой страницы.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'ERR_DIV_HAS_CHILDREN';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_DIV_SYSTEM');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Це службова сторінка сайту (вхід, адмінка, мапа сайту): її не можна видалити.', 'Это служебная страница сайта (вход, админка, карта сайта): её нельзя удалить.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'ERR_DIV_SYSTEM';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('MSG_DIV_LINKED');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'На цю сторінку посилаються тексти інших сторінок — посилання стануть битими. Все одно видалити? Сторінки з посиланнями:', 'На эту страницу ссылаются тексты других страниц — ссылки станут битыми. Удалить всё равно? Страницы со ссылками:')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'MSG_DIV_LINKED';
