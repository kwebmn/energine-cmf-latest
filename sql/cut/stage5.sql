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

-- 4. Восстановление пароля по одноразовой ссылке (RestorePassword): в базе — только хэш токена и срок ссылки;
--    пароль меняется после перехода по ссылке, а не сразу по запросу. Письмо — ссылка вместо пароля.
ALTER TABLE `user_users`
    ADD COLUMN IF NOT EXISTS `u_restore_hash` char(64) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `u_restore_until` datetime DEFAULT NULL,
    ADD INDEX IF NOT EXISTS `idx_restore_hash` (`u_restore_hash`);
UPDATE `mail_templates` t JOIN `mail_templates_translation` tr USING (`template_id`) JOIN `share_languages` l USING (`lang_id`)
   SET tr.`template_subject` = IF(l.`lang_abbr` = 'ua', 'Зміна пароля на сайті [site_name]', 'Смена пароля на сайте [site_name]'),
       tr.`template_body` = IF(l.`lang_abbr` = 'ua',
           CONCAT('Шановн[sex_suffix_hello] [user_name]!\n\n',
                  'Для облікового запису [user_login] на сайті [site_name] ([site_url]) запитано зміну пароля.\n',
                  'Щоб задати новий пароль, перейдіть за посиланням (воно дійсне одну годину):\n[restore_link]\n\n',
                  'Якщо ви не запитували зміну пароля, просто проігноруйте цей лист: пароль залишиться попереднім.'),
           CONCAT('Уважаем[sex_suffix_hello] [user_name]!\n\n',
                  'Для учётной записи [user_login] на сайте [site_name] ([site_url]) запрошена смена пароля.\n',
                  'Чтобы задать новый пароль, перейдите по ссылке (она действует один час):\n[restore_link]\n\n',
                  'Если вы не запрашивали смену пароля, просто проигнорируйте это письмо: пароль останется прежним.')),
       tr.`template_body_rtf` = IF(l.`lang_abbr` = 'ua',
           CONCAT('<p>Шановн[sex_suffix_hello] [user_name]!</p>\n',
                  '<p>Для облікового запису [user_login] на сайті <a href="[site_url]">[site_name]</a> запитано зміну пароля.</p>\n',
                  '<p>Щоб задати новий пароль, перейдіть за посиланням (воно дійсне одну годину):<br><a href="[restore_link]">[restore_link]</a></p>\n',
                  '<p>Якщо ви не запитували зміну пароля, просто проігноруйте цей лист: пароль залишиться попереднім.</p>'),
           CONCAT('<p>Уважаем[sex_suffix_hello] [user_name]!</p>\n',
                  '<p>Для учётной записи [user_login] на сайте <a href="[site_url]">[site_name]</a> запрошена смена пароля.</p>\n',
                  '<p>Чтобы задать новый пароль, перейдите по ссылке (она действует один час):<br><a href="[restore_link]">[restore_link]</a></p>\n',
                  '<p>Если вы не запрашивали смену пароля, просто проигнорируйте это письмо: пароль останется прежним.</p>'))
 WHERE t.`template_sysname` = 'user_restore_password';
UPDATE `mail_templates`
   SET `template_hints` = '[sex_suffix_hello] - окончание обращения по полу пользователя (константы TXT_EMAIL_SUFFIX_SEX_M/F/UNKNOWN), [user_name] - имя, [user_login] - логин (e-mail), [restore_link] - ссылка для смены пароля (действует час), [site_name] - название сайта, [site_url] - адрес сайта'
 WHERE `template_sysname` = 'user_restore_password';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES
    ('MSG_RESTORE_LINK_SENT'), ('ERR_RESTORE_LINK'), ('MSG_PASSWORD_CHANGED'), ('TXT_NEW_PASSWORD');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'MSG_RESTORE_LINK_SENT' THEN IF(l.`lang_abbr` = 'ua',
                   'Якщо цю адресу зареєстровано, на неї надіслано посилання для зміни пароля. Посилання дійсне одну годину.',
                   'Если этот адрес зарегистрирован, на него отправлена ссылка для смены пароля. Ссылка действует один час.')
               WHEN 'ERR_RESTORE_LINK' THEN IF(l.`lang_abbr` = 'ua',
                   'Посилання для зміни пароля застаріло або вже використане. Запросіть нове.',
                   'Ссылка для смены пароля устарела или уже использована. Запросите новую.')
               WHEN 'MSG_PASSWORD_CHANGED' THEN IF(l.`lang_abbr` = 'ua',
                   'Пароль змінено. Увійдіть із новим паролем.',
                   'Пароль изменён. Войдите с новым паролем.')
               ELSE IF(l.`lang_abbr` = 'ua', 'Новий пароль', 'Новый пароль')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('MSG_RESTORE_LINK_SENT', 'ERR_RESTORE_LINK', 'MSG_PASSWORD_CHANGED', 'TXT_NEW_PASSWORD');
