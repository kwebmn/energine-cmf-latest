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

-- 2. Используемый файл не удаляется молча: вопрос при удалении файла (папки), на который ссылаются тексты страниц
--    (FileRepository::delete, LinkChecker::fileReferrers); после текста — список страниц.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('MSG_FILE_LINKED');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
        'Цей файл використовується в текстах сторінок — посилання і картинки там стануть битими. Все одно видалити? Сторінки:',
        'Этот файл используется в текстах страниц — ссылки и картинки там станут битыми. Удалить всё равно? Страницы:')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'MSG_FILE_LINKED';

-- 3. Шаблон новой страницы: подсказка «что это за страница» под списком шаблонов (DivisionEditor::loadTemplateData —
--    атрибут data-hint варианта, DivForm — строка .e-template-hint).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HINT_CONTENT_LANDING'), ('HINT_CONTENT_SERVICE'), ('HINT_CONTENT_CONTACTS'),
    ('HINT_CONTENT_TEXTBLOCK'), ('HINT_CONTENT_CHILDS'), ('HINT_CONTENT_MAP'), ('HINT_CONTENT_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, CASE t.`ltag_name`
        WHEN 'HINT_CONTENT_LANDING' THEN IF(l.`lang_abbr` = 'ua',
            'Вітрина: перший екран, послуги, відгуки й заклик до дії. Кожну секцію правте прямо на сторінці.',
            'Витрина: первый экран, услуги, отзывы и призыв к действию. Каждую секцию правьте прямо на странице.')
        WHEN 'HINT_CONTENT_SERVICE' THEN IF(l.`lang_abbr` = 'ua',
            'Послуга: перший екран, опис, ціни та питання й відповіді.',
            'Услуга: первый экран, описание, цены и вопросы с ответами.')
        WHEN 'HINT_CONTENT_CONTACTS' THEN IF(l.`lang_abbr` = 'ua',
            'Контакти: текст і блок з адресою, телефоном, поштою та посиланням на мапу.',
            'Контакты: текст и блок с адресом, телефоном, почтой и ссылкой на карту.')
        WHEN 'HINT_CONTENT_TEXTBLOCK' THEN IF(l.`lang_abbr` = 'ua',
            'Звичайна сторінка: заголовок і текст.',
            'Обычная страница: заголовок и текст.')
        WHEN 'HINT_CONTENT_CHILDS' THEN IF(l.`lang_abbr` = 'ua',
            'Розділ: текст і список його підсторінок, список оновлюється сам.',
            'Раздел: текст и список его подстраниц, список обновляется сам.')
        WHEN 'HINT_CONTENT_MAP' THEN IF(l.`lang_abbr` = 'ua',
            'Карта сайту: усі сторінки сайту деревом, оновлюється сама.',
            'Карта сайта: все страницы сайта деревом, обновляется сама.')
        WHEN 'HINT_CONTENT_MAIN' THEN IF(l.`lang_abbr` = 'ua',
            'Проста головна: текст і бічний блок.',
            'Простая главная: текст и боковой блок.')
        END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('HINT_CONTENT_LANDING', 'HINT_CONTENT_SERVICE', 'HINT_CONTENT_CONTACTS', 'HINT_CONTENT_TEXTBLOCK',
         'HINT_CONTENT_CHILDS', 'HINT_CONTENT_MAP', 'HINT_CONTENT_MAIN');
