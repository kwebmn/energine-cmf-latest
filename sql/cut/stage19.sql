-- Energine Simple, надёжность 6: находки сравнения с xSight (docs/superpowers/plans/2026-10-06-energine-simple-r6-findings.md).
-- Переход базы после sql/cut/stage18.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage19.sql

-- 1. Цикл в дереве страниц: отказ сохранения, если новый родитель — сама страница или её подраздел (DivisionSaver).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_DIV_PARENT_LOOP');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
        'Розділ не можна перенести в самого себе або у свій підрозділ: виберіть іншого батька.',
        'Раздел нельзя перенести в самого себя или в свой подраздел: выберите другого родителя.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_DIV_PARENT_LOOP';