-- прежние сообщения (новый пароль в письме, «неправильное имя пользователя» — выдавало, есть ли адрес)
DELETE FROM `share_lang_tags` WHERE `ltag_name` IN ('MSG_PASSWORD_SENT', 'ERR_NO_U_NAME');

-- 5. Ловушка для ботов и минимальное время заполнения (FormGuard) в регистрации и обратной связи.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_FORM_SPAM');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Форму надіслано надто швидко або автоматично. Перевірте дані та надішліть ще раз.',
           'Форма отправлена слишком быстро или автоматически. Проверьте данные и отправьте ещё раз.')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'ERR_FORM_SPAM';

-- 6. Тема (этап 5в): подписи шапки — ссылка «к содержимому», меню, крошки.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SKIP_TO_CONTENT'), ('TXT_MAIN_MENU'), ('TXT_MENU'), ('TXT_BREADCRUMBS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'TXT_SKIP_TO_CONTENT' THEN IF(l.`lang_abbr` = 'ua', 'До змісту', 'К содержимому')
               WHEN 'TXT_MAIN_MENU' THEN IF(l.`lang_abbr` = 'ua', 'Головне меню', 'Главное меню')
               WHEN 'TXT_MENU' THEN IF(l.`lang_abbr` = 'ua', 'Меню', 'Меню')
               ELSE IF(l.`lang_abbr` = 'ua', 'Ви тут', 'Вы здесь')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('TXT_SKIP_TO_CONTENT', 'TXT_MAIN_MENU', 'TXT_MENU', 'TXT_BREADCRUMBS');
-- Своё XML содержимого со старой раскладкой (меню и вход в колонке — теперь они в шапке) заменяется
-- шаблоном страницы: так у демо-главной; как у админки, пустая строка — «брать шаблон».
-- Такие страницы перечисляются в выводе клиента mysql — их раскладку при необходимости собрать заново в админке.
SELECT CONCAT(`smap_id`, ' ', `smap_segment`) AS `XML страницы сброшен на шаблон`
  FROM `share_sitemap` WHERE `smap_content_xml` LIKE '%mainMenuContainer%';
UPDATE `share_sitemap` SET `smap_content_xml` = '' WHERE `smap_content_xml` LIKE '%mainMenuContainer%';
-- Демо-тексты темы (вход администратора без demo/demo, приветствие главной) — в sql/demo.sql:
-- переход сайта на форк его собственные тексты не трогает.

-- 7. Профиль (исправления этапа 5а): смена пароля — с текущим паролем; поле пароля — «новый пароль».
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('FIELD_U_PASSWORD_CURRENT'), ('FIELD_U_PASSWORD_NEW');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'FIELD_U_PASSWORD_CURRENT' THEN IF(l.`lang_abbr` = 'ua', 'Поточний пароль', 'Текущий пароль')
               ELSE IF(l.`lang_abbr` = 'ua', 'Новий пароль', 'Новый пароль')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('FIELD_U_PASSWORD_CURRENT', 'FIELD_U_PASSWORD_NEW');


-- 9. Листалка по страницам (исправления темы): подписи стрелок «назад» и «вперёд».
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_PREVIOUS_PAGE'), ('TXT_NEXT_PAGE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`,
           CASE t.`ltag_name`
               WHEN 'TXT_PREVIOUS_PAGE' THEN IF(l.`lang_abbr` = 'ua', 'Попередня сторінка', 'Предыдущая страница')
               ELSE IF(l.`lang_abbr` = 'ua', 'Наступна сторінка', 'Следующая страница')
           END
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` IN ('TXT_PREVIOUS_PAGE', 'TXT_NEXT_PAGE');
