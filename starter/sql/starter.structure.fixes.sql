-- Доработки схемы, которых нет в starter.structure.sql (дамп от 2016-05),
-- но на которые опирается код ядра energine-cmf/energine@master (2018-05).
-- Импортировать после starter.structure.sql / starter.routines.sql / starter.data.*.sql

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS=0;

-- core/modules/share/gears/Site.php (коммит 20dee2a5 "shop favicon"):
-- Site::load() на каждом запросе выбирает favicon сайта из этой таблицы
CREATE TABLE IF NOT EXISTS `shop_sites_uploads_favicon` (
  `site_id` int(11) unsigned NOT NULL,
  `upl_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`site_id`,`upl_id`),
  KEY `upl_id` (`upl_id`),
  CONSTRAINT `shop_sites_uploads_favicon_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_sites_uploads_favicon_ibfk_2` FOREIGN KEY (`upl_id`) REFERENCES `share_uploads` (`upl_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- SEO robots: patch.sql (удалён из репо в b2d25ecf, 2015-09), в дамп попал лишь частично.
-- Sitemap::preparePageInfo() требует smap_meta_robots, Site::load() вычисляет isIndexed из site_meta_robots.
-- Старые колонки есть только в базах, доживших с версии 2015 года: в дампе
-- starter.structure.sql их уже нет. Поэтому перенос значения выполняется,
-- только если колонка на месте, - иначе импорт с нуля обрывался на этом месте.
ALTER TABLE `share_sites` MODIFY `site_meta_robots` SET('NOINDEX','NOFOLLOW','NOARCHIVE','NOSNIPPET','NOODP') NULL;
SET @has_col := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'share_sites' AND `COLUMN_NAME` = 'site_is_indexed');
SET @sql := IF(@has_col, 'UPDATE `share_sites` SET `site_meta_robots` = ''NOINDEX'' WHERE `site_is_indexed` = 0', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
ALTER TABLE `share_sites` DROP COLUMN IF EXISTS `site_is_indexed`;

ALTER TABLE `share_sitemap` ADD COLUMN IF NOT EXISTS `smap_meta_robots` SET('NOINDEX','NOFOLLOW','NOARCHIVE','NOSNIPPET','NOODP') NULL AFTER `smap_redirect_url`;
SET @has_col := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
  WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'share_sitemap' AND `COLUMN_NAME` = 'smap_is_indexed');
