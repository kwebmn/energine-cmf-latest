-- Energine Simple, этап 4: визуальный редактор — Jodit вместо CKEditor, загрузка файлов — fetch
-- вместо FileAPI. В базе меняется только справочник переводов.
--
-- Переходный скрипт. Применяется после sql/cut/stage3.sql, на свежей установке и на базе этапа 3;
-- повторный прогон на той же базе ничего не меняет. Сведение установки в один файл — этап 5.

-- 1. Подписи старой панели редактора (DataSet::addWYSIWYGTranslations): их читал только прежний
--    редактор. Список — tests/tools/cut-constants.php по удалённым строкам этапа и буквальные имена
--    удалённого кода, которых нет в оставшемся: TXT_H1…TXT_H6, TXT_ADDRESS, TXT_PREVIEW, TXT_RESET
--    собираются из обычного слова, и инструмент их прячет; динамически их никто не собирает.
--    Переводы удаляются каскадом.
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (
    'BTN_ALIGN_CENTER', 'BTN_ALIGN_JUSTIFY', 'BTN_ALIGN_LEFT', 'BTN_ALIGN_RIGHT', 'BTN_BOLD',
    'BTN_FILE_LIBRARY', 'BTN_HREF', 'BTN_INSERT_IMAGE', 'BTN_INSERT_IMAGE_URL', 'BTN_ITALIC',
    'BTN_OL', 'BTN_UL', 'BTN_VIEWSOURCE', 'TXT_ADDRESS', 'TXT_H1', 'TXT_H2', 'TXT_H3', 'TXT_H4',
    'TXT_H5', 'TXT_H6', 'TXT_PREVIEW', 'TXT_RESET'
);

-- 2. Правка на странице: блок, который сервер не сохранил (нет прав, сессия закончилась, отказ),
--    не считается сохранённым — администратор видит это сообщение.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_TEXT_NOT_SAVED');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Текст не збережено. Правка залишилася на сторінці — спробуйте ще раз або оновіть сторінку.',
           'Текст не сохранён. Правка осталась на странице — попробуйте ещё раз или обновите страницу.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_TEXT_NOT_SAVED';

-- 3. Загрузка файла, которая не состоялась: причина вместо имени константы (переводов не было).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_UPLOAD_TOO_BIG'), ('ERR_UPLOAD_FAILED'), ('ERR_NO_FILE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'ERR_UPLOAD_TOO_BIG' THEN IF(l.`lang_abbr` = 'ua', 'Файл більший за допустимий розмір: %size% МБ.',
                                                                          'Файл больше допустимого размера: %size% МБ.')
               WHEN 'ERR_UPLOAD_FAILED' THEN IF(l.`lang_abbr` = 'ua', 'Файл не завантажено. Спробуйте ще раз.',
                                                                         'Файл не загружен. Попробуйте ещё раз.')
               ELSE IF(l.`lang_abbr` = 'ua', 'Файл не вибрано.', 'Файл не выбран.')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('ERR_UPLOAD_TOO_BIG', 'ERR_UPLOAD_FAILED', 'ERR_NO_FILE');
