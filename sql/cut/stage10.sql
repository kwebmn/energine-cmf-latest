-- Energine Simple, этап 10: доделки (docs/superpowers/plans/2026-10-04-energine-simple-stage10-followups.md).
-- Переход базы сайта после sql/cut/stage7.sql (у этапов 8–9 переходов базы нет); каждый раздел можно запускать повторно.
--   mariadb БАЗА < sql/cut/stage10.sql

-- 1. Внутренние ошибки (база, пути сервера) посетителю не показываются — общий текст.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_SERVER');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Помилка на сервері. Спробуйте ще раз пізніше.', 'Ошибка на сервере. Попробуйте ещё раз позже.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_SERVER';
