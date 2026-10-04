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

-- 2. Письмо о регистрации — без пароля: одноразовая ссылка на установку пароля ([password_link], срок — час;
--    истекла — «Забыли пароль?»). Пароль, созданный при регистрации, никуда не отправляется.
UPDATE `mail_templates` t JOIN `mail_templates_translation` tr USING (`template_id`) JOIN `share_languages` l USING (`lang_id`)
   SET tr.`template_body` = IF(l.`lang_abbr` = 'ua',
           CONCAT('Вітаємо, [user_name]!\n\nВи зареєстровані на сайті [site_name] ([site_url]). Логін: [user_login]\n\n',
                  'Задайте пароль за посиланням (діє годину): [password_link]\n',
                  'Якщо посилання застаріло, скористайтеся «Забули пароль?» на сторінці входу.\n\n',
                  'Лист надіслано автоматично, відповідати на нього не потрібно.'),
           CONCAT('Здравствуйте, [user_name]!\n\nВы зарегистрированы на сайте [site_name] ([site_url]). Логин: [user_login]\n\n',
                  'Задайте пароль по ссылке (действует час): [password_link]\n',
                  'Если ссылка устарела, воспользуйтесь «Забыли пароль?» на странице входа.\n\n',
                  'Письмо отправлено автоматически, отвечать на него не нужно.')),
       tr.`template_body_rtf` = IF(l.`lang_abbr` = 'ua',
           CONCAT('<p>Вітаємо, [user_name]!</p>\n<p>Ви зареєстровані на сайті <a href="[site_url]">[site_name]</a>. ',
                  'Логін: <strong>[user_login]</strong></p>\n<p><a href="[password_link]">Задайте пароль</a> — посилання діє годину. ',
                  'Якщо воно застаріло, скористайтеся «Забули пароль?» на сторінці входу.</p>\n',
                  '<p>Лист надіслано автоматично, відповідати на нього не потрібно.</p>'),
           CONCAT('<p>Здравствуйте, [user_name]!</p>\n<p>Вы зарегистрированы на сайте <a href="[site_url]">[site_name]</a>. ',
                  'Логин: <strong>[user_login]</strong></p>\n<p><a href="[password_link]">Задайте пароль</a> — ссылка действует час. ',
                  'Если она устарела, воспользуйтесь «Забыли пароль?» на странице входа.</p>\n',
                  '<p>Письмо отправлено автоматически, отвечать на него не нужно.</p>'))
 WHERE t.`template_sysname` = 'user_registration';
UPDATE `mail_templates`
   SET `template_hints` = '[user_name] - имя пользователя, [user_login] - логин (e-mail), [password_link] - ссылка установки пароля (действует час), [site_name] - название сайта, [site_url] - адрес сайта'
 WHERE `template_sysname` = 'user_registration';
