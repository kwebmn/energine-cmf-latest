-- Energine Simple, удобство, этап 3 (docs/superpowers/plans/2026-10-05-energine-simple-c3-owner.md). Переход базы после
-- sql/cut/stage12.sql. Повторный запуск ничего не меняет.
--   mariadb БАЗА < sql/cut/stage13.sql

-- 1. Страница админки «Битые ссылки» (/admin/links/): только администраторам, последней в меню админки. Номер строки
--    задан явно — как в файлах установки (fresh-check сверяет площадку с установкой).
INSERT INTO `share_sitemap` (`smap_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_in_menu`, `smap_order_num`)
    SELECT 3726, 'default.layout.xml', 'broken_links.content.xml', a.`smap_id`, 'links', 1,
           (SELECT IFNULL(MAX(c.`smap_order_num`), 0) + 1 FROM `share_sitemap` c WHERE c.`smap_pid` = a.`smap_id`)
      FROM `share_sitemap` a JOIN `share_sitemap` r ON r.`smap_id` = a.`smap_pid` AND r.`smap_pid` IS NULL
     WHERE a.`smap_segment` = 'admin'
       AND NOT EXISTS (SELECT 1 FROM `share_sitemap` x WHERE x.`smap_pid` = a.`smap_id` AND x.`smap_segment` = 'links');
SET @links = (SELECT s.`smap_id` FROM `share_sitemap` s JOIN `share_sitemap` a ON a.`smap_id` = s.`smap_pid` AND a.`smap_segment` = 'admin'
              JOIN `share_sitemap` r ON r.`smap_id` = a.`smap_pid` AND r.`smap_pid` IS NULL WHERE s.`smap_segment` = 'links');
INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
    SELECT @links, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Биті посилання', 'Битые ссылки'), 0 FROM `share_languages` l;
-- права — как у журнала действий (только администраторы)
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
    SELECT @links, a.`group_id`, a.`right_id` FROM `share_access_level` a JOIN `share_sitemap` s USING (`smap_id`)
     WHERE s.`smap_segment` = 'action-log';

-- 2. Переводы страницы «Битые ссылки».
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_BROKEN_LINKS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Биті посилання', 'Битые ссылки')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'CONTENT_BROKEN_LINKS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_HINT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання в текстах сторінок, що ведуть на неіснуючі або вимкнені сторінки та відсутні файли. Зовнішні сайти не перевіряються. Виправте посилання в тексті сторінки в режимі редагування.', 'Ссылки в текстах страниц, которые ведут на несуществующие или отключённые страницы и отсутствующие файлы. Внешние сайты не проверяются. Исправьте ссылку в тексте страницы в режиме редактирования.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_HINT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NONE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Битих посилань немає', 'Битых ссылок нет')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NONE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_MEMBERS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання на сторінки лише для тих, хто увійшов (гостю не відкриються)', 'Ссылки на страницы только для вошедших (гостю не откроются)')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_MEMBERS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_PAGE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сторінка', 'Страница')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_PAGE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_LANG');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Мова', 'Язык')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_LANG';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_LINK');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Посилання', 'Ссылка')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_LINK';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_REASON');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Причина', 'Причина')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_REASON';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NO_PAGE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Немає сторінки', 'Нет страницы')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NO_PAGE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_NO_FILE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Немає файлу', 'Нет файла')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_NO_FILE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_DISABLED');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Сторінку вимкнено', 'Страница отключена')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_DISABLED';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_OUTSIDE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Поза сайтом', 'Вне сайта')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_OUTSIDE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_LINKS_MEMBERS_ONLY');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Лише для тих, хто увійшов', 'Только для вошедших')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_LINKS_MEMBERS_ONLY';

