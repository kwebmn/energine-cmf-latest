-- Energine Simple, надёжность, этап 2: статический анализ (docs/superpowers/plans/2026-10-05-energine-simple-r2-static.md).
-- Переход базы после sql/cut/stage14.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage15.sql

-- Константы перевода, которые использовал только удалённый мёртвый код: закомментированная заготовка загрузки
-- zip-архива в репозитории файлов (кнопка addZip в конфиге и исключение ERR_FAKE в FileRepository::uploadZip).
DELETE tr FROM `share_lang_tags_translation` tr JOIN `share_lang_tags` t USING (`ltag_id`) WHERE t.`ltag_name` IN (
    'BTN_ZIP_UPLOAD',
    'ERR_FAKE'
);
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (
    'BTN_ZIP_UPLOAD',
    'ERR_FAKE'
);
