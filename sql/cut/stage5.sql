-- Energine Simple, этап 5а: безопасность — токен против подделки запросов, лимит попыток входа,
-- восстановление пароля по одноразовой ссылке, ловушка для ботов в формах.
--
-- Переходный скрипт. Применяется после sql/cut/stage4.sql, на свежей установке и на базе этапа 4;
-- повторный прогон на той же базе ничего не меняет. Сведение установки в один файл — этап 5г.

-- 1. Отказ по токену (Csrf): страница ошибки (код 422), ответ JSON админке, сообщение формы входа.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_CSRF');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Форма застаріла або надіслана з іншого сайту. Оновіть сторінку та надішліть ще раз.',
           'Форма устарела или отправлена с другого сайта. Обновите страницу и отправьте ещё раз.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_CSRF';

-- 2. Неудачный вход: сообщение выводилось именем константы — перевода не было никогда.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_BAD_AUTH');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Невірний e-mail або пароль.', 'Неверный e-mail или пароль.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_BAD_AUTH';

-- 3. Лимит попыток входа (AuthUser): неудачные попытки по логину и IP за окно 15 минут; записи старше
--    окна удаляются при каждой новой. utf8mb4: логин в попытке — любой текст, в том числе 4-байтовые символы.
CREATE TABLE IF NOT EXISTS `user_login_attempts` (
  `la_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `la_ip` varchar(45) NOT NULL,
  `la_login` varchar(250) NOT NULL,
  `la_date` int(10) unsigned NOT NULL,
  PRIMARY KEY (`la_id`),
  KEY `idx_login_date` (`la_login`, `la_date`),
  KEY `idx_ip_date` (`la_ip`, `la_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_TOO_MANY_ATTEMPTS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Забагато невдалих спроб входу. Спробуйте через 15 хвилин.',
           'Слишком много неудачных попыток входа. Попробуйте через 15 минут.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_TOO_MANY_ATTEMPTS';

