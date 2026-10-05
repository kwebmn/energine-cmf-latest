-- Energine Simple, надёжность, этап 3: владельцу (docs/superpowers/plans/2026-10-06-energine-simple-r3-owner.md).
-- Переход базы после sql/cut/stage15.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage16.sql

-- 1. История текста: прежний текст блока на языке перед каждым сохранением (не больше 20 версий на блок и язык,
--    TextHistory::LIMIT); удаление блока уносит историю каскадом. Автор — u_id без внешнего ключа: пользователя
--    могут удалить, история остаётся.
CREATE TABLE IF NOT EXISTS `share_textblocks_history` (
  `tbh_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tb_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `tbh_date` datetime NOT NULL DEFAULT current_timestamp(),
  `u_id` int(10) unsigned DEFAULT NULL,
  `tbh_content` text NOT NULL,
  PRIMARY KEY (`tbh_id`),
  KEY `tb_lang` (`tb_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `share_textblocks_history_ibfk_1` FOREIGN KEY (`tb_id`) REFERENCES `share_textblocks` (`tb_id`) ON DELETE CASCADE,
  CONSTRAINT `share_textblocks_history_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- Подписи окна истории, журнала и подсказки.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('BTN_HISTORY'), ('BTN_RESTORE'), ('BTN_VIEW'), ('TXT_TEXT_HISTORY'),
    ('FIELD_TBH_DATE'), ('FIELD_TBH_AUTHOR'), ('FIELD_TBH_EXCERPT'),
    ('CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK'), ('CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCKHISTORY'), ('HELP_TEXTBLOCKHISTORY_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, CASE t.`ltag_name`
        WHEN 'BTN_HISTORY' THEN IF(l.`lang_abbr` = 'ua', 'Історія', 'История')
        WHEN 'BTN_RESTORE' THEN IF(l.`lang_abbr` = 'ua', 'Повернути', 'Вернуть')
        WHEN 'BTN_VIEW' THEN IF(l.`lang_abbr` = 'ua', 'Переглянути', 'Посмотреть')
        WHEN 'TXT_TEXT_HISTORY' THEN IF(l.`lang_abbr` = 'ua', 'Історія тексту', 'История текста')
        WHEN 'FIELD_TBH_DATE' THEN IF(l.`lang_abbr` = 'ua', 'Коли', 'Когда')
        WHEN 'FIELD_TBH_AUTHOR' THEN IF(l.`lang_abbr` = 'ua', 'Хто', 'Кто')
        WHEN 'FIELD_TBH_EXCERPT' THEN IF(l.`lang_abbr` = 'ua', 'Початок тексту', 'Начало текста')
        WHEN 'CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK' THEN IF(l.`lang_abbr` = 'ua', 'Текст сторінки', 'Текст страницы')
        WHEN 'CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCKHISTORY' THEN IF(l.`lang_abbr` = 'ua', 'Історія тексту', 'История текста')
        WHEN 'HELP_TEXTBLOCKHISTORY_MAIN' THEN IF(l.`lang_abbr` = 'ua',
            'Прежні версії цього тексту цією мовою, нові зверху. «Переглянути» показує версію цілком, «Повернути» робить її поточною — нинішній текст теж залишається в історії. Зберігається до 20 версій.',
            'Прежние версии этого текста на этом языке, новые сверху. «Посмотреть» показывает версию целиком, «Вернуть» делает её текущей — нынешний текст тоже остаётся в истории. Хранится до 20 версий.')
        END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('BTN_HISTORY', 'BTN_RESTORE', 'BTN_VIEW', 'TXT_TEXT_HISTORY', 'FIELD_TBH_DATE', 'FIELD_TBH_AUTHOR',
        'FIELD_TBH_EXCERPT', 'CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK',
        'CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCKHISTORY', 'HELP_TEXTBLOCKHISTORY_MAIN');

-- 2. Язык «в подготовке»: lang_is_active = 0 — язык виден только редакторам (гостю его адреса дают 404, в переключателе
--    его нет), язык по умолчанию выключить нельзя (LanguageEditor, ERR_LANG_DEFAULT_INACTIVE).
ALTER TABLE `share_languages` ADD COLUMN IF NOT EXISTS `lang_is_active` tinyint(1) NOT NULL DEFAULT 1 AFTER `lang_default`;
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('FIELD_LANG_IS_ACTIVE'), ('TXT_LANG_INACTIVE'), ('ERR_LANG_DEFAULT_INACTIVE'),
    ('HELP_LANGUAGEEDITOR_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, CASE t.`ltag_name`
        WHEN 'FIELD_LANG_IS_ACTIVE' THEN IF(l.`lang_abbr` = 'ua', 'Відкритий відвідувачам', 'Открыт посетителям')
        WHEN 'TXT_LANG_INACTIVE' THEN IF(l.`lang_abbr` = 'ua', 'у підготовці', 'в подготовке')
        WHEN 'ERR_LANG_DEFAULT_INACTIVE' THEN IF(l.`lang_abbr` = 'ua',
            'Мову за замовчуванням не можна закрити від відвідувачів: спочатку призначте іншу мову за замовчуванням.',
            'Язык по умолчанию нельзя закрыть от посетителей: сначала назначьте другой язык по умолчанию.')
        WHEN 'HELP_LANGUAGEEDITOR_MAIN' THEN IF(l.`lang_abbr` = 'ua',
            'Мови сайту. Нову мову можна готувати непомітно для відвідувачів: зніміть позначку «Відкритий відвідувачам» — її сторінки побачать лише редактори, у перемикачі мов її не буде. Коли тексти готові, поставте позначку знову.',
            'Языки сайта. Новый язык можно готовить незаметно для посетителей: снимите отметку «Открыт посетителям» — его страницы увидят только редакторы, в переключателе языков его не будет. Когда тексты готовы, поставьте отметку снова.')
        END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('FIELD_LANG_IS_ACTIVE', 'TXT_LANG_INACTIVE', 'ERR_LANG_DEFAULT_INACTIVE', 'HELP_LANGUAGEEDITOR_MAIN');
