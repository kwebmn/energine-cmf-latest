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
UPDATE `share_sitemap` SET `smap_content_xml` = '' WHERE `smap_content_xml` LIKE '%mainMenuContainer%';

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

-- 8. Демо-тексты (тема, этап 5в). Вход администратора demo@energine.org / demo — неправда на площадке со своим
--    паролем: боковой блок главной и страница «Админка» раздела «Возможности» его больше не называют.
--    Приветствие главной — о Energine Simple; украинская версия была русским текстом с припиской
--    «перекладати було обломно».
UPDATE `share_textblocks_translation` tt
  JOIN `share_textblocks` tb ON tb.`tb_id` = tt.`tb_id`
  JOIN `share_languages` l ON l.`lang_id` = tt.`lang_id`
   SET tt.`tb_content` = IF(l.`lang_abbr` = 'ua',
       '<p>Це демонстраційний сайт Energine Simple. Адміністратор входить за посиланням «Вхід» угорі сторінки.</p>',
       '<p>Это демонстрационный сайт Energine Simple. Администратор входит по ссылке «Вход» вверху страницы.</p>')
 WHERE tb.`tb_num` = 'sidebarTextBlock' AND tb.`smap_id` IS NULL;
UPDATE `share_textblocks_translation` tt
  JOIN `share_textblocks` tb ON tb.`tb_id` = tt.`tb_id`
  JOIN `share_sitemap` s ON s.`smap_id` = tb.`smap_id`
  JOIN `share_languages` l ON l.`lang_id` = tt.`lang_id`
   SET tt.`tb_content` = IF(l.`lang_abbr` = 'ua',
       '<p>Розділи адмінки зібрані на <a href="/ua/admin/">одній сторінці</a>; вхід — за посиланням «Вхід» угорі сторінки.</p>\n<h3>В адмінці</h3><ul><li><a href="/ua/admin/action-log/">Журнал дій</a></li></ul>',
       '<p>Разделы админки собраны на <a href="/admin/">одной странице</a>; вход — по ссылке «Вход» вверху страницы.</p>\n<p>Кроме редакторов содержимого есть журнал действий, редактор сайтов и доменов.</p>\n<h3>В админке</h3><ul><li><a href="/admin/action-log/">Журнал действий</a></li><li><a href="/admin/structure/sites/">Сайты и домены</a></li></ul>')
 WHERE s.`smap_segment` = 'admin' AND s.`smap_content` = 'textblock.content.xml' AND tb.`tb_num` = '1';
UPDATE `share_textblocks_translation` tt
  JOIN `share_textblocks` tb ON tb.`tb_id` = tt.`tb_id`
  JOIN `share_sitemap` s ON s.`smap_id` = tb.`smap_id`
  JOIN `share_languages` l ON l.`lang_id` = tt.`lang_id`
   SET tt.`tb_content` = IF(l.`lang_abbr` = 'ua',
       '<h1>Вітаємо!</h1>\n<p>Це демонстраційний сайт Energine Simple — системи керування для сайтів-візиток: сторінки, новини, галерея, зворотний зв’язок і кабінет відвідувача.</p>\n<ul>\n<li>Кілька мов: перекладаються і сторінки, і підписи інтерфейсу.</li>\n<li>Права: у кожної групи користувачів свої права на кожен розділ.</li>\n<li>Тексти редагуються просто на сторінці, у візуальному редакторі.</li>\n<li>Файли зберігаються в репозиторії сайту й використовуються в текстах, новинах і галереї.</li>\n<li>Структура сайту — дерево розділів, яке змінюється в адмінці.</li>\n</ul>',
       '<h1>Добро пожаловать!</h1>\n<p>Это демонстрационный сайт Energine Simple — системы управления для сайтов-визиток: страницы, новости, галерея, обратная связь и кабинет посетителя.</p>\n<ul>\n<li>Несколько языков: переводятся и страницы, и подписи интерфейса.</li>\n<li>Права: у каждой группы пользователей свои права на каждый раздел.</li>\n<li>Тексты правятся прямо на странице, в визуальном редакторе.</li>\n<li>Файлы хранятся в репозитории сайта и используются в текстах, новостях и галерее.</li>\n<li>Структура сайта — дерево разделов, которое меняется в админке.</li>\n</ul>')
 WHERE s.`smap_pid` IS NULL AND s.`smap_content` = 'main.content.xml' AND tb.`tb_num` = '1';