-- 3. Подсказки «?» экранов админки: HELP_<КЛАСС>_<СОСТОЯНИЕ> (Component::build), текст — без разметки.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_HELP');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Підказка', 'Подсказка')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'TXT_HELP';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_DIVISIONEDITOR_EDIT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Властивості сторінки. «Назва» — пункт меню та крихт; «Сегмент URI» — частина адреси; «Вміст сторінки» — шаблон (лендінг, послуга, контакти, текст). Вкладки мов — тексти кожною мовою. Збережіть кнопкою «Зберегти»; тексти самої сторінки редагуються на ній у режимі редагування.', 'Свойства страницы. «Название» — пункт меню и крошек; «Сегмент URI» — часть адреса; «Содержимое страницы» — шаблон (лендинг, услуга, контакты, текст). Вкладки языков — тексты на каждом языке. Сохраните кнопкой «Сохранить»; тексты самой страницы правятся на ней в режиме редактирования.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_DIVISIONEDITOR_EDIT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_DIVISIONEDITOR_ADD');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Нова сторінка. Заповніть «Назву» кожною мовою та «Сегмент URI» (латиниця, цифри, дефіс), оберіть «Вміст сторінки» — шаблон. Порожні секції шаблону покажуть приклад тексту в режимі редагування.', 'Новая страница. Заполните «Название» на каждом языке и «Сегмент URI» (латиница, цифры, дефис), выберите «Содержимое страницы» — шаблон. Пустые секции шаблона покажут пример текста в режиме редактирования.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_DIVISIONEDITOR_ADD';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_USEREDITOR_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Користувачі сайту. Рядок виділяють клацанням; «Редагувати» відкриває форму, «Активувати» вмикає відвідувача, який зареєструвався, але не підтвердив адресу. Фільтр над таблицею шукає за колонкою.', 'Пользователи сайта. Строку выделяют щелчком; «Редактировать» открывает форму, «Активизировать» включает посетителя, зарегистрированного, но не подтвердившего адрес. Фильтр над таблицей ищет по колонке.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_USEREDITOR_MAIN';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_USEREDITOR_EDIT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Дані користувача. E-mail — логін для входу; пароль змінюється, лише якщо ввести новий. На вкладці «Групи» — права: адміністратор бачить адмінку.', 'Данные пользователя. E-mail — логин для входа; пароль меняется, только если ввести новый. На вкладке «Группы» — права: администратор видит админку.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_USEREDITOR_EDIT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_USEREDITOR_ADD');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Новий користувач: e-mail (логін), пароль, імя; на вкладці «Групи» — права.', 'Новый пользователь: e-mail (логин), пароль, имя; на вкладке «Группы» — права.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_USEREDITOR_ADD';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_FILEREPOSITORY_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Файли сайту: зображення та документи для текстів. Подвійне клацання відкриває теку, «Додати» завантажує файл. Вставити зображення в текст — кнопка «Зображення» редактора на сторінці.', 'Файлы сайта: картинки и документы для текстов. Двойной щелчок открывает папку, «Добавить» загружает файл. Вставить картинку в текст — кнопка «Изображение» редактора на странице.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_FILEREPOSITORY_MAIN';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_TRANSLATIONEDITOR_MAIN');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Підписи інтерфейсу всіма мовами (кнопки, поля, повідомлення). Знайдіть константу фільтром, «Редагувати» — змінити текст. Назву константи змінювати не потрібно.', 'Подписи интерфейса на всех языках (кнопки, поля, сообщения). Найдите константу фильтром, «Редактировать» — поменять текст. Название константы менять не нужно.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_TRANSLATIONEDITOR_MAIN';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_SITESETTINGS_EDIT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Налаштування сайту: назва, ключові слова та опис для пошуковиків за замовчуванням, прапорці robots (NOINDEX закриває весь сайт від пошуковиків).', 'Настройки сайта: название, ключевые слова и описание для поисковиков по умолчанию, флажки robots (NOINDEX закрывает весь сайт от поисковиков).')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_SITESETTINGS_EDIT';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('HELP_MAILTEMPLATEEDITOR_EDIT');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Шаблон листа: тема та текст. Слова у квадратних дужках ([user_name], [site_name] …) підставляються під час надсилання — їх не видаляйте.', 'Шаблон письма: тема и текст. Слова в квадратных скобках ([user_name], [site_name] …) подставляются при отправке — их не удаляйте.')
      FROM `share_lang_tags` t JOIN `share_languages` l WHERE t.`ltag_name` = 'HELP_MAILTEMPLATEEDITOR_EDIT';
