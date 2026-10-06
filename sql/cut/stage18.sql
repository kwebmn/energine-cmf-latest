-- Energine Simple, идеи xsight для владельца (docs/superpowers/plans/2026-10-06-energine-simple-x1-owner.md).
-- Переход базы после sql/cut/stage17.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage18.sql

-- 1. Битые ссылки на странице: подсказка у пометки, которую видит администратор (TextLinks).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_BROKEN_LINK_PAGE'), ('TXT_BROKEN_LINK_FILE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, CASE t.`ltag_name`
        WHEN 'TXT_BROKEN_LINK_PAGE' THEN IF(l.`lang_abbr` = 'ua',
            'Бите посилання: такої сторінки немає. Відвідувачі бачать тут просто текст.',
            'Битая ссылка: такой страницы нет. Посетители видят здесь просто текст.')
        WHEN 'TXT_BROKEN_LINK_FILE' THEN IF(l.`lang_abbr` = 'ua',
            'Бите посилання: такого файлу немає. Відвідувачі його не бачать.',
            'Битая ссылка: такого файла нет. Посетители его не видят.')
        END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('TXT_BROKEN_LINK_PAGE', 'TXT_BROKEN_LINK_FILE');