SET @sql := IF(@has_col, 'UPDATE `share_sitemap` SET `smap_meta_robots` = ''NOINDEX'' WHERE `smap_is_indexed` = 0', 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
ALTER TABLE `share_sitemap` DROP COLUMN IF EXISTS `smap_is_indexed`;

-- Профиль пользователя: поля из user/config/UserEditor.component.xml и Register.component.xml
-- (появились в ядре в 2016). Без колонок поля формы становятся customField и не сохраняются.
-- Типы под FieldDescription::convertType(): *_img -> загрузка файла, *_phone -> телефон,
-- ENUM -> список (RestorePassword ждёт 'M'/'F'), DATE -> дата.
-- Входы через соцсети удалены из ядра, их колонки (u_gooid/u_okid/u_inid) больше не создаются.
ALTER TABLE `user_users`
  ADD COLUMN IF NOT EXISTS `u_avatar_img` varchar(1000) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_person_name` varchar(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_person_family_name` varchar(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_person_surname` varchar(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_bdate` date DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_add_phone` varchar(100) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_address` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `u_sex` enum('M','F') DEFAULT NULL;

-- Обратная связь: FeedbackForm вставляет сообщение без feed_date и проставляет дату следующим UPDATE;
-- в строгом режиме MariaDB вставка падает (Field 'feed_date' doesn't have a default value).
ALTER TABLE `apps_feedback` MODIFY `feed_date` datetime NOT NULL DEFAULT current_timestamp();

-- Подписи для добавленных полей (формы переводят FIELD_<ПОЛЕ> и варианты ENUM/SET как FIELD_<ПОЛЕ>_ENUM_<ЗНАЧЕНИЕ>)
-- и самые заметные константы ядра, которых нет в дампе: форма входа, страница ошибки, файловый репозиторий.
-- Полный список непереведённых констант: php index.php setup untranslated
CREATE TEMPORARY TABLE `tmp_fix_translations` (`name` varchar(70) NOT NULL, `abbr` char(2) NOT NULL, `value` text NOT NULL) DEFAULT CHARSET=utf8;
INSERT INTO `tmp_fix_translations` VALUES
  ('FIELD_U_PERSON_NAME', 'ru', 'Имя'), ('FIELD_U_PERSON_NAME', 'ua', 'Ім''я'),
  ('FIELD_U_PERSON_FAMILY_NAME', 'ru', 'Фамилия'), ('FIELD_U_PERSON_FAMILY_NAME', 'ua', 'Прізвище'),
  ('FIELD_U_PERSON_SURNAME', 'ru', 'Отчество'), ('FIELD_U_PERSON_SURNAME', 'ua', 'По батькові'),
  ('FIELD_U_BDATE', 'ru', 'Дата рождения'), ('FIELD_U_BDATE', 'ua', 'Дата народження'),
  ('FIELD_U_ADD_PHONE', 'ru', 'Дополнительный телефон'), ('FIELD_U_ADD_PHONE', 'ua', 'Додатковий телефон'),
  ('FIELD_U_SEX', 'ru', 'Пол'), ('FIELD_U_SEX', 'ua', 'Стать'),
  ('FIELD_U_SEX_ENUM_M', 'ru', 'Мужской'), ('FIELD_U_SEX_ENUM_M', 'ua', 'Чоловіча'),
  ('FIELD_U_SEX_ENUM_F', 'ru', 'Женский'), ('FIELD_U_SEX_ENUM_F', 'ua', 'Жіноча'),
  ('FIELD_SMAP_META_ROBOTS', 'ru', 'Мета robots'), ('FIELD_SMAP_META_ROBOTS', 'ua', 'Мета robots'),
  ('FIELD_SMAP_META_ROBOTS_ENUM_NOINDEX', 'ru', 'noindex'), ('FIELD_SMAP_META_ROBOTS_ENUM_NOINDEX', 'ua', 'noindex'),
  ('FIELD_SMAP_META_ROBOTS_ENUM_NOFOLLOW', 'ru', 'nofollow'), ('FIELD_SMAP_META_ROBOTS_ENUM_NOFOLLOW', 'ua', 'nofollow'),
  ('FIELD_SMAP_META_ROBOTS_ENUM_NOARCHIVE', 'ru', 'noarchive'), ('FIELD_SMAP_META_ROBOTS_ENUM_NOARCHIVE', 'ua', 'noarchive'),
  ('FIELD_SMAP_META_ROBOTS_ENUM_NOSNIPPET', 'ru', 'nosnippet'), ('FIELD_SMAP_META_ROBOTS_ENUM_NOSNIPPET', 'ua', 'nosnippet'),
  ('FIELD_SMAP_META_ROBOTS_ENUM_NOODP', 'ru', 'noodp'), ('FIELD_SMAP_META_ROBOTS_ENUM_NOODP', 'ua', 'noodp'),
  ('FIELD_SITE_META_ROBOTS_ENUM_NOINDEX', 'ru', 'noindex'), ('FIELD_SITE_META_ROBOTS_ENUM_NOINDEX', 'ua', 'noindex'),
  ('FIELD_SITE_META_ROBOTS_ENUM_NOFOLLOW', 'ru', 'nofollow'), ('FIELD_SITE_META_ROBOTS_ENUM_NOFOLLOW', 'ua', 'nofollow'),
  ('FIELD_SITE_META_ROBOTS_ENUM_NOARCHIVE', 'ru', 'noarchive'), ('FIELD_SITE_META_ROBOTS_ENUM_NOARCHIVE', 'ua', 'noarchive'),
  ('FIELD_SITE_META_ROBOTS_ENUM_NOSNIPPET', 'ru', 'nosnippet'), ('FIELD_SITE_META_ROBOTS_ENUM_NOSNIPPET', 'ua', 'nosnippet'),
  ('FIELD_SITE_META_ROBOTS_ENUM_NOODP', 'ru', 'noodp'), ('FIELD_SITE_META_ROBOTS_ENUM_NOODP', 'ua', 'noodp'),
  ('FIELD_LOGIN_U_NAME', 'ru', 'E-mail'), ('FIELD_LOGIN_U_NAME', 'ua', 'E-mail'),
  ('FIELD_LOGIN_U_PASSWORD', 'ru', 'Пароль'), ('FIELD_LOGIN_U_PASSWORD', 'ua', 'Пароль'),
  ('TXT_ERROR', 'ru', 'Ошибка'), ('TXT_ERROR', 'ua', 'Помилка'),
  ('TXT_ERROR_404', 'ru', 'Запрашиваемая страница не найдена.'), ('TXT_ERROR_404', 'ua', 'Запитувану сторінку не знайдено.'),
  ('TXT_ERROR_403', 'ru', 'Доступ к странице запрещён.'), ('TXT_ERROR_403', 'ua', 'Доступ до сторінки заборонено.'),
  ('TXT_ERROR_HINT', 'ru', 'Проверьте правильность адреса или перейдите на главную страницу сайта «%site_name%».'),
  ('TXT_ERROR_HINT', 'ua', 'Перевірте правильність адреси або перейдіть на головну сторінку сайту «%site_name%».'),
  ('BTN_COPY_FM', 'ru', 'Копировать'), ('BTN_COPY_FM', 'ua', 'Копіювати'),
  ('BTN_MOVE_TO_DIR', 'ru', 'Переместить в папку'), ('BTN_MOVE_TO_DIR', 'ua', 'Перемістити до теки'),
  ('MSG_WRONG_DATE_FORMAT', 'ru', 'Неверный формат даты, нужен ГГГГ-ММ-ДД.'), ('MSG_WRONG_DATE_FORMAT', 'ua', 'Невірний формат дати, потрібен РРРР-ММ-ДД.');
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) SELECT DISTINCT `name` FROM `tmp_fix_translations`;
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`, x.`value`
    FROM `tmp_fix_translations` x
    JOIN `share_lang_tags` t ON t.`ltag_name` = x.`name`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`;
DROP TEMPORARY TABLE `tmp_fix_translations`;

-- Подписи и сообщения ядра
-- Константы, у которых не было записи в справочнике: админка показывала
-- их системные имена (FIELD_TOP_NAME и т.п.) вместо подписей.
-- кодировка колонки задана явно: `share_lang_tags`.`ltag_name` - utf8mb3_general_ci,
-- а временная таблица иначе берёт сортировку базы, и соединение падает
CREATE TEMPORARY TABLE `tmp_label_translations` (
  `name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
  `abbr` VARCHAR(5) CHARACTER SET utf8 COLLATE utf8_general_ci,
  `value` TEXT CHARACTER SET utf8 COLLATE utf8_general_ci);
INSERT INTO `tmp_label_translations` (`name`, `abbr`, `value`) VALUES
  ('BTN_CLEAR', 'ru', 'Очистить'), ('BTN_CLEAR', 'ua', 'Очистити'),
  ('BTN_INSERT_IMAGE_URL', 'ru', 'Вставить по ссылке'), ('BTN_INSERT_IMAGE_URL', 'ua', 'Вставити за посиланням'),
  ('BTN_INSERT_VIDEO', 'ru', 'Вставить видео'), ('BTN_INSERT_VIDEO', 'ua', 'Вставити відео'),
  ('BTN_MOVE_CANCEL', 'ru', 'Отменить перемещение'), ('BTN_MOVE_CANCEL', 'ua', 'Скасувати переміщення'),
  ('ERR_BAD_DATA', 'ru', 'Запрос не содержит данных.'), ('ERR_BAD_DATA', 'ua', 'Запит не містить даних.'),
  ('ERR_BAD_FORM_ID', 'ru', 'Форма не найдена.'), ('ERR_BAD_FORM_ID', 'ua', 'Форму не знайдено.'),
  ('ERR_BAD_PID', 'ru', 'Папка не найдена.'), ('ERR_BAD_PID', 'ua', 'Теку не знайдено.'),
  ('ERR_BAD_PREPARE_FUNCTION', 'ru', 'Не задана функция подготовки файла.'), ('ERR_BAD_PREPARE_FUNCTION', 'ua', 'Не задано функцію підготовки файлу.'),
  ('ERR_BAD_XML', 'ru', 'Неверная разметка XML.'), ('ERR_BAD_XML', 'ua', 'Невірна розмітка XML.'),
  ('ERR_BAD_XML_DESCR', 'ru', 'Описание виджета не разобрано: неверная разметка XML.'), ('ERR_BAD_XML_DESCR', 'ua', 'Опис віджета не розібрано: невірна розмітка XML.'),
  ('ERR_CANT_COPY_FILE', 'ru', 'Не удалось скопировать файл.'), ('ERR_CANT_COPY_FILE', 'ua', 'Не вдалося скопіювати файл.'),
  ('ERR_CANT_CREATE_DIR', 'ru', 'Не удалось создать папку.'), ('ERR_CANT_CREATE_DIR', 'ua', 'Не вдалося створити теку.'),
  ('ERR_DEV_NO_PARAM', 'ru', 'Компоненту передан неизвестный параметр.'), ('ERR_DEV_NO_PARAM', 'ua', 'Компоненту передано невідомий параметр.'),
  ('ERR_DUPLICATE_LOGIN', 'ru', 'Пользователь с таким e-mail уже зарегистрирован.'), ('ERR_DUPLICATE_LOGIN', 'ua', 'Користувач з таким e-mail вже зареєстрований.'),
  ('ERR_FAKE', 'ru', 'Файл не прошёл проверку.'), ('ERR_FAKE', 'ua', 'Файл не пройшов перевірку.'),
  ('ERR_INCORRECT_MIME', 'ru', 'Недопустимый тип файла.'), ('ERR_INCORRECT_MIME', 'ua', 'Неприпустимий тип файлу.'),
  ('ERR_INSUFFICIENT_DATA', 'ru', 'Недостаточно данных для выполнения запроса.'), ('ERR_INSUFFICIENT_DATA', 'ua', 'Недостатньо даних для виконання запиту.'),
  ('ERR_INVALID_UPL_PATH', 'ru', 'Неверный путь в репозитории файлов.'), ('ERR_INVALID_UPL_PATH', 'ua', 'Невірний шлях у репозиторії файлів.'),
  ('ERR_MISSING_ALTS_FTP_CONFIG', 'ru', 'Не настроен FTP-доступ к альтернативному хранилищу.'), ('ERR_MISSING_ALTS_FTP_CONFIG', 'ua', 'Не налаштовано FTP-доступ до альтернативного сховища.'),
  ('ERR_MISSING_MEDIA_FTP_CONFIG', 'ru', 'Не настроен FTP-доступ к медиа-хранилищу.'), ('ERR_MISSING_MEDIA_FTP_CONFIG', 'ua', 'Не налаштовано FTP-доступ до медіа-сховища.'),
  ('ERR_NOT_USED', 'ru', 'Действие не поддерживается этим репозиторием.'), ('ERR_NOT_USED', 'ua', 'Дія не підтримується цим репозиторієм.'),
  ('ERR_NO_MODIFICATION', 'ru', 'Этот набор данных изменять нельзя.'), ('ERR_NO_MODIFICATION', 'ua', 'Цей набір даних змінювати не можна.'),
  ('ERR_PROPERTY_EXIST', 'ru', 'Свойство с таким именем уже есть.'), ('ERR_PROPERTY_EXIST', 'ua', 'Властивість з такою назвою вже є.'),
  ('ERR_READ_ONLY_FTP_REPO', 'ru', 'Репозиторий доступен только для чтения.'), ('ERR_READ_ONLY_FTP_REPO', 'ua', 'Репозиторій доступний лише для читання.'),
  ('ERR_SAVE_FILE', 'ru', 'Не удалось сохранить файл.'), ('ERR_SAVE_FILE', 'ua', 'Не вдалося зберегти файл.'),
  ('ERR_UNIMPLEMENTED_YET', 'ru', 'Действие для этого репозитория не реализовано.'), ('ERR_UNIMPLEMENTED_YET', 'ua', 'Дію для цього репозиторію не реалізовано.'),
  ('ERR_USER_EXISTS', 'ru', 'Такой пользователь уже существует.'), ('ERR_USER_EXISTS', 'ua', 'Такий користувач уже існує.'),
  ('ERR_WRONG_FIELD_ID', 'ru', 'Поле формы не найдено.'), ('ERR_WRONG_FIELD_ID', 'ua', 'Поле форми не знайдено.'),
  ('FIELD_ALIGN', 'ru', 'Выравнивание'), ('FIELD_ALIGN', 'ua', 'Вирівнювання'),
  ('FIELD_ALT', 'ru', 'Альтернативный текст'), ('FIELD_ALT', 'ua', 'Альтернативний текст'),
  ('FIELD_AL_ACTION', 'ru', 'Действие'), ('FIELD_AL_ACTION', 'ua', 'Дія'),
  ('FIELD_AL_CLASSNAME', 'ru', 'Компонент'), ('FIELD_AL_CLASSNAME', 'ua', 'Компонент'),
  ('FIELD_AL_DATE', 'ru', 'Дата'), ('FIELD_AL_DATE', 'ua', 'Дата'),
  ('FIELD_AL_ID', 'ru', 'Запись журнала'), ('FIELD_AL_ID', 'ua', 'Запис журналу'),
  ('FIELD_ATTACHEDFILES', 'ru', 'Вложения'), ('FIELD_ATTACHEDFILES', 'ua', 'Вкладення'),
  ('FIELD_COMMENTS_NUM', 'ru', 'Комментариев'), ('FIELD_COMMENTS_NUM', 'ua', 'Коментарів'),
  ('FIELD_COMMENT_ID', 'ru', 'Комментарий'), ('FIELD_COMMENT_ID', 'ua', 'Коментар'),
  ('FIELD_CONTENT_FILE_TITLE', 'ru', 'Шаблон содержимого'), ('FIELD_CONTENT_FILE_TITLE', 'ua', 'Шаблон вмісту'),
  ('FIELD_DESCRIPTIONRTF', 'ru', 'Описание'), ('FIELD_DESCRIPTIONRTF', 'ua', 'Опис'),
  ('FIELD_DOMAIN_ID', 'ru', 'Домен'), ('FIELD_DOMAIN_ID', 'ua', 'Домен'),
  ('FIELD_DOMAIN_URL', 'ru', 'Адрес домена'), ('FIELD_DOMAIN_URL', 'ua', 'Адреса домену'),
  ('FIELD_FEED_ID', 'ru', 'Сообщение'), ('FIELD_FEED_ID', 'ua', 'Повідомлення'),
  ('FIELD_FILENAME', 'ru', 'Имя файла'), ('FIELD_FILENAME', 'ua', 'Назва файлу'),
  ('FIELD_HTML', 'ru', 'HTML-код'), ('FIELD_HTML', 'ua', 'HTML-код'),
  ('FIELD_LANG_ID', 'ru', 'Язык'), ('FIELD_LANG_ID', 'ua', 'Мова'),
  ('FIELD_LANG_LOCALE', 'ru', 'Локаль'), ('FIELD_LANG_LOCALE', 'ua', 'Локаль'),
  ('FIELD_LTAG_ID', 'ru', 'Константа'), ('FIELD_LTAG_ID', 'ua', 'Константа'),
  ('FIELD_NEWS_ID', 'ru', 'Новость'), ('FIELD_NEWS_ID', 'ua', 'Новина'),
  ('FIELD_PAGE_RIGHTS', 'ru', 'Права доступа'), ('FIELD_PAGE_RIGHTS', 'ua', 'Права доступу'),
  ('FIELD_PID', 'ru', 'Родительский раздел'), ('FIELD_PID', 'ua', 'Батьківський розділ'),
  ('FIELD_PROP_ID', 'ru', 'Свойство'), ('FIELD_PROP_ID', 'ua', 'Властивість'),
  ('FIELD_PROP_IS_DEFAULT', 'ru', 'Значение по умолчанию'), ('FIELD_PROP_IS_DEFAULT', 'ua', 'Значення за замовчуванням'),
  ('FIELD_PROP_NAME', 'ru', 'Название свойства'), ('FIELD_PROP_NAME', 'ua', 'Назва властивості'),
  ('FIELD_PROP_VALUE', 'ru', 'Значение'), ('FIELD_PROP_VALUE', 'ua', 'Значення'),
  ('FIELD_RESTORE_PASSWORD_RESULT', 'ru', 'Результат'), ('FIELD_RESTORE_PASSWORD_RESULT', 'ua', 'Результат'),
  ('FIELD_RESULT', 'ru', 'Результат'), ('FIELD_RESULT', 'ua', 'Результат'),
  ('FIELD_SEGMENT', 'ru', 'Сегмент URL'), ('FIELD_SEGMENT', 'ua', 'Сегмент URL'),
  ('FIELD_SESSION_ID', 'ru', 'Сессия'), ('FIELD_SESSION_ID', 'ua', 'Сесія'),
  ('FIELD_SMAP_TITLE', 'ru', 'Заголовок страницы'), ('FIELD_SMAP_TITLE', 'ua', 'Заголовок сторінки'),
  ('FIELD_TAG_CODE', 'ru', 'Код тега'), ('FIELD_TAG_CODE', 'ua', 'Код тега'),
  ('FIELD_TAG_ID', 'ru', 'Тег'), ('FIELD_TAG_ID', 'ua', 'Тег'),
  ('FIELD_TAG_NAME', 'ru', 'Название тега'), ('FIELD_TAG_NAME', 'ua', 'Назва тега'),
  ('FIELD_TG_ID', 'ru', 'Группа подборок'), ('FIELD_TG_ID', 'ua', 'Група добірок'),
  ('FIELD_TG_NAME', 'ru', 'Название группы'), ('FIELD_TG_NAME', 'ua', 'Назва групи'),
  ('FIELD_TOP_ID', 'ru', 'Позиция подборки'), ('FIELD_TOP_ID', 'ua', 'Позиція добірки'),
  ('FIELD_TOP_IS_ACTIVE', 'ru', 'Активна'), ('FIELD_TOP_IS_ACTIVE', 'ua', 'Активна'),
  ('FIELD_TOP_LINK', 'ru', 'Ссылка'), ('FIELD_TOP_LINK', 'ua', 'Посилання'),
  ('FIELD_TOP_NAME', 'ru', 'Название'), ('FIELD_TOP_NAME', 'ua', 'Назва'),
  ('FIELD_TOP_TEXT_RTF', 'ru', 'Описание'), ('FIELD_TOP_TEXT_RTF', 'ua', 'Опис'),
  ('FIELD_UPL_ALLOWS_CREATE_DIR', 'ru', 'Можно создавать папки'), ('FIELD_UPL_ALLOWS_CREATE_DIR', 'ua', 'Можна створювати теки'),
  ('FIELD_UPL_ALLOWS_DELETE_DIR', 'ru', 'Можно удалять папки'), ('FIELD_UPL_ALLOWS_DELETE_DIR', 'ua', 'Можна видаляти теки'),
  ('FIELD_UPL_ALLOWS_DELETE_FILE', 'ru', 'Можно удалять файлы'), ('FIELD_UPL_ALLOWS_DELETE_FILE', 'ua', 'Можна видаляти файли'),
  ('FIELD_UPL_ALLOWS_EDIT_DIR', 'ru', 'Можно править папки'), ('FIELD_UPL_ALLOWS_EDIT_DIR', 'ua', 'Можна редагувати теки'),
  ('FIELD_UPL_ALLOWS_EDIT_FILE', 'ru', 'Можно править файлы'), ('FIELD_UPL_ALLOWS_EDIT_FILE', 'ua', 'Можна редагувати файли'),
  ('FIELD_UPL_ALLOWS_UPLOAD_FILE', 'ru', 'Можно загружать файлы'), ('FIELD_UPL_ALLOWS_UPLOAD_FILE', 'ua', 'Можна завантажувати файли'),
  ('FIELD_UPL_CHILDS_COUNT', 'ru', 'Вложений'), ('FIELD_UPL_CHILDS_COUNT', 'ua', 'Вкладень'),
  ('FIELD_UPL_DURATION', 'ru', 'Длительность'), ('FIELD_UPL_DURATION', 'ua', 'Тривалість'),
  ('FIELD_UPL_FILENAME', 'ru', 'Имя файла'), ('FIELD_UPL_FILENAME', 'ua', 'Назва файлу'),
  ('FIELD_UPL_ID', 'ru', 'Файл'), ('FIELD_UPL_ID', 'ua', 'Файл'),
  ('FIELD_UPL_INTERNAL_TYPE', 'ru', 'Тип записи'), ('FIELD_UPL_INTERNAL_TYPE', 'ua', 'Тип запису'),
  ('FIELD_UPL_IS_FLV', 'ru', 'Есть версия FLV'), ('FIELD_UPL_IS_FLV', 'ua', 'Є версія FLV'),
  ('FIELD_UPL_IS_MP4', 'ru', 'Есть версия MP4'), ('FIELD_UPL_IS_MP4', 'ua', 'Є версія MP4'),
  ('FIELD_UPL_IS_WEBM', 'ru', 'Есть версия WebM'), ('FIELD_UPL_IS_WEBM', 'ua', 'Є версія WebM'),
  ('FIELD_UPL_PID', 'ru', 'Папка'), ('FIELD_UPL_PID', 'ua', 'Тека'),
  ('FIELD_UPL_PROPERTIES', 'ru', 'Свойства файла'), ('FIELD_UPL_PROPERTIES', 'ua', 'Властивості файлу'),
  ('FIELD_VOTE_QUESTION_ID', 'ru', 'Вопрос'), ('FIELD_VOTE_QUESTION_ID', 'ua', 'Питання'),
  ('FIELD_WIDGET_ID', 'ru', 'Виджет'), ('FIELD_WIDGET_ID', 'ua', 'Віджет'),
  ('MSG_BAD_INT_FORMAT', 'ru', 'Нужно целое число.'), ('MSG_BAD_INT_FORMAT', 'ua', 'Потрібне ціле число.'),
  ('MSG_BAD_INT_FORMAT_OR_NULL', 'ru', 'Нужно целое число или пустое значение.'), ('MSG_BAD_INT_FORMAT_OR_NULL', 'ua', 'Потрібне ціле число або порожнє значення.'),
  ('MSG_BAD_LANG_ABBR', 'ru', 'Код языка — две латинские буквы.'), ('MSG_BAD_LANG_ABBR', 'ua', 'Код мови — дві латинські літери.'),
  ('MSG_BAD_MONEY_FORMAT', 'ru', 'Неверный формат суммы.'), ('MSG_BAD_MONEY_FORMAT', 'ua', 'Невірний формат суми.'),
  ('MSG_WRONG_DATETIME_FORMAT', 'ru', 'Неверный формат даты и времени, нужен ГГГГ-ММ-ДД ЧЧ:ММ.'), ('MSG_WRONG_DATETIME_FORMAT', 'ua', 'Невірний формат дати й часу, потрібен РРРР-ММ-ДД ГГ:ХХ.'),
  ('MSG_WRONG_TIME_FORMAT', 'ru', 'Неверный формат времени, нужен ЧЧ:ММ.'), ('MSG_WRONG_TIME_FORMAT', 'ua', 'Невірний формат часу, потрібен ГГ:ХХ.'),
  ('TXT_ACTIONSLIST', 'ru', 'Журнал действий'), ('TXT_ACTIONSLIST', 'ua', 'Журнал дій'),
  ('TXT_AND', 'ru', 'и'), ('TXT_AND', 'ua', 'та'),
  ('TXT_CHANGE_PASSWORD', 'ru', 'Смена пароля'), ('TXT_CHANGE_PASSWORD', 'ua', 'Зміна пароля'),
  ('TXT_COMMENT_NICK_IS_REQUIRED', 'ru', 'Укажите имя.'), ('TXT_COMMENT_NICK_IS_REQUIRED', 'ua', 'Вкажіть ім’я.'),
  ('TXT_ERROR_NOT_VIDEO_FILE', 'ru', 'Это не видеофайл.'), ('TXT_ERROR_NOT_VIDEO_FILE', 'ua', 'Це не відеофайл.'),
  ('TXT_FILE_SIZE', 'ru', 'Размер файла'), ('TXT_FILE_SIZE', 'ua', 'Розмір файлу'),
  ('TXT_FILTER_SIGN_CHECKED', 'ru', 'отмечено'), ('TXT_FILTER_SIGN_CHECKED', 'ua', 'позначено'),
  ('TXT_FILTER_SIGN_UNCHECKED', 'ru', 'не отмечено'), ('TXT_FILTER_SIGN_UNCHECKED', 'ua', 'не позначено'),
  ('TXT_LOGIN_AVAILABLE', 'ru', 'Логин свободен.'), ('TXT_LOGIN_AVAILABLE', 'ua', 'Логін вільний.'),
  ('TXT_REVERT_CONTENT', 'ru', 'Вернуться к шаблону ядра'), ('TXT_REVERT_CONTENT', 'ua', 'Повернутися до шаблону ядра'),
  ('TXT_USER_PROFILE_EDIT', 'ru', 'Редактирование профиля'), ('TXT_USER_PROFILE_EDIT', 'ua', 'Редагування профілю'),
  ('TXT_WIDGETSREPOSITORY', 'ru', 'Репозиторий виджетов'), ('TXT_WIDGETSREPOSITORY', 'ua', 'Репозиторій віджетів');
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) SELECT DISTINCT `name` FROM `tmp_label_translations`;
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`, x.`value`
    FROM `tmp_label_translations` x
    JOIN `share_lang_tags` t ON t.`ltag_name` = x.`name`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`;
DROP TEMPORARY TABLE `tmp_label_translations`;

SET FOREIGN_KEY_CHECKS=1;
