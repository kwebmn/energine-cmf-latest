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
