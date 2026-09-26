-- Данные модулей mail, ads, blog и shop: теги, переводы интерфейса, шаблоны писем, справочники магазина,
-- виджет баннера и страницы сайта и админки. Демо-контента (товаров, блогов, баннеров) нет.
-- Импортировать после modules.structure.sql. Повторный запуск ничего не дублирует и не перезаписывает:
-- INSERT IGNORE и проверки NOT EXISTS; языки ищутся по share_languages.lang_abbr ('ru', 'ua').

SET NAMES utf8;

-- =============================================================================================
-- 1. Теги и привязка сайта
-- =============================================================================================
-- shop      — сайт-магазин: SiteManager::getSitesByTag('shop') в редакторах товаров, категорий, характеристик,
--             производителей, заказов и баннеров (без сайта с тегом формы не открываются);
-- ads       — корень рубрик баннеров (параметр rootTag редактора баннеров);
-- catalogue — корень каталога: категории товаров — разделы под этой страницей.
-- TagManager::getID() ищет тег по названию на текущем языке, поэтому перевод нужен на всех языках;
-- без тега Sitemap::getPagesByTag() падает с TypeError.
INSERT IGNORE INTO `share_tags` (`tag_code`) VALUES ('shop'), ('ads'), ('catalogue');
INSERT IGNORE INTO `share_tags_translation` (`tag_id`, `lang_id`, `tag_name`)
  SELECT t.`tag_id`, l.`lang_id`, t.`tag_code`
    FROM `share_tags` t
    CROSS JOIN `share_languages` l
   WHERE t.`tag_code` IN ('shop', 'ads', 'catalogue');

-- Сайт по умолчанию становится магазином.
INSERT IGNORE INTO `share_sites_tags` (`site_id`, `tag_id`)
  SELECT s.`site_id`, t.`tag_id`
    FROM `share_sites` s
    JOIN `share_tags` t ON t.`tag_code` = 'shop'
   WHERE s.`site_is_default` = 1;

-- Роли с полным доступом к корню сайта-магазина управляют этим магазином (User::getSites()).
INSERT IGNORE INTO `share_groups2sites` (`group_id`, `site_id`)
  SELECT DISTINCT al.`group_id`, sm.`site_id`
    FROM `share_sites_tags` st
    JOIN `share_tags` t ON t.`tag_id` = st.`tag_id` AND t.`tag_code` = 'shop'
    JOIN `share_sitemap` sm ON sm.`site_id` = st.`site_id` AND sm.`smap_pid` IS NULL
    JOIN `share_access_level` al ON al.`smap_id` = sm.`smap_id`
    JOIN `user_group_rights` r ON r.`right_id` = al.`right_id` AND r.`right_const` = 'ACCESS_FULL';

-- Макрос [site_name] в письме о регистрации — константа TXT_SITE_NAME, берётся из названия сайта.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SITE_NAME');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, st.`lang_id`, st.`site_name`
    FROM `share_lang_tags` t
    JOIN `share_sites` s ON s.`site_is_default` = 1
    JOIN `share_sites_translation` st ON st.`site_id` = s.`site_id`
    JOIN `share_languages` l ON l.`lang_id` = st.`lang_id` AND l.`lang_abbr` IN ('ru', 'ua')
   WHERE t.`ltag_name` = 'TXT_SITE_NAME';

-- Отказ при загрузке файла, который веб-сервер выполнил бы как программу.
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('ERR_EXECUTABLE_FILE_TYPE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`,
         IF(l.`lang_abbr` = 'ua',
            'Файли цього типу завантажувати не можна: сервер виконає їх як програму',
            'Файлы этого типа загружать нельзя: сервер выполнит их как программу')
    FROM `share_lang_tags` t
    CROSS JOIN `share_languages` l
   WHERE t.`ltag_name` = 'ERR_EXECUTABLE_FILE_TYPE';

-- =============================================================================================
-- 2. Переводы интерфейса, которых нет в дампе стартера
-- =============================================================================================
-- Правила имён: FIELD_<КОЛОНКА>, FIELD_<КОЛОНКА>_ENUM_<ЗНАЧЕНИЕ>, заголовок грида — TXT_<ИМЯ КОМПОНЕНТА>,
-- вкладки — TAB_*, шаблоны содержимого в редакторе разделов — CONTENT_<ФАЙЛ>. Существующие переводы не меняются.
CREATE TEMPORARY TABLE `tmp_module_translations` (`name` varchar(70) NOT NULL, `abbr` char(2) NOT NULL, `value` text NOT NULL) DEFAULT CHARSET=utf8;
INSERT INTO `tmp_module_translations` VALUES
  -- общие кнопки и ошибки редакторов
  ('BTN_USE', 'ru', 'Использовать'), ('BTN_USE', 'ua', 'Використати'),
  ('BTN_MOVE_FIRST', 'ru', 'В начало'), ('BTN_MOVE_FIRST', 'ua', 'На початок'),
  ('BTN_MOVE_LAST', 'ru', 'В конец'), ('BTN_MOVE_LAST', 'ua', 'В кінець'),
  ('BTN_MOVE_ABOVE', 'ru', 'Выше выбранного'), ('BTN_MOVE_ABOVE', 'ua', 'Вище за обраний'),
  ('BTN_MOVE_BELOW', 'ru', 'Ниже выбранного'), ('BTN_MOVE_BELOW', 'ua', 'Нижче за обраний'),
  ('ERR_NO_DATA', 'ru', 'Нет данных'), ('ERR_NO_DATA', 'ua', 'Немає даних'),

  -- mail: редакторы и вкладки
  ('TXT_MAIL_TEMPLATES_EDITOR', 'ru', 'Шаблоны писем'), ('TXT_MAIL_TEMPLATES_EDITOR', 'ua', 'Шаблони листів'),
  ('TXT_MAIL_SUBSCRIPTION_EDITOR', 'ru', 'Рассылки'), ('TXT_MAIL_SUBSCRIPTION_EDITOR', 'ua', 'Розсилки'),
  ('TXT_MAILSUBSCRIPTIONEDITOR', 'ru', 'Подписчики по e-mail'), ('TXT_MAILSUBSCRIPTIONEDITOR', 'ua', 'Підписники за e-mail'),
  ('TXT_MAILCRMEDITOR', 'ru', 'Выпуски CRM-рассылки'), ('TXT_MAILCRMEDITOR', 'ua', 'Випуски CRM-розсилки'),
  ('TAB_SUBSCRIBED_USERS', 'ru', 'Подписанные пользователи'), ('TAB_SUBSCRIBED_USERS', 'ua', 'Підписані користувачі'),
  ('TAB_SUBSCRIBED_EMAILS', 'ru', 'Подписанные e-mail'), ('TAB_SUBSCRIBED_EMAILS', 'ua', 'Підписані e-mail'),
  -- mail: шаблоны писем
  ('FIELD_TEMPLATE_SYSNAME', 'ru', 'Системное имя'), ('FIELD_TEMPLATE_SYSNAME', 'ua', 'Системне ім''я'),
  ('FIELD_TEMPLATE_NAME', 'ru', 'Название шаблона'), ('FIELD_TEMPLATE_NAME', 'ua', 'Назва шаблону'),
  ('FIELD_TEMPLATE_SUBJECT', 'ru', 'Тема письма'), ('FIELD_TEMPLATE_SUBJECT', 'ua', 'Тема листа'),
  ('FIELD_TEMPLATE_BODY', 'ru', 'Текст письма (plain text)'), ('FIELD_TEMPLATE_BODY', 'ua', 'Текст листа (plain text)'),
  ('FIELD_TEMPLATE_BODY_RTF', 'ru', 'Текст письма (HTML)'), ('FIELD_TEMPLATE_BODY_RTF', 'ua', 'Текст листа (HTML)'),
  ('FIELD_TEMPLATE_HINTS', 'ru', 'Подсказки (доступные макросы)'), ('FIELD_TEMPLATE_HINTS', 'ua', 'Підказки (доступні макроси)'),
  ('FIELD_TEMPLATE_IS_ACTIVE', 'ru', 'Шаблон активен'), ('FIELD_TEMPLATE_IS_ACTIVE', 'ua', 'Шаблон активний'),
  -- mail: рассылки
  ('FIELD_SUBSCRIPTION_ID', 'ru', 'Рассылка'), ('FIELD_SUBSCRIPTION_ID', 'ua', 'Розсилка'),
  ('FIELD_SUBSCRIPTION_NAME', 'ru', 'Название рассылки'), ('FIELD_SUBSCRIPTION_NAME', 'ua', 'Назва розсилки'),
  ('FIELD_SUBSCRIPTION_DESCRIPTION', 'ru', 'Описание рассылки'), ('FIELD_SUBSCRIPTION_DESCRIPTION', 'ua', 'Опис розсилки'),
  ('FIELD_SUBSCRIPTION_TYPE', 'ru', 'Источник данных'), ('FIELD_SUBSCRIPTION_TYPE', 'ua', 'Джерело даних'),
  ('FIELD_SUBSCRIPTION_TYPE_ENUM_NEWS', 'ru', 'Новости'), ('FIELD_SUBSCRIPTION_TYPE_ENUM_NEWS', 'ua', 'Новини'),
  ('FIELD_SUBSCRIPTION_TYPE_ENUM_CRM', 'ru', 'CRM-рассылка'), ('FIELD_SUBSCRIPTION_TYPE_ENUM_CRM', 'ua', 'CRM-розсилка'),
  ('FIELD_SUBSCRIPTION_PERIOD', 'ru', 'Периодичность'), ('FIELD_SUBSCRIPTION_PERIOD', 'ua', 'Періодичність'),
  ('FIELD_SUBSCRIPTION_PERIOD_ENUM_HOURLY', 'ru', 'Ежечасно'), ('FIELD_SUBSCRIPTION_PERIOD_ENUM_HOURLY', 'ua', 'Щогодини'),
  ('FIELD_SUBSCRIPTION_PERIOD_ENUM_DAILY', 'ru', 'Ежедневно'), ('FIELD_SUBSCRIPTION_PERIOD_ENUM_DAILY', 'ua', 'Щодня'),
  ('FIELD_SUBSCRIPTION_PERIOD_ENUM_WEEKLY', 'ru', 'Еженедельно'), ('FIELD_SUBSCRIPTION_PERIOD_ENUM_WEEKLY', 'ua', 'Щотижня'),
  ('FIELD_SUBSCRIPTION_PERIOD_ENUM_MONTHLY', 'ru', 'Ежемесячно'), ('FIELD_SUBSCRIPTION_PERIOD_ENUM_MONTHLY', 'ua', 'Щомісяця'),
  ('FIELD_SUBSCRIPTION_SENT_DATE', 'ru', 'Последняя отправка'), ('FIELD_SUBSCRIPTION_SENT_DATE', 'ua', 'Останнє надсилання'),
  ('FIELD_SUBSCRIPTION_IS_ACTIVE', 'ru', 'Рассылка активна'), ('FIELD_SUBSCRIPTION_IS_ACTIVE', 'ua', 'Розсилка активна'),
  ('FIELD_SUBSCRIPTION_IS_DEFAULT', 'ru', 'Подписывать новых подписчиков автоматически'), ('FIELD_SUBSCRIPTION_IS_DEFAULT', 'ua', 'Підписувати нових підписників автоматично'),
  ('FIELD_SUBSCRIPTION_IS_HIDDEN', 'ru', 'Не показывать в списке подписок'), ('FIELD_SUBSCRIPTION_IS_HIDDEN', 'ua', 'Не показувати у списку підписок'),
  -- mail: подписчики по e-mail, сообщения CRM-рассылки
  ('FIELD_ME_ID', 'ru', 'E-mail подписчика'), ('FIELD_ME_ID', 'ua', 'E-mail підписника'),
  ('FIELD_ME_NAME', 'ru', 'E-mail'), ('FIELD_ME_NAME', 'ua', 'E-mail'),
  ('FIELD_ME_DATE', 'ru', 'Дата подписки'), ('FIELD_ME_DATE', 'ua', 'Дата підписки'),
  ('FIELD_CRM_DATE', 'ru', 'Дата выпуска'), ('FIELD_CRM_DATE', 'ua', 'Дата випуску'),
  ('FIELD_CRM_IS_ACTIVE', 'ru', 'Включать в рассылку'), ('FIELD_CRM_IS_ACTIVE', 'ua', 'Включати до розсилки'),
  ('FIELD_CRM_NAME', 'ru', 'Заголовок'), ('FIELD_CRM_NAME', 'ua', 'Заголовок'),
  ('FIELD_CRM_TEXT_RTF', 'ru', 'Текст'), ('FIELD_CRM_TEXT_RTF', 'ua', 'Текст'),
  -- mail: подписка на сайте, сообщения и ошибки
  ('TXT_SUBSCRIBE', 'ru', 'Подписаться'), ('TXT_SUBSCRIBE', 'ua', 'Підписатися'),
  ('MSG_SUBSCRIBED', 'ru', 'Вы подписаны на рассылку'), ('MSG_SUBSCRIBED', 'ua', 'Вас підписано на розсилку'),
  ('TXT_SUBSCRIBED', 'ru', 'Подписка оформлена'), ('TXT_SUBSCRIBED', 'ua', 'Підписку оформлено'),
  ('TXT_UNSUBSCRIBED', 'ru', 'Подписка отменена'), ('TXT_UNSUBSCRIBED', 'ua', 'Підписку скасовано'),
  ('ERR_NO_EMAIL', 'ru', 'Не указан e-mail'), ('ERR_NO_EMAIL', 'ua', 'Не вказано e-mail'),
  ('ERR_BAD_EMAIL', 'ru', 'Неправильный формат e-mail'), ('ERR_BAD_EMAIL', 'ua', 'Неправильний формат e-mail'),
  ('ERR_MAIL_EXISTS', 'ru', 'Этот e-mail уже подписан'), ('ERR_MAIL_EXISTS', 'ua', 'Цей e-mail вже підписано'),
  ('ERR_NO_MAIL_TEMPLATE', 'ru', 'Не найден активный шаблон письма'), ('ERR_NO_MAIL_TEMPLATE', 'ua', 'Не знайдено активного шаблону листа'),
  ('ERR_CANT_DELETE_MAIL_TEMPLATE', 'ru', 'Шаблон письма нельзя удалить, его можно только отключить'), ('ERR_CANT_DELETE_MAIL_TEMPLATE', 'ua', 'Шаблон листа не можна видалити, його можна лише вимкнути'),
  ('TXT_EMAIL_USER', 'ru', 'Подписчик'), ('TXT_EMAIL_USER', 'ua', 'Підписник'),
  -- окончание обращения в письме user_restore_password (user/components/RestorePassword.php)
  ('TXT_EMAIL_SUFFIX_SEX_M', 'ru', 'ый'), ('TXT_EMAIL_SUFFIX_SEX_M', 'ua', 'ий'),
  ('TXT_EMAIL_SUFFIX_SEX_F', 'ru', 'ая'), ('TXT_EMAIL_SUFFIX_SEX_F', 'ua', 'а'),
  ('TXT_EMAIL_SUFFIX_SEX_UNKNOWN', 'ru', 'ый(ая)'), ('TXT_EMAIL_SUFFIX_SEX_UNKNOWN', 'ua', 'ий(а)'),

  -- ads
  ('TXT_ADS_TYPES_EDITOR', 'ru', 'Рекламные места'), ('TXT_ADS_TYPES_EDITOR', 'ua', 'Рекламні місця'),
  ('TXT_ADS_ITEMS_EDITOR', 'ru', 'Баннеры'), ('TXT_ADS_ITEMS_EDITOR', 'ua', 'Банери'),
  ('TXT_ADS_WIDGET', 'ru', 'Баннер'), ('TXT_ADS_WIDGET', 'ua', 'Банер'),
  ('FIELD_ADS_TYPE_ID', 'ru', 'Рекламное место'), ('FIELD_ADS_TYPE_ID', 'ua', 'Рекламне місце'),
  ('FIELD_ADS_TYPE_SYSNAME', 'ru', 'Системное имя'), ('FIELD_ADS_TYPE_SYSNAME', 'ua', 'Системне ім''я'),
  ('FIELD_ADS_TYPE_NAME', 'ru', 'Название места'), ('FIELD_ADS_TYPE_NAME', 'ua', 'Назва місця'),
  ('FIELD_ADS_TYPE_WIDTH', 'ru', 'Ширина, px'), ('FIELD_ADS_TYPE_WIDTH', 'ua', 'Ширина, px'),
  ('FIELD_ADS_TYPE_HEIGHT', 'ru', 'Высота, px'), ('FIELD_ADS_TYPE_HEIGHT', 'ua', 'Висота, px'),
  ('FIELD_ADS_ITEM_NAME', 'ru', 'Название баннера'), ('FIELD_ADS_ITEM_NAME', 'ua', 'Назва банера'),
  ('FIELD_ADS_ITEM_IS_ACTIVE', 'ru', 'Показывать'), ('FIELD_ADS_ITEM_IS_ACTIVE', 'ua', 'Показувати'),
  ('FIELD_ADS_ITEM_MODE', 'ru', 'Тип баннера'), ('FIELD_ADS_ITEM_MODE', 'ua', 'Тип банера'),
  ('FIELD_ADS_ITEM_MODE_ENUM_IMAGE', 'ru', 'Изображение со ссылкой'), ('FIELD_ADS_ITEM_MODE_ENUM_IMAGE', 'ua', 'Зображення з посиланням'),
  ('FIELD_ADS_ITEM_MODE_ENUM_HTML', 'ru', 'HTML-код'), ('FIELD_ADS_ITEM_MODE_ENUM_HTML', 'ua', 'HTML-код'),
  ('FIELD_ADS_ITEM_IMG', 'ru', 'Изображение'), ('FIELD_ADS_ITEM_IMG', 'ua', 'Зображення'),
  ('FIELD_ADS_ITEM_URL', 'ru', 'Ссылка'), ('FIELD_ADS_ITEM_URL', 'ua', 'Посилання'),
  ('FIELD_ADS_ITEM_HTML', 'ru', 'HTML-код баннера'), ('FIELD_ADS_ITEM_HTML', 'ua', 'HTML-код банера'),
  ('FIELD_ADS_ITEM_SITE_MULTI', 'ru', 'Сайты'), ('FIELD_ADS_ITEM_SITE_MULTI', 'ua', 'Сайти'),
  ('FIELD_ADS_ITEM_SMAP_MULTI', 'ru', 'Разделы'), ('FIELD_ADS_ITEM_SMAP_MULTI', 'ua', 'Розділи'),

  -- blog
  ('TXT_BLOG_EDITOR', 'ru', 'Блоги'), ('TXT_BLOG_EDITOR', 'ua', 'Блоги'),
  ('TXT_BLOG_POST_EDITOR', 'ru', 'Записи блогов'), ('TXT_BLOG_POST_EDITOR', 'ua', 'Записи блогів'),
  ('TXT_BLOG_NEW_POST', 'ru', 'Новая запись'), ('TXT_BLOG_NEW_POST', 'ua', 'Новий запис'),
  ('TXT_BLOG_COMMENTS', 'ru', 'Комментарии'), ('TXT_BLOG_COMMENTS', 'ua', 'Коментарі'),
  ('TXT_BLOG_EMPTY', 'ru', 'Записей пока нет'), ('TXT_BLOG_EMPTY', 'ua', 'Записів поки немає'),
  ('TXT_BLOG_ALL_POSTS', 'ru', 'Все записи'), ('TXT_BLOG_ALL_POSTS', 'ua', 'Усі записи'),
  ('FIELD_BLOG_ID', 'ru', 'Блог'), ('FIELD_BLOG_ID', 'ua', 'Блог'),
  ('FIELD_BLOG_NAME', 'ru', 'Название блога'), ('FIELD_BLOG_NAME', 'ua', 'Назва блогу'),
  ('FIELD_POST_ID', 'ru', 'Запись'), ('FIELD_POST_ID', 'ua', 'Запис'),
  ('FIELD_POST_CREATED', 'ru', 'Дата публикации'), ('FIELD_POST_CREATED', 'ua', 'Дата публікації'),
  ('FIELD_POST_NAME', 'ru', 'Заголовок записи'), ('FIELD_POST_NAME', 'ua', 'Заголовок запису'),
  ('FIELD_POST_TEXT_RTF', 'ru', 'Текст записи'), ('FIELD_POST_TEXT_RTF', 'ua', 'Текст запису'),
  ('TAB_BLOG_POST_COMMENT', 'ru', 'Комментарии к записям блогов'), ('TAB_BLOG_POST_COMMENT', 'ua', 'Коментарі до записів блогів'),

  -- shop: кнопки, тексты и сообщения компонентов, конфигов и XSLT
  ('BTN_BUY', 'ru', 'Купить'), ('BTN_BUY', 'ua', 'Купити'),
  ('BTN_WISHLIST', 'ru', 'В список желаний'), ('BTN_WISHLIST', 'ua', 'До списку бажань'),
  ('BTN_ORDER', 'ru', 'Оформить заказ'), ('BTN_ORDER', 'ua', 'Оформити замовлення'),
  ('BTN_MOVE_BASKET', 'ru', 'Переместить в корзину'), ('BTN_MOVE_BASKET', 'ua', 'Перемістити до кошика'),
  ('BTN_PROPERTIES', 'ru', 'Свойства'), ('BTN_PROPERTIES', 'ua', 'Властивості'),
  ('BTN_RESET_FILTER', 'ru', 'Сбросить'), ('BTN_RESET_FILTER', 'ua', 'Скинути'),
  ('BTN_SAVE_FILTER', 'ru', 'Сохранить фильтр'), ('BTN_SAVE_FILTER', 'ua', 'Зберегти фільтр'),
  ('SHOW_AS_TILE', 'ru', 'Плиткой'), ('SHOW_AS_TILE', 'ua', 'Плиткою'),
  ('SHOW_AS_LIST', 'ru', 'Списком'), ('SHOW_AS_LIST', 'ua', 'Списком'),
  ('FILTER_PRICE', 'ru', 'Цена'), ('FILTER_PRICE', 'ua', 'Ціна'),
  ('FILTER_PRODUCERS', 'ru', 'Производители'), ('FILTER_PRODUCERS', 'ua', 'Виробники'),
  ('FPV_ORDER_NUM', 'ru', 'Порядок'), ('FPV_ORDER_NUM', 'ua', 'Порядок'),
  ('TAB_GOODS_FEATURES', 'ru', 'Характеристики'), ('TAB_GOODS_FEATURES', 'ua', 'Характеристики'),
  ('TAB_GOODS_RELATIONS', 'ru', 'Связанные товары'), ('TAB_GOODS_RELATIONS', 'ua', 'Пов''язані товари'),
  ('TAB_FEATURE_OPTIONS', 'ru', 'Значения'), ('TAB_FEATURE_OPTIONS', 'ua', 'Значення'),
  ('TAB_ORDER_GOODS', 'ru', 'Товары заказа'), ('TAB_ORDER_GOODS', 'ua', 'Товари замовлення'),
  ('TAB_PROMOTION_GOODS', 'ru', 'Товары акции'), ('TAB_PROMOTION_GOODS', 'ua', 'Товари акції'),
  ('TAB_SITE_LOGO_FILES', 'ru', 'Логотип'), ('TAB_SITE_LOGO_FILES', 'ua', 'Логотип'),
  ('TXT_FEATURES', 'ru', 'Характеристики'), ('TXT_FEATURES', 'ua', 'Характеристики'),
  ('TXT_ALL_FEATURES', 'ru', 'Все характеристики'), ('TXT_ALL_FEATURES', 'ua', 'Усі характеристики'),
  ('TXT_MAIN_FEATURES', 'ru', 'Основные характеристики'), ('TXT_MAIN_FEATURES', 'ua', 'Основні характеристики'),
  ('TXT_DAYS', 'ru', 'дн.'), ('TXT_DAYS', 'ua', 'дн.'),
  ('TXT_SORT', 'ru', 'Сортировка'), ('TXT_SORT', 'ua', 'Сортування'),
  ('TXT_COMPARE', 'ru', 'Сравнение'), ('TXT_COMPARE', 'ua', 'Порівняння'),
  ('TXT_ADD_TO_COMPARE', 'ru', 'Добавить к сравнению'), ('TXT_ADD_TO_COMPARE', 'ua', 'Додати до порівняння'),
  ('TXT_REMOVE_FROM_COMPARE', 'ru', 'Убрать из сравнения'), ('TXT_REMOVE_FROM_COMPARE', 'ua', 'Прибрати з порівняння'),
  ('TXT_COMPARE_WORD_GOODS', 'ru', 'товара'), ('TXT_COMPARE_WORD_GOODS', 'ua', 'товари'),
  ('TXT_COMPARE_WORD_GOODS_MANY', 'ru', 'товаров'), ('TXT_COMPARE_WORD_GOODS_MANY', 'ua', 'товарів'),
  ('TXT_ALL_SEARCH_RESULTS', 'ru', 'Все результаты поиска'), ('TXT_ALL_SEARCH_RESULTS', 'ua', 'Усі результати пошуку'),
  ('TXT_FILTER_LIB', 'ru', 'Сохранённые фильтры'), ('TXT_FILTER_LIB', 'ua', 'Збережені фільтри'),
  ('TXT_EMPTY_SAVED_FILTER', 'ru', 'Сохранённых фильтров нет'), ('TXT_EMPTY_SAVED_FILTER', 'ua', 'Збережених фільтрів немає'),
  ('TXT_TITLE_SAVE_FILTER_FORM', 'ru', 'Сохранение фильтра'), ('TXT_TITLE_SAVE_FILTER_FORM', 'ua', 'Збереження фільтра'),
  ('TXT_SAVE_FILTER_FORM', 'ru', 'Введите название, под которым сохранить текущий фильтр'), ('TXT_SAVE_FILTER_FORM', 'ua', 'Введіть назву, під якою зберегти поточний фільтр'),
  ('TXT_CART', 'ru', 'Корзина'), ('TXT_CART', 'ua', 'Кошик'),
  ('TXT_WISHLIST', 'ru', 'Избранное'), ('TXT_WISHLIST', 'ua', 'Обране'),
  ('TXT_SIMILAR_GOODS', 'ru', 'Похожие товары'), ('TXT_SIMILAR_GOODS', 'ua', 'Схожі товари'),
  ('MSG_BAD_CHECK_FEATURE_NAME', 'ru', 'Укажите название характеристики'), ('MSG_BAD_CHECK_FEATURE_NAME', 'ua', 'Вкажіть назву характеристики'),
  ('MSG_BAD_CHECK_FEATURE_TITLE', 'ru', 'Укажите заголовок характеристики'), ('MSG_BAD_CHECK_FEATURE_TITLE', 'ua', 'Вкажіть заголовок характеристики'),
  ('MSG_BAD_CHECK_GROUP_ID', 'ru', 'Выберите группу характеристик'), ('MSG_BAD_CHECK_GROUP_ID', 'ua', 'Оберіть групу характеристик'),
  ('MSG_ERR_BAD_PLACEHOLDER', 'ru', 'Маска телефона: 10–16 символов из цифр, X, пробела, скобок, точки и дефиса'), ('MSG_ERR_BAD_PLACEHOLDER', 'ua', 'Маска телефону: 10–16 символів із цифр, X, пробілу, дужок, крапки та дефіса'),
  ('ERR_BAD_USER', 'ru', 'Войдите на сайт, чтобы сохранить фильтр'), ('ERR_BAD_USER', 'ua', 'Увійдіть на сайт, щоб зберегти фільтр'),
  ('ERR_NO_FILTER_NAME', 'ru', 'Укажите название фильтра'), ('ERR_NO_FILTER_NAME', 'ua', 'Вкажіть назву фільтра'),
  ('ERR_DUPLICATE_FILTER_NAME', 'ru', 'Фильтр с таким названием уже есть'), ('ERR_DUPLICATE_FILTER_NAME', 'ua', 'Фільтр із такою назвою вже є'),
  ('ERR_DUPLICATE_FILTER_DATA', 'ru', 'Такой фильтр уже сохранён'), ('ERR_DUPLICATE_FILTER_DATA', 'ua', 'Такий фільтр уже збережено'),
  ('ERR_NO_SHOP', 'ru', 'Нет сайта с тегом shop'), ('ERR_NO_SHOP', 'ua', 'Немає сайту з тегом shop'),
  ('ERR_NO_CATALOGUE', 'ru', 'На сайте магазина нет раздела с тегом catalogue'), ('ERR_NO_CATALOGUE', 'ua', 'На сайті магазину немає розділу з тегом catalogue'),
  ('ERR_NO_CURR_DATA', 'ru', 'Нет активных валют'), ('ERR_NO_CURR_DATA', 'ua', 'Немає активних валют'),
  ('ERR_NO_CURRENCY', 'ru', 'Не задана валюта по умолчанию'), ('ERR_NO_CURRENCY', 'ua', 'Не задано валюту за замовчуванням'),
  -- shop: экспорт заказов (OrderEditor)
  ('EXPORT_ORDERS_CAMPAGIN', 'ru', 'Кампания'), ('EXPORT_ORDERS_CAMPAGIN', 'ua', 'Кампанія'),
  ('EXPORT_ORDERS_NOCAMPAGIN', 'ru', 'Без кампании'), ('EXPORT_ORDERS_NOCAMPAGIN', 'ua', 'Без кампанії'),
  ('EXPORT_ORDERS_ORDER', 'ru', 'Заказ'), ('EXPORT_ORDERS_ORDER', 'ua', 'Замовлення'),
  ('EXPORT_ORDERS_UPDATED', 'ru', 'Изменён'), ('EXPORT_ORDERS_UPDATED', 'ua', 'Змінено'),
  ('EXPORT_ORDERS_USER', 'ru', 'Покупатель'), ('EXPORT_ORDERS_USER', 'ua', 'Покупець'),
  ('EXPORT_ORDERS_PHONE', 'ru', 'Телефон'), ('EXPORT_ORDERS_PHONE', 'ua', 'Телефон'),
  ('EXPORT_ORDERS_TOTAL', 'ru', 'Сумма'), ('EXPORT_ORDERS_TOTAL', 'ua', 'Сума'),
  ('EXPORT_ORDERS_DISCOUNT', 'ru', 'Скидка'), ('EXPORT_ORDERS_DISCOUNT', 'ua', 'Знижка'),
  ('EXPORT_ORDERS_PROMOCODE', 'ru', 'Промокод'), ('EXPORT_ORDERS_PROMOCODE', 'ua', 'Промокод'),
  ('EXPORT_ORDERS_STATUS', 'ru', 'Статус'), ('EXPORT_ORDERS_STATUS', 'ua', 'Статус'),
  ('EXPORT_ORDERS_ORDER_NUMBER', 'ru', 'Номер заказа'), ('EXPORT_ORDERS_ORDER_NUMBER', 'ua', 'Номер замовлення'),
  ('EXPORT_ORDERS_ORDER_DATE', 'ru', 'Дата заказа'), ('EXPORT_ORDERS_ORDER_DATE', 'ua', 'Дата замовлення'),
  ('EXPORT_ORDERS_USER_NAME', 'ru', 'Покупатель'), ('EXPORT_ORDERS_USER_NAME', 'ua', 'Покупець'),
  ('EXPORT_ORDERS_PRODUCT_CODE', 'ru', 'Артикул'), ('EXPORT_ORDERS_PRODUCT_CODE', 'ua', 'Артикул'),
  ('EXPORT_ORDERS_PRODUCT_NAME', 'ru', 'Товар'), ('EXPORT_ORDERS_PRODUCT_NAME', 'ua', 'Товар'),
  ('EXPORT_ORDERS_PRODUCT_AMOUNT', 'ru', 'Количество'), ('EXPORT_ORDERS_PRODUCT_AMOUNT', 'ua', 'Кількість'),
  ('EXPORT_ORDERS_PRODUCT_PRICE_PER_ITEM', 'ru', 'Цена за единицу'), ('EXPORT_ORDERS_PRODUCT_PRICE_PER_ITEM', 'ua', 'Ціна за одиницю'),
  ('EXPORT_ORDERS_PRODUCT_ITEM_SUMM_PRICE', 'ru', 'Сумма'), ('EXPORT_ORDERS_PRODUCT_ITEM_SUMM_PRICE', 'ua', 'Сума'),
  ('EXPORT_ORDERS_PRODUCT_SUMM_PRICE', 'ru', 'Итого'), ('EXPORT_ORDERS_PRODUCT_SUMM_PRICE', 'ua', 'Разом'),
  ('EXPORT_ORDERS_PROMOCODE_USED', 'ru', 'Использован промокод'), ('EXPORT_ORDERS_PROMOCODE_USED', 'ua', 'Використано промокод'),
  ('EXPORT_ORDERS_SUMM_DISCOUNT', 'ru', 'Сумма скидки'), ('EXPORT_ORDERS_SUMM_DISCOUNT', 'ua', 'Сума знижки'),
  -- shop: заголовки гридов (TXT_ + имя компонента)
  ('TXT_GOODSEDITOR', 'ru', 'Товары'), ('TXT_GOODSEDITOR', 'ua', 'Товари'),
  ('TXT_RELATIONEDITOR', 'ru', 'Связанные товары'), ('TXT_RELATIONEDITOR', 'ua', 'Пов''язані товари'),
  ('TXT_FEATUREEDITOR', 'ru', 'Характеристики'), ('TXT_FEATUREEDITOR', 'ua', 'Характеристики'),
  ('TXT_OEDITOR', 'ru', 'Элементы'), ('TXT_OEDITOR', 'ua', 'Елементи'),
  ('TXT_FGEDITOR', 'ru', 'Группы характеристик'), ('TXT_FGEDITOR', 'ua', 'Групи характеристик'),
  ('TXT_PRODUCEREDITOR', 'ru', 'Производители'), ('TXT_PRODUCEREDITOR', 'ua', 'Виробники'),
  ('TXT_PROMOTIONEDITOR', 'ru', 'Акции'), ('TXT_PROMOTIONEDITOR', 'ua', 'Акції'),
  ('TXT_ORDEREDITOR', 'ru', 'Заказы'), ('TXT_ORDEREDITOR', 'ua', 'Замовлення'),
  ('TXT_ORDERGOODSEDITOR', 'ru', 'Товары заказа'), ('TXT_ORDERGOODSEDITOR', 'ua', 'Товари замовлення'),
  ('TXT_ORDERSTATUSEDITOR', 'ru', 'Статусы заказов'), ('TXT_ORDERSTATUSEDITOR', 'ua', 'Статуси замовлень'),
  ('TXT_DELIVERYTYPESEDITOR', 'ru', 'Способы доставки'), ('TXT_DELIVERYTYPESEDITOR', 'ua', 'Способи доставки'),
  ('TXT_PAYMENTTYPESEDITOR', 'ru', 'Способы оплаты'), ('TXT_PAYMENTTYPESEDITOR', 'ua', 'Способи оплати'),
  ('TXT_CURRENCYEDITOR', 'ru', 'Валюты'), ('TXT_CURRENCYEDITOR', 'ua', 'Валюти'),
  ('TXT_LOOKUPEDITOR', 'ru', 'Выбор значения'), ('TXT_LOOKUPEDITOR', 'ua', 'Вибір значення'),
  ('TXT_ATTACHMENTEDITOR', 'ru', 'Файлы'), ('TXT_ATTACHMENTEDITOR', 'ua', 'Файли'),
  ('TXT_SHOPEDITOR', 'ru', 'Магазины'), ('TXT_SHOPEDITOR', 'ua', 'Магазини'),
  ('TXT_COUNTRYEDITOR', 'ru', 'Страны'), ('TXT_COUNTRYEDITOR', 'ua', 'Країни'),
  ('TXT_SITELIST', 'ru', 'Магазины'), ('TXT_SITELIST', 'ua', 'Магазини'),
  ('TXT_CATEGORYDIVEDITOR', 'ru', 'Категории'), ('TXT_CATEGORYDIVEDITOR', 'ua', 'Категорії'),
  -- shop: поля товаров
  ('FIELD_GOODS_ID', 'ru', 'Товар'), ('FIELD_GOODS_ID', 'ua', 'Товар'),
  ('FIELD_GOODS_NAME', 'ru', 'Название'), ('FIELD_GOODS_NAME', 'ua', 'Назва'),
  ('FIELD_GOODS_CODE', 'ru', 'Артикул'), ('FIELD_GOODS_CODE', 'ua', 'Артикул'),
  ('FIELD_GOODS_SEGMENT', 'ru', 'Сегмент URL'), ('FIELD_GOODS_SEGMENT', 'ua', 'Сегмент URL'),
  ('FIELD_GOODS_TYPE', 'ru', 'Тип товара'), ('FIELD_GOODS_TYPE', 'ua', 'Тип товару'),
  ('FIELD_GOODS_PRICE', 'ru', 'Цена'), ('FIELD_GOODS_PRICE', 'ua', 'Ціна'),
  ('FIELD_GOODS_PRICE_OLD', 'ru', 'Старая цена'), ('FIELD_GOODS_PRICE_OLD', 'ua', 'Стара ціна'),
  ('FIELD_GOODS_IS_ACTIVE', 'ru', 'Активен'), ('FIELD_GOODS_IS_ACTIVE', 'ua', 'Активний'),
  ('FIELD_GOODS_SHORT_DESCRIPTION', 'ru', 'Краткое описание'), ('FIELD_GOODS_SHORT_DESCRIPTION', 'ua', 'Короткий опис'),
  ('FIELD_GOODS_DESCRIPTION_RTF', 'ru', 'Описание'), ('FIELD_GOODS_DESCRIPTION_RTF', 'ua', 'Опис'),
  ('FIELD_GOODS_SEO_TITLE', 'ru', 'SEO: заголовок'), ('FIELD_GOODS_SEO_TITLE', 'ua', 'SEO: заголовок'),
  ('FIELD_GOODS_SEO_KEYWORDS', 'ru', 'SEO: ключевые слова'), ('FIELD_GOODS_SEO_KEYWORDS', 'ua', 'SEO: ключові слова'),
  ('FIELD_GOODS_SEO_DESCRIPTION', 'ru', 'SEO: описание'), ('FIELD_GOODS_SEO_DESCRIPTION', 'ua', 'SEO: опис'),
  ('FIELD_PRODUCER_ID', 'ru', 'Производитель'), ('FIELD_PRODUCER_ID', 'ua', 'Виробник'),
  ('FIELD_SELL_STATUS_ID', 'ru', 'Наличие'), ('FIELD_SELL_STATUS_ID', 'ua', 'Наявність'),
  ('FIELD_CURRENCY_ID', 'ru', 'Валюта'), ('FIELD_CURRENCY_ID', 'ua', 'Валюта'),
  ('FIELD_FEATURES', 'ru', 'Характеристики'), ('FIELD_FEATURES', 'ua', 'Характеристики'),
  ('FIELD_PROMOTIONS', 'ru', 'Акции'), ('FIELD_PROMOTIONS', 'ua', 'Акції'),
  ('FIELD_GOODS_FROM_ID', 'ru', 'Товар'), ('FIELD_GOODS_FROM_ID', 'ua', 'Товар'),
  ('FIELD_GOODS_TO_ID', 'ru', 'Связанный товар'), ('FIELD_GOODS_TO_ID', 'ua', 'Пов''язаний товар'),
  ('FIELD_RELATION_TYPE', 'ru', 'Тип связи'), ('FIELD_RELATION_TYPE', 'ua', 'Тип зв''язку'),
  ('FIELD_RELATION_TYPE_ENUM_SIMILAR', 'ru', 'Похожий товар'), ('FIELD_RELATION_TYPE_ENUM_SIMILAR', 'ua', 'Схожий товар'),
  ('FIELD_RELATION_TYPE_ENUM_ACCESSORY', 'ru', 'Аксессуар'), ('FIELD_RELATION_TYPE_ENUM_ACCESSORY', 'ua', 'Аксесуар'),
  ('FIELD_FPV_DATA', 'ru', 'Значение'), ('FIELD_FPV_DATA', 'ua', 'Значення'),
  ('FIELD_CART_GOODS_COUNT', 'ru', 'Количество'), ('FIELD_CART_GOODS_COUNT', 'ua', 'Кількість'),
  ('FIELD_CART_GOODS_SUM', 'ru', 'Сумма'), ('FIELD_CART_GOODS_SUM', 'ua', 'Сума'),
  ('FIELD_KEYWORD', 'ru', 'Поиск товаров'), ('FIELD_KEYWORD', 'ua', 'Пошук товарів'),
  ('FIELD_SF_NAME', 'ru', 'Название фильтра'), ('FIELD_SF_NAME', 'ua', 'Назва фільтра'),
  ('FIELD_SF_DATA', 'ru', 'Параметры фильтра'), ('FIELD_SF_DATA', 'ua', 'Параметри фільтра'),
  -- shop: поля характеристик (FIELD_GROUP_ID и FIELD_GROUP_NAME уже есть в дампе — модуль user)
  ('FIELD_FEATURE_ID', 'ru', 'Характеристика'), ('FIELD_FEATURE_ID', 'ua', 'Характеристика'),
  ('FIELD_FEATURE_NAME', 'ru', 'Название'), ('FIELD_FEATURE_NAME', 'ua', 'Назва'),
  ('FIELD_FEATURE_TITLE', 'ru', 'Заголовок на сайте'), ('FIELD_FEATURE_TITLE', 'ua', 'Заголовок на сайті'),
  ('FIELD_FEATURE_DESCRIPTION', 'ru', 'Описание'), ('FIELD_FEATURE_DESCRIPTION', 'ua', 'Опис'),
  ('FIELD_FEATURE_UNIT', 'ru', 'Единица измерения'), ('FIELD_FEATURE_UNIT', 'ua', 'Одиниця виміру'),
  ('FIELD_FEATURE_TYPE', 'ru', 'Тип значения'), ('FIELD_FEATURE_TYPE', 'ua', 'Тип значення'),
  ('FIELD_FEATURE_TYPE_ENUM_STRING', 'ru', 'Строка'), ('FIELD_FEATURE_TYPE_ENUM_STRING', 'ua', 'Рядок'),
  ('FIELD_FEATURE_TYPE_ENUM_INT', 'ru', 'Число'), ('FIELD_FEATURE_TYPE_ENUM_INT', 'ua', 'Число'),
  ('FIELD_FEATURE_TYPE_ENUM_BOOL', 'ru', 'Да / нет'), ('FIELD_FEATURE_TYPE_ENUM_BOOL', 'ua', 'Так / ні'),
  ('FIELD_FEATURE_TYPE_ENUM_OPTION', 'ru', 'Одно значение из списка'), ('FIELD_FEATURE_TYPE_ENUM_OPTION', 'ua', 'Одне значення зі списку'),
  ('FIELD_FEATURE_TYPE_ENUM_MULTIOPTION', 'ru', 'Несколько значений из списка'), ('FIELD_FEATURE_TYPE_ENUM_MULTIOPTION', 'ua', 'Кілька значень зі списку'),
  ('FIELD_FEATURE_TYPE_ENUM_VARIANT', 'ru', 'Варианты исполнения'), ('FIELD_FEATURE_TYPE_ENUM_VARIANT', 'ua', 'Варіанти виконання'),
  ('FIELD_FEATURE_FILTER_TYPE', 'ru', 'Вид фильтра'), ('FIELD_FEATURE_FILTER_TYPE', 'ua', 'Вигляд фільтра'),
  ('FIELD_FEATURE_FILTER_TYPE_ENUM_DEFAULT', 'ru', 'По типу значения'), ('FIELD_FEATURE_FILTER_TYPE_ENUM_DEFAULT', 'ua', 'За типом значення'),
  ('FIELD_FEATURE_FILTER_TYPE_ENUM_RADIOGROUP', 'ru', 'Переключатели'), ('FIELD_FEATURE_FILTER_TYPE_ENUM_RADIOGROUP', 'ua', 'Перемикачі'),
  ('FIELD_FEATURE_FILTER_TYPE_ENUM_CHECKBOXGROUP', 'ru', 'Флажки'), ('FIELD_FEATURE_FILTER_TYPE_ENUM_CHECKBOXGROUP', 'ua', 'Прапорці'),
  ('FIELD_FEATURE_FILTER_TYPE_ENUM_SELECT', 'ru', 'Выпадающий список'), ('FIELD_FEATURE_FILTER_TYPE_ENUM_SELECT', 'ua', 'Випадаючий список'),
  ('FIELD_FEATURE_FILTER_TYPE_ENUM_RANGE', 'ru', 'Диапазон'), ('FIELD_FEATURE_FILTER_TYPE_ENUM_RANGE', 'ua', 'Діапазон'),
  ('FIELD_FEATURE_SITE_MULTI', 'ru', 'Магазины'), ('FIELD_FEATURE_SITE_MULTI', 'ua', 'Магазини'),
  ('FIELD_FEATURE_SMAP_MULTI', 'ru', 'Категории'), ('FIELD_FEATURE_SMAP_MULTI', 'ua', 'Категорії'),
  ('FIELD_FEATURE_IS_ACTIVE', 'ru', 'Активна'), ('FIELD_FEATURE_IS_ACTIVE', 'ua', 'Активна'),
  ('FIELD_FEATURE_IS_FILTER', 'ru', 'Показывать в фильтре'), ('FIELD_FEATURE_IS_FILTER', 'ua', 'Показувати у фільтрі'),
  ('FIELD_FEATURE_IS_ORDER_PARAM', 'ru', 'Параметр заказа'), ('FIELD_FEATURE_IS_ORDER_PARAM', 'ua', 'Параметр замовлення'),
  ('FIELD_FEATURE_IS_MAIN', 'ru', 'Основная'), ('FIELD_FEATURE_IS_MAIN', 'ua', 'Основна'),
  ('FIELD_FEATURE_SYSNAME', 'ru', 'Имя параметра фильтра'), ('FIELD_FEATURE_SYSNAME', 'ua', 'Ім''я параметра фільтра'),
  ('FIELD_FEATURE_ORDER_NUM', 'ru', 'Порядок'), ('FIELD_FEATURE_ORDER_NUM', 'ua', 'Порядок'),
  ('FIELD_GROUP_DESCRIPTION', 'ru', 'Описание'), ('FIELD_GROUP_DESCRIPTION', 'ua', 'Опис'),
  ('FIELD_GROUP_IS_ACTIVE', 'ru', 'Активна'), ('FIELD_GROUP_IS_ACTIVE', 'ua', 'Активна'),
  ('FIELD_OPTION_VALUE', 'ru', 'Значение'), ('FIELD_OPTION_VALUE', 'ua', 'Значення'),
  ('FIELD_OPTION_IMG', 'ru', 'Изображение'), ('FIELD_OPTION_IMG', 'ua', 'Зображення'),
  ('FIELD_SMAP_FEATURES_MULTI', 'ru', 'Характеристики товаров раздела'), ('FIELD_SMAP_FEATURES_MULTI', 'ua', 'Характеристики товарів розділу'),
  -- shop: производители, валюты, страны, акции
  ('FIELD_PRODUCER_NAME', 'ru', 'Название'), ('FIELD_PRODUCER_NAME', 'ua', 'Назва'),
  ('FIELD_PRODUCER_SEGMENT', 'ru', 'Сегмент URL'), ('FIELD_PRODUCER_SEGMENT', 'ua', 'Сегмент URL'),
  ('FIELD_PRODUCER_IS_ACTIVE', 'ru', 'Активен'), ('FIELD_PRODUCER_IS_ACTIVE', 'ua', 'Активний'),
  ('FIELD_PRODUCER_SITE_MULTI', 'ru', 'Магазины'), ('FIELD_PRODUCER_SITE_MULTI', 'ua', 'Магазини'),
  ('FIELD_CURRENCY_NAME', 'ru', 'Название'), ('FIELD_CURRENCY_NAME', 'ua', 'Назва'),
  ('FIELD_CURRENCY_CODE', 'ru', 'Код ISO 4217'), ('FIELD_CURRENCY_CODE', 'ua', 'Код ISO 4217'),
  ('FIELD_CURRENCY_SHORTNAME', 'ru', 'Обозначение'), ('FIELD_CURRENCY_SHORTNAME', 'ua', 'Позначення'),
  ('FIELD_CURRENCY_SHORTNAME_ORDER', 'ru', 'Обозначение ставится'), ('FIELD_CURRENCY_SHORTNAME_ORDER', 'ua', 'Позначення ставиться'),
  ('FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_BEFORE', 'ru', 'перед суммой'), ('FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_BEFORE', 'ua', 'перед сумою'),
  ('FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_AFTER', 'ru', 'после суммы'), ('FIELD_CURRENCY_SHORTNAME_ORDER_ENUM_AFTER', 'ua', 'після суми'),
  ('FIELD_CURRENCY_RATE', 'ru', 'Курс к базовой валюте'), ('FIELD_CURRENCY_RATE', 'ua', 'Курс до базової валюти'),
  ('FIELD_CURRENCY_IS_DEFAULT', 'ru', 'Базовая валюта'), ('FIELD_CURRENCY_IS_DEFAULT', 'ua', 'Базова валюта'),
  ('FIELD_CURRENCY_IS_ACTIVE', 'ru', 'Активна'), ('FIELD_CURRENCY_IS_ACTIVE', 'ua', 'Активна'),
  ('FIELD_COUNTRY_ID', 'ru', 'Страна'), ('FIELD_COUNTRY_ID', 'ua', 'Країна'),
  ('FIELD_COUNTRY_NAME', 'ru', 'Страна'), ('FIELD_COUNTRY_NAME', 'ua', 'Країна'),
  ('FIELD_COUNTRY_TEL_CODE', 'ru', 'Телефонный код'), ('FIELD_COUNTRY_TEL_CODE', 'ua', 'Телефонний код'),
  ('FIELD_COUNTRY_TEL_FORMAT', 'ru', 'Маска телефона'), ('FIELD_COUNTRY_TEL_FORMAT', 'ua', 'Маска телефону'),
  ('FIELD_PROMOTION_NAME', 'ru', 'Название акции'), ('FIELD_PROMOTION_NAME', 'ua', 'Назва акції'),
  ('FIELD_PROMOTION_IS_ACTIVE', 'ru', 'Активна'), ('FIELD_PROMOTION_IS_ACTIVE', 'ua', 'Активна'),
  ('FIELD_PROMOTION_START_DATE', 'ru', 'Начало'), ('FIELD_PROMOTION_START_DATE', 'ua', 'Початок'),
  ('FIELD_PROMOTION_END_DATE', 'ru', 'Окончание'), ('FIELD_PROMOTION_END_DATE', 'ua', 'Закінчення'),
  -- shop: заказы и справочники
  ('FIELD_ORDER_ID', 'ru', '№ заказа'), ('FIELD_ORDER_ID', 'ua', '№ замовлення'),
  ('FIELD_STATUS_ID', 'ru', 'Статус'), ('FIELD_STATUS_ID', 'ua', 'Статус'),
  ('FIELD_DELIVERY_TYPE_ID', 'ru', 'Доставка'), ('FIELD_DELIVERY_TYPE_ID', 'ua', 'Доставка'),
  ('FIELD_PAYMENT_TYPE_ID', 'ru', 'Оплата'), ('FIELD_PAYMENT_TYPE_ID', 'ua', 'Оплата'),
  ('FIELD_ORDER_USER_NAME', 'ru', 'Покупатель'), ('FIELD_ORDER_USER_NAME', 'ua', 'Покупець'),
  ('FIELD_ORDER_EMAIL', 'ru', 'E-mail'), ('FIELD_ORDER_EMAIL', 'ua', 'E-mail'),
  ('FIELD_ORDER_PHONE', 'ru', 'Телефон'), ('FIELD_ORDER_PHONE', 'ua', 'Телефон'),
  ('FIELD_ORDER_CITY', 'ru', 'Город'), ('FIELD_ORDER_CITY', 'ua', 'Місто'),
  ('FIELD_ORDER_ADDRESS', 'ru', 'Адрес доставки'), ('FIELD_ORDER_ADDRESS', 'ua', 'Адреса доставки'),
  ('FIELD_ORDER_COMMENT', 'ru', 'Комментарий'), ('FIELD_ORDER_COMMENT', 'ua', 'Коментар'),
  ('FIELD_ORDER_CREATED', 'ru', 'Создан'), ('FIELD_ORDER_CREATED', 'ua', 'Створено'),
  ('FIELD_ORDER_UPDATED', 'ru', 'Изменён'), ('FIELD_ORDER_UPDATED', 'ua', 'Змінено'),
  ('FIELD_ORDER_AMOUNT', 'ru', 'Сумма товаров'), ('FIELD_ORDER_AMOUNT', 'ua', 'Сума товарів'),
  ('FIELD_ORDER_DISCOUNT', 'ru', 'Скидка'), ('FIELD_ORDER_DISCOUNT', 'ua', 'Знижка'),
  ('FIELD_ORDER_TOTAL', 'ru', 'Итого'), ('FIELD_ORDER_TOTAL', 'ua', 'Разом'),
  ('FIELD_ORDER_PROMOCODE', 'ru', 'Промокод'), ('FIELD_ORDER_PROMOCODE', 'ua', 'Промокод'),
  ('FIELD_ORDER_GOODS', 'ru', 'Товары'), ('FIELD_ORDER_GOODS', 'ua', 'Товари'),
  ('FIELD_GOODS_TITLE', 'ru', 'Наименование'), ('FIELD_GOODS_TITLE', 'ua', 'Найменування'),
  ('FIELD_GOODS_DESCRIPTION', 'ru', 'Описание'), ('FIELD_GOODS_DESCRIPTION', 'ua', 'Опис'),
  ('FIELD_GOODS_REAL_PRICE', 'ru', 'Цена без скидки'), ('FIELD_GOODS_REAL_PRICE', 'ua', 'Ціна без знижки'),
  ('FIELD_GOODS_QUANTITY', 'ru', 'Количество'), ('FIELD_GOODS_QUANTITY', 'ua', 'Кількість'),
  ('FIELD_GOODS_AMOUNT', 'ru', 'Сумма'), ('FIELD_GOODS_AMOUNT', 'ua', 'Сума'),
  ('FIELD_STATUS_NAME', 'ru', 'Название'), ('FIELD_STATUS_NAME', 'ua', 'Назва'),
  ('FIELD_STATUS_SYSNAME', 'ru', 'Системное имя'), ('FIELD_STATUS_SYSNAME', 'ua', 'Системне ім''я'),
  ('FIELD_STATUS_IS_CANCELLABLE', 'ru', 'Можно отменить'), ('FIELD_STATUS_IS_CANCELLABLE', 'ua', 'Можна скасувати'),
  ('FIELD_STATUS_IS_ACTIVE', 'ru', 'Активен'), ('FIELD_STATUS_IS_ACTIVE', 'ua', 'Активний'),
  ('FIELD_TYPE_NAME', 'ru', 'Название'), ('FIELD_TYPE_NAME', 'ua', 'Назва'),
  ('FIELD_TYPE_SYSNAME', 'ru', 'Системное имя'), ('FIELD_TYPE_SYSNAME', 'ua', 'Системне ім''я'),
  ('FIELD_TYPE_IS_ACTIVE', 'ru', 'Активен'), ('FIELD_TYPE_IS_ACTIVE', 'ua', 'Активний'),
  ('FIELD_TYPE_IS_ONLINE', 'ru', 'Онлайн-оплата'), ('FIELD_TYPE_IS_ONLINE', 'ua', 'Онлайн-оплата'),
  ('FIELD_SELL_STATUS_NAME', 'ru', 'Наличие'), ('FIELD_SELL_STATUS_NAME', 'ua', 'Наявність'),
  -- shop: шаблоны содержимого в редакторе разделов (CONTENT_ + имя файла)
  ('CONTENT_CART', 'ru', 'Магазин: корзина'), ('CONTENT_CART', 'ua', 'Магазин: кошик'),
  ('CONTENT_CATALOG', 'ru', 'Магазин: каталог (список категорий)'), ('CONTENT_CATALOG', 'ua', 'Магазин: каталог (список категорій)'),
  ('CONTENT_CATALOG_PRODUCTS', 'ru', 'Магазин: товары категории'), ('CONTENT_CATALOG_PRODUCTS', 'ua', 'Магазин: товари категорії'),
  ('CONTENT_SEARCH', 'ru', 'Магазин: поиск товаров'), ('CONTENT_SEARCH', 'ua', 'Магазин: пошук товарів'),
  ('CONTENT_WISHLIST', 'ru', 'Магазин: список желаний'), ('CONTENT_WISHLIST', 'ua', 'Магазин: список бажань'),
  ('CONTENT_ORDER_LIST', 'ru', 'Магазин: мои заказы'), ('CONTENT_ORDER_LIST', 'ua', 'Магазин: мої замовлення'),
  ('CONTENT_GOODS_EDITOR', 'ru', 'Магазин: редактор товаров'), ('CONTENT_GOODS_EDITOR', 'ua', 'Магазин: редактор товарів'),
  ('CONTENT_CATEGORY_EDITOR', 'ru', 'Магазин: редактор категорий'), ('CONTENT_CATEGORY_EDITOR', 'ua', 'Магазин: редактор категорій'),
  ('CONTENT_FEATURE_EDITOR', 'ru', 'Магазин: характеристики'), ('CONTENT_FEATURE_EDITOR', 'ua', 'Магазин: характеристики'),
  ('CONTENT_FEATURE_GROUP_EDITOR', 'ru', 'Магазин: группы характеристик'), ('CONTENT_FEATURE_GROUP_EDITOR', 'ua', 'Магазин: групи характеристик'),
  ('CONTENT_PRODUCER_EDITOR', 'ru', 'Магазин: производители'), ('CONTENT_PRODUCER_EDITOR', 'ua', 'Магазин: виробники'),
  ('CONTENT_PROMOTION_EDITOR', 'ru', 'Магазин: акции'), ('CONTENT_PROMOTION_EDITOR', 'ua', 'Магазин: акції'),
  ('CONTENT_ORDER_EDITOR', 'ru', 'Магазин: заказы'), ('CONTENT_ORDER_EDITOR', 'ua', 'Магазин: замовлення'),
  ('CONTENT_ORDER_STATUS_EDITOR', 'ru', 'Магазин: статусы заказов'), ('CONTENT_ORDER_STATUS_EDITOR', 'ua', 'Магазин: статуси замовлень'),
  ('CONTENT_DELIVERY_TYPES_EDITOR', 'ru', 'Магазин: способы доставки'), ('CONTENT_DELIVERY_TYPES_EDITOR', 'ua', 'Магазин: способи доставки'),
  ('CONTENT_PAYMENT_TYPES_EDITOR', 'ru', 'Магазин: способы оплаты'), ('CONTENT_PAYMENT_TYPES_EDITOR', 'ua', 'Магазин: способи оплати'),
  ('CONTENT_CURRENCY_EDITOR', 'ru', 'Магазин: валюты'), ('CONTENT_CURRENCY_EDITOR', 'ua', 'Магазин: валюти');

INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) SELECT DISTINCT `name` FROM `tmp_module_translations`;
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`, x.`value`
    FROM `tmp_module_translations` x
    JOIN `share_lang_tags` t ON t.`ltag_name` = x.`name`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`;
DROP TEMPORARY TABLE `tmp_module_translations`;

-- Подписи модулей mail, ads, shop
-- Константы, у которых не было записи в справочнике: админка показывала
-- их системные имена (FIELD_TOP_NAME и т.п.) вместо подписей.
-- кодировка колонки задана явно: `share_lang_tags`.`ltag_name` - utf8mb3_general_ci,
-- а временная таблица иначе берёт сортировку базы, и соединение падает
CREATE TEMPORARY TABLE `tmp_module_label_translations` (
  `name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci,
  `abbr` VARCHAR(5) CHARACTER SET utf8 COLLATE utf8_general_ci,
  `value` TEXT CHARACTER SET utf8 COLLATE utf8_general_ci);
INSERT INTO `tmp_module_label_translations` (`name`, `abbr`, `value`) VALUES
  ('FIELD_ADS_ITEM_ID', 'ru', 'Баннер'), ('FIELD_ADS_ITEM_ID', 'ua', 'Банер'),
  ('FIELD_CRM_ID', 'ru', 'Сообщение рассылки'), ('FIELD_CRM_ID', 'ua', 'Повідомлення розсилки'),
  ('FIELD_FPV_ID', 'ru', 'Значение характеристики'), ('FIELD_FPV_ID', 'ua', 'Значення характеристики'),
  ('FIELD_FPV_ORDER', 'ru', 'Порядок'), ('FIELD_FPV_ORDER', 'ua', 'Порядок'),
  ('FIELD_GP_ID', 'ru', 'Товар акции'), ('FIELD_GP_ID', 'ua', 'Товар акції'),
  ('FIELD_OG_ID', 'ru', 'Строка заказа'), ('FIELD_OG_ID', 'ua', 'Рядок замовлення'),
  ('FIELD_OPTION_ID', 'ru', 'Вариант'), ('FIELD_OPTION_ID', 'ua', 'Варіант'),
  ('FIELD_OPTION_ORDER_NUM', 'ru', 'Порядок'), ('FIELD_OPTION_ORDER_NUM', 'ua', 'Порядок'),
  ('FIELD_ORDER_GOODS_COUNT', 'ru', 'Количество'), ('FIELD_ORDER_GOODS_COUNT', 'ua', 'Кількість'),
  ('FIELD_PRICE', 'ru', 'Цена'), ('FIELD_PRICE', 'ua', 'Ціна'),
  ('FIELD_PRODUCERS', 'ru', 'Производители'), ('FIELD_PRODUCERS', 'ua', 'Виробники'),
  ('FIELD_PROMOTION_ID', 'ru', 'Акция'), ('FIELD_PROMOTION_ID', 'ua', 'Акція'),
  ('FIELD_RELATION_ID', 'ru', 'Связь товаров'), ('FIELD_RELATION_ID', 'ua', 'Зв’язок товарів'),
  ('FIELD_SF_ID', 'ru', 'Сохранённый фильтр'), ('FIELD_SF_ID', 'ua', 'Збережений фільтр'),
  ('FIELD_SMAP_SEO_DESCRIPTION', 'ru', 'SEO-описание'), ('FIELD_SMAP_SEO_DESCRIPTION', 'ua', 'SEO-опис'),
  ('FIELD_SMAP_SEO_TITLE', 'ru', 'SEO-заголовок'), ('FIELD_SMAP_SEO_TITLE', 'ua', 'SEO-заголовок'),
  ('FIELD_TEMPLATE_ID', 'ru', 'Шаблон письма'), ('FIELD_TEMPLATE_ID', 'ua', 'Шаблон листа'),
  ('FIELD_TYPE_ID', 'ru', 'Тип'), ('FIELD_TYPE_ID', 'ua', 'Тип'),
  ('MSG_BAD_CHECK_SITE_MULTI', 'ru', 'Выберите хотя бы один сайт.'), ('MSG_BAD_CHECK_SITE_MULTI', 'ua', 'Оберіть хоча б один сайт.');
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) SELECT DISTINCT `name` FROM `tmp_module_label_translations`;
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
  SELECT t.`ltag_id`, l.`lang_id`, x.`value`
    FROM `tmp_module_label_translations` x
    JOIN `share_lang_tags` t ON t.`ltag_name` = x.`name`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`;
DROP TEMPORARY TABLE `tmp_module_label_translations`;

-- =============================================================================================
-- 3. Шаблоны писем (mail/gears/MailTemplate.php)
-- =============================================================================================
-- Макросы [ключ] заменяются значениями, которые передаёт вызывающий код; значения не экранируются.
-- template_subject — тема, template_body — текстовая часть, template_body_rtf — HTML-часть.
-- Без активного шаблона MailTemplate бросает ERR_NO_MAIL_TEMPLATE: регистрация, восстановление пароля
-- и обратная связь перестают отправлять письма.
CREATE TEMPORARY TABLE `tmp_mail_templates` (
  `sysname` varchar(100) NOT NULL,
  `hints` text NOT NULL,
  `abbr` char(2) NOT NULL,
  `name` varchar(255) NOT NULL,
  `subject` varchar(255) DEFAULT NULL,
  `body` text DEFAULT NULL,
  `body_rtf` mediumtext DEFAULT NULL
) DEFAULT CHARSET=utf8;

INSERT INTO `tmp_mail_templates` VALUES
('user_registration',
 '[user_name] - имя пользователя, [user_login] - логин (e-mail), [user_password] - пароль, [site_name] - название сайта (константа TXT_SITE_NAME), [site_url] - адрес сайта',
 'ru', 'Регистрация пользователя',
 'Регистрация на сайте [site_name]',
 'Здравствуйте, [user_name]!

Вы зарегистрированы на сайте [site_name] ([site_url]).

Логин: [user_login]
Пароль: [user_password]

Письмо отправлено автоматически, отвечать на него не нужно.',
 '<p>Здравствуйте, [user_name]!</p>
<p>Вы зарегистрированы на сайте <a href="[site_url]">[site_name]</a>.</p>
<p>Логин: <strong>[user_login]</strong><br>Пароль: <strong>[user_password]</strong></p>
<p>Письмо отправлено автоматически, отвечать на него не нужно.</p>'),
('user_registration', '', 'ua', 'Реєстрація користувача',
 'Реєстрація на сайті [site_name]',
 'Вітаємо, [user_name]!

Ви зареєстровані на сайті [site_name] ([site_url]).

Логін: [user_login]
Пароль: [user_password]

Лист надіслано автоматично, відповідати на нього не потрібно.',
 '<p>Вітаємо, [user_name]!</p>
<p>Ви зареєстровані на сайті <a href="[site_url]">[site_name]</a>.</p>
<p>Логін: <strong>[user_login]</strong><br>Пароль: <strong>[user_password]</strong></p>
<p>Лист надіслано автоматично, відповідати на нього не потрібно.</p>'),

('user_restore_password',
 '[sex_suffix_hello] - окончание обращения по полу пользователя (константы TXT_EMAIL_SUFFIX_SEX_M/F/UNKNOWN), [user_name] - имя, [user_login] - логин (e-mail), [user_password] - новый пароль, [site_name] - название сайта, [site_url] - адрес сайта',
 'ru', 'Восстановление пароля',
 'Новый пароль для сайта [site_name]',
 'Уважаем[sex_suffix_hello] [user_name]!

Для учётной записи [user_login] на сайте [site_name] ([site_url]) создан новый пароль: [user_password]

Используйте его для входа на сайт.',
 '<p>Уважаем[sex_suffix_hello] [user_name]!</p>
<p>Для учётной записи <strong>[user_login]</strong> на сайте <a href="[site_url]">[site_name]</a> создан новый пароль: <strong>[user_password]</strong></p>
<p>Используйте его для входа на сайт.</p>'),
('user_restore_password', '', 'ua', 'Відновлення пароля',
 'Новий пароль для сайту [site_name]',
 'Шановн[sex_suffix_hello] [user_name]!

Для облікового запису [user_login] на сайті [site_name] ([site_url]) створено новий пароль: [user_password]

Використовуйте його для входу на сайт.',
 '<p>Шановн[sex_suffix_hello] [user_name]!</p>
<p>Для облікового запису <strong>[user_login]</strong> на сайті <a href="[site_url]">[site_name]</a> створено новий пароль: <strong>[user_password]</strong></p>
<p>Використовуйте його для входу на сайт.</p>'),

-- в письмо посетителю не подставляем введённый им текст: форма отправляет его на любой указанный адрес
('feedback_form',
 'Письмо посетителю, указавшему e-mail. Доступны поля формы: [feed_author] - имя, [feed_email] - e-mail, [feed_theme] - тема, [feed_text] - сообщение. Значения не экранируются.',
 'ru', 'Обратная связь: подтверждение посетителю',
 'Ваше сообщение получено',
 'Спасибо за ваше сообщение. Вскоре оно будет рассмотрено.',
 '<p>Спасибо за ваше сообщение. Вскоре оно будет рассмотрено.</p>'),
('feedback_form', '', 'ua', 'Зворотний зв''язок: підтвердження відвідувачу',
 'Ваше повідомлення отримано',
 'Дякуємо за ваше повідомлення. Незабаром його буде розглянуто.',
 '<p>Дякуємо за ваше повідомлення. Незабаром його буде розглянуто.</p>'),

('feedback_form_admin',
 'Письмо получателям из справочника "Получатели" обратной связи. [feed_author] - имя, [feed_email] - e-mail, [feed_theme] - тема, [feed_text] - сообщение, [rcp_id] - id получателя. Значения не экранируются.',
 'ru', 'Обратная связь: уведомление получателю',
 'Сообщение с сайта: [feed_theme]',
 'Новое сообщение из формы обратной связи.

Имя: [feed_author]
E-mail: [feed_email]
Тема: [feed_theme]

[feed_text]',
 '<p>Новое сообщение из формы обратной связи.</p>
<p>Имя: [feed_author]<br>E-mail: [feed_email]<br>Тема: [feed_theme]</p>
<p>[feed_text]</p>'),
('feedback_form_admin', '', 'ua', 'Зворотний зв''язок: сповіщення отримувачу',
 'Повідомлення з сайту: [feed_theme]',
 'Нове повідомлення з форми зворотного зв''язку.

Ім''я: [feed_author]
E-mail: [feed_email]
Тема: [feed_theme]

[feed_text]',
 '<p>Нове повідомлення з форми зворотного зв''язку.</p>
<p>Ім''я: [feed_author]<br>E-mail: [feed_email]<br>Тема: [feed_theme]</p>
<p>[feed_text]</p>'),

('mail_news',
 'Рассылка новостей (тип news), язык сайта по умолчанию. [user_name] - имя подписчика, [user_email] - его e-mail, [items] - новости, каждая оформлена шаблоном mail_news_item.',
 'ru', 'Рассылка новостей',
 'Новости сайта',
 'Здравствуйте, [user_name]!

Новые публикации на сайте:

[items]
Вы получили это письмо, потому что адрес [user_email] подписан на рассылку.',
 '<p>Здравствуйте, [user_name]!</p>
<p>Новые публикации на сайте:</p>
[items]
<p><small>Вы получили это письмо, потому что адрес [user_email] подписан на рассылку.</small></p>'),
('mail_news', '', 'ua', 'Розсилка новин',
 'Новини сайту',
 'Вітаємо, [user_name]!

Нові публікації на сайті:

[items]
Ви отримали цей лист, тому що адресу [user_email] підписано на розсилку.',
 '<p>Вітаємо, [user_name]!</p>
<p>Нові публікації на сайті:</p>
[items]
<p><small>Ви отримали цей лист, тому що адресу [user_email] підписано на розсилку.</small></p>'),

('mail_news_item',
 'Одна новость в письме mail_news. [id] - id новости, [title] - заголовок, [description] - анонс без HTML, [date] - дата (дд.мм.гггг), [url] - ссылка на новость.',
 'ru', 'Рассылка новостей: новость', NULL,
 '[date] [title]
[description]
[url]

',
 '<p><small>[date]</small><br><a href="[url]"><strong>[title]</strong></a><br>[description]</p>
'),
('mail_news_item', '', 'ua', 'Розсилка новин: новина', NULL,
 '[date] [title]
[description]
[url]

',
 '<p><small>[date]</small><br><a href="[url]"><strong>[title]</strong></a><br>[description]</p>
'),

('mail_crm',
 'Информационная рассылка (тип crm): сообщения из раздела "Сообщения рассылки". [user_name] - имя подписчика, [user_email] - его e-mail, [items] - сообщения, каждое оформлено шаблоном mail_crm_item.',
 'ru', 'Информационная рассылка',
 'Информационная рассылка',
 'Здравствуйте, [user_name]!

[items]
Вы получили это письмо, потому что адрес [user_email] подписан на рассылку.',
 '<p>Здравствуйте, [user_name]!</p>
[items]
<p><small>Вы получили это письмо, потому что адрес [user_email] подписан на рассылку.</small></p>'),
('mail_crm', '', 'ua', 'Інформаційна розсилка',
 'Інформаційна розсилка',
 'Вітаємо, [user_name]!

[items]
Ви отримали цей лист, тому що адресу [user_email] підписано на розсилку.',
 '<p>Вітаємо, [user_name]!</p>
[items]
<p><small>Ви отримали цей лист, тому що адресу [user_email] підписано на розсилку.</small></p>'),

('mail_crm_item',
 'Одно сообщение в письме mail_crm. [id] - id сообщения, [title] - заголовок, [description] - текст без HTML, [date] - дата (дд.мм.гггг).',
 'ru', 'Информационная рассылка: сообщение', NULL,
 '[title] ([date])
[description]

',
 '<h3>[title]</h3>
<p><small>[date]</small></p>
<p>[description]</p>
'),
('mail_crm_item', '', 'ua', 'Інформаційна розсилка: повідомлення', NULL,
 '[title] ([date])
[description]

',
 '<h3>[title]</h3>
<p><small>[date]</small></p>
<p>[description]</p>
');

INSERT IGNORE INTO `mail_templates` (`template_sysname`, `template_is_active`, `template_hints`)
  SELECT `sysname`, 1, `hints` FROM `tmp_mail_templates` WHERE `abbr` = 'ru';

INSERT IGNORE INTO `mail_templates_translation` (`template_id`, `lang_id`, `template_name`, `template_subject`, `template_body`, `template_body_rtf`)
  SELECT t.`template_id`, l.`lang_id`, x.`name`, x.`subject`, x.`body`, x.`body_rtf`
    FROM `tmp_mail_templates` x
    JOIN `mail_templates` t ON t.`template_sysname` = x.`sysname`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`;

DROP TEMPORARY TABLE `tmp_mail_templates`;

-- =============================================================================================
-- 4. Справочники магазина
-- =============================================================================================
-- Названия копируются из ru во все остальные языки: Currency и списки внешних ключей читают только текущий язык.
CREATE TEMPORARY TABLE `tmp_shop_seed` (
  `entity` varchar(30) NOT NULL,
  `code` varchar(50) NOT NULL,
  `abbr` char(2) NOT NULL,
  `name` varchar(255) NOT NULL
) DEFAULT CHARSET=utf8;

INSERT INTO `tmp_shop_seed` VALUES
  ('currency', 'UAH', 'ru', 'Гривна'), ('currency', 'UAH', 'ua', 'Гривня'),
  ('status', 'new', 'ru', 'Новый'), ('status', 'new', 'ua', 'Новий'),
  ('status', 'valid', 'ru', 'Подтверждён'), ('status', 'valid', 'ua', 'Підтверджено'),
  ('status', 'done', 'ru', 'Выполнен'), ('status', 'done', 'ua', 'Виконано'),
  ('status', 'cancelled', 'ru', 'Отменён'), ('status', 'cancelled', 'ua', 'Скасовано'),
  ('delivery', 'pickup', 'ru', 'Самовывоз'), ('delivery', 'pickup', 'ua', 'Самовивіз'),
  ('delivery', 'courier', 'ru', 'Курьером'), ('delivery', 'courier', 'ua', 'Кур''єром'),
  ('delivery', 'post', 'ru', 'Почтой'), ('delivery', 'post', 'ua', 'Поштою'),
  ('payment', 'cash', 'ru', 'Наличными при получении'), ('payment', 'cash', 'ua', 'Готівкою при отриманні'),
  ('payment', 'card', 'ru', 'Картой онлайн'), ('payment', 'card', 'ua', 'Карткою онлайн'),
  ('payment', 'invoice', 'ru', 'Безналичный расчёт'), ('payment', 'invoice', 'ua', 'Безготівковий розрахунок');

-- Базовая валюта: без активной валюты по умолчанию список товаров, корзина и поиск падают (ERR_NO_CURRENCY).
INSERT IGNORE INTO `shop_currencies`
  (`currency_code`, `currency_shortname`, `currency_shortname_order`, `currency_rate`, `currency_is_default`, `currency_is_active`)
VALUES
  ('UAH', 'грн', 'after', 1.0000, 1, 1);

INSERT IGNORE INTO `shop_currencies_translation` (`currency_id`, `lang_id`, `currency_name`)
  SELECT c.`currency_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_currencies` c ON c.`currency_code` = x.`code`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`
   WHERE x.`entity` = 'currency';
INSERT IGNORE INTO `shop_currencies_translation` (`currency_id`, `lang_id`, `currency_name`)
  SELECT c.`currency_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_currencies` c ON c.`currency_code` = x.`code`
    CROSS JOIN `share_languages` l
   WHERE x.`entity` = 'currency' AND x.`abbr` = 'ru';

-- Статусы заказов (new и valid обязательны), способы доставки и оплаты.
INSERT IGNORE INTO `shop_order_statuses` (`status_sysname`, `status_is_cancellable`, `status_is_active`, `status_order_num`) VALUES
  ('new', 1, 1, 1),
  ('valid', 1, 1, 2),
  ('done', 0, 1, 3),
  ('cancelled', 0, 1, 4);

INSERT IGNORE INTO `shop_order_statuses_translation` (`status_id`, `lang_id`, `status_name`)
  SELECT s.`status_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_order_statuses` s ON s.`status_sysname` = x.`code`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`
   WHERE x.`entity` = 'status';
INSERT IGNORE INTO `shop_order_statuses_translation` (`status_id`, `lang_id`, `status_name`)
  SELECT s.`status_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_order_statuses` s ON s.`status_sysname` = x.`code`
    CROSS JOIN `share_languages` l
   WHERE x.`entity` = 'status' AND x.`abbr` = 'ru';

INSERT IGNORE INTO `shop_delivery_types` (`type_sysname`, `type_is_active`, `type_order_num`) VALUES
  ('pickup', 1, 1),
  ('courier', 1, 2),
  ('post', 1, 3);

INSERT IGNORE INTO `shop_delivery_types_translation` (`type_id`, `lang_id`, `type_name`)
  SELECT d.`type_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_delivery_types` d ON d.`type_sysname` = x.`code`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`
   WHERE x.`entity` = 'delivery';
INSERT IGNORE INTO `shop_delivery_types_translation` (`type_id`, `lang_id`, `type_name`)
  SELECT d.`type_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_delivery_types` d ON d.`type_sysname` = x.`code`
    CROSS JOIN `share_languages` l
   WHERE x.`entity` = 'delivery' AND x.`abbr` = 'ru';

INSERT IGNORE INTO `shop_payment_types` (`type_sysname`, `type_is_online`, `type_is_active`, `type_order_num`) VALUES
  ('cash', 0, 1, 1),
  ('card', 1, 1, 2),
  ('invoice', 0, 1, 3);

INSERT IGNORE INTO `shop_payment_types_translation` (`type_id`, `lang_id`, `type_name`)
  SELECT p.`type_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_payment_types` p ON p.`type_sysname` = x.`code`
    JOIN `share_languages` l ON l.`lang_abbr` = x.`abbr`
   WHERE x.`entity` = 'payment';
INSERT IGNORE INTO `shop_payment_types_translation` (`type_id`, `lang_id`, `type_name`)
  SELECT p.`type_id`, l.`lang_id`, x.`name`
    FROM `tmp_shop_seed` x
    JOIN `shop_payment_types` p ON p.`type_sysname` = x.`code`
    CROSS JOIN `share_languages` l
   WHERE x.`entity` = 'payment' AND x.`abbr` = 'ru';

DROP TEMPORARY TABLE `tmp_shop_seed`;

-- Наличие товара и страна: естественного ключа нет, строка пропускается, если есть запись с тем же
-- русским названием. Страна нужна, чтобы сохранить магазин в редакторе магазинов.
INSERT INTO `shop_sell_statuses` (`sell_status_order_num`)
  SELECT 1 FROM DUAL WHERE NOT EXISTS (
    SELECT 1 FROM `shop_sell_statuses_translation` t JOIN `share_languages` l ON l.`lang_id` = t.`lang_id`
     WHERE l.`lang_abbr` = 'ru' AND t.`sell_status_name` = 'В наличии');
SET @seed_id = IF(ROW_COUNT() > 0, LAST_INSERT_ID(), NULL);
INSERT IGNORE INTO `shop_sell_statuses_translation` (`sell_status_id`, `lang_id`, `sell_status_name`)
  SELECT @seed_id, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'В наявності', 'В наличии')
    FROM `share_languages` l WHERE @seed_id IS NOT NULL;

INSERT INTO `shop_sell_statuses` (`sell_status_order_num`)
  SELECT 2 FROM DUAL WHERE NOT EXISTS (
    SELECT 1 FROM `shop_sell_statuses_translation` t JOIN `share_languages` l ON l.`lang_id` = t.`lang_id`
     WHERE l.`lang_abbr` = 'ru' AND t.`sell_status_name` = 'Под заказ');
SET @seed_id = IF(ROW_COUNT() > 0, LAST_INSERT_ID(), NULL);
INSERT IGNORE INTO `shop_sell_statuses_translation` (`sell_status_id`, `lang_id`, `sell_status_name`)
  SELECT @seed_id, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Під замовлення', 'Под заказ')
    FROM `share_languages` l WHERE @seed_id IS NOT NULL;

INSERT INTO `shop_sell_statuses` (`sell_status_order_num`)
  SELECT 3 FROM DUAL WHERE NOT EXISTS (
    SELECT 1 FROM `shop_sell_statuses_translation` t JOIN `share_languages` l ON l.`lang_id` = t.`lang_id`
     WHERE l.`lang_abbr` = 'ru' AND t.`sell_status_name` = 'Нет в наличии');
SET @seed_id = IF(ROW_COUNT() > 0, LAST_INSERT_ID(), NULL);
INSERT IGNORE INTO `shop_sell_statuses_translation` (`sell_status_id`, `lang_id`, `sell_status_name`)
  SELECT @seed_id, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Немає в наявності', 'Нет в наличии')
    FROM `share_languages` l WHERE @seed_id IS NOT NULL;

-- телефонный код — только цифры, маска — X на месте цифр номера
INSERT INTO `site_country` (`country_tel_code`, `country_tel_format`)
  SELECT '380', '(XX) XXX-XX-XX' FROM DUAL WHERE NOT EXISTS (
    SELECT 1 FROM `site_country_translation` t JOIN `share_languages` l ON l.`lang_id` = t.`lang_id`
     WHERE l.`lang_abbr` = 'ru' AND t.`country_name` = 'Украина');
SET @seed_id = IF(ROW_COUNT() > 0, LAST_INSERT_ID(), NULL);
INSERT IGNORE INTO `site_country_translation` (`country_id`, `lang_id`, `country_name`)
  SELECT @seed_id, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Україна', 'Украина')
    FROM `share_languages` l WHERE @seed_id IS NOT NULL;

SET @seed_id = NULL;

-- Валюта и страна сайта по умолчанию (цены в заказах, маска телефона), если ещё не заданы.
UPDATE `share_sites`
   SET `currency_id` = (SELECT `currency_id` FROM `shop_currencies` WHERE `currency_is_default` = 1 ORDER BY `currency_id` LIMIT 1)
 WHERE `site_is_default` = 1 AND `currency_id` IS NULL;
UPDATE `share_sites`
   SET `country_id` = (SELECT MIN(`country_id`) FROM `site_country`)
 WHERE `site_is_default` = 1 AND `country_id` IS NULL;

-- =============================================================================================
-- 5. Баннерное место и виджет «Баннер»
-- =============================================================================================
-- В режиме редактирования страницы виджет добавляется в любую колонку; место (type), число баннеров
-- и порядок меняются в параметрах виджета.
INSERT IGNORE INTO `ads_types` (`ads_type_sysname`, `ads_type_name`, `ads_type_width`, `ads_type_height`)
  VALUES ('sidebar', 'Боковая колонка', 240, 400);

INSERT INTO `share_widgets` (`widget_name`, `widget_xml`)
  SELECT 'Баннер', '<container name="AdsContainer" block="beta" widget="widget">
    <component class="Energine\\ads\\components\\Ads" name="Ads">
        <params>
            <param name="type">sidebar</param>
            <param name="limit">1</param>
            <param name="order">rand</param>
        </params>
    </component>
</container>'
    FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM `share_widgets` WHERE `widget_xml` LIKE '%Energine\\\\ads\\\\components\\\\Ads%');

-- =============================================================================================
-- 6. Страницы сайта и админки
-- =============================================================================================
-- parent: root — корень сайта, admin — /admin/, admin/blogs, admin/shop, catalog — вложенные разделы.
-- tags — коды тегов через запятую (menu — пункт меню). rights — группа:право через запятую, до трёх групп:
-- группы 1 — администраторы, 3 — гости, 4 — пользователи; права 1 — чтение, 2 — редактирование, 3 — полный доступ.
-- Уже существующие разделы (по родителю и сегменту) не трогаются.
SET @site := (SELECT `site_id` FROM `share_sites` WHERE `site_is_default` = 1 ORDER BY `site_id` LIMIT 1);
SET @root := (SELECT `smap_id` FROM `share_sitemap` WHERE `site_id` = @site AND `smap_pid` IS NULL LIMIT 1);
SET @admin := (SELECT `smap_id` FROM `share_sitemap` WHERE `site_id` = @site AND `smap_pid` = @root AND `smap_segment` = 'admin' LIMIT 1);

CREATE TEMPORARY TABLE `tmp_pages` (
  `parent` varchar(50) NOT NULL,
  `segment` varchar(50) NOT NULL,
  `content` varchar(200) NOT NULL,
  `order_num` int(10) unsigned NOT NULL,
  `tags` varchar(100) DEFAULT NULL,
  `rights` varchar(50) NOT NULL,
  `name_ru` varchar(200) NOT NULL,
  `name_ua` varchar(200) NOT NULL
) DEFAULT CHARSET=utf8;

INSERT INTO `tmp_pages` VALUES
  -- mail
  ('admin', 'mail-templates', 'mail_templates_editor.content.xml', 14, 'menu', '1:3', 'Шаблоны писем', 'Шаблони листів'),
  ('admin', 'mail-subscriptions', 'mail_subscription_editor.content.xml', 15, 'menu', '1:3', 'Рассылки', 'Розсилки'),
  ('admin', 'mail-subscribers', 'mail_email_subscription_editor.content.xml', 16, 'menu', '1:3', 'Подписчики рассылок', 'Підписники розсилок'),
  ('admin', 'mail-crm', 'mail_crm_editor.content.xml', 17, 'menu', '1:3', 'Сообщения рассылки', 'Повідомлення розсилки'),
  ('root', 'subscribe', 'email_subscription.content.xml', 16, 'menu', '1:3,3:1,4:1', 'Подписка на рассылку', 'Підписка на розсилку'),
  -- «Мои подписки» только для зарегистрированных: у гостя нет u_id
  ('root', 'subscriptions', 'subscriptions.content.xml', 17, 'menu', '1:3,4:2', 'Мои подписки', 'Мої підписки'),
  -- ads; banners — корень рубрик баннеров (тег ads), сам раздел скрыт
  ('admin', 'ads-types', 'ads_type_editor.content.xml', 18, 'menu', '1:3', 'Баннерные места', 'Банерні місця'),
  ('admin', 'ads-items', 'ads_item_editor.content.xml', 19, 'menu', '1:3', 'Баннеры', 'Банери'),
  ('root', 'banners', 'childs.content.xml', 400, 'ads', '1:3', 'Рубрики баннеров', 'Рубрики банерів'),
  -- blog
  ('root', 'blogs', 'blog_post.content.xml', 15, 'menu', '1:3,3:1,4:1', 'Блоги', 'Блоги'),
  ('admin', 'blogs', 'blog_editor.content.xml', 20, 'menu', '1:3', 'Блоги', 'Блоги'),
  ('admin/blogs', 'posts', 'blog_post_editor.content.xml', 1, 'menu', '1:3', 'Записи блогов', 'Записи блогів'),
  ('admin/blogs', 'comments', 'blog_comments_editor.content.xml', 2, 'menu', '1:3', 'Комментарии блогов', 'Коментарі блогів'),
  -- shop: админка
  ('admin', 'shop', 'childs.content.xml', 21, 'menu', '1:3', 'Магазин', 'Магазин'),
  ('admin/shop', 'goods', 'goods_editor.content.xml', 1, 'menu', '1:3', 'Товары', 'Товари'),
  ('admin/shop', 'categories', 'category_editor.content.xml', 2, 'menu', '1:3', 'Категории', 'Категорії'),
  ('admin/shop', 'orders', 'order_editor.content.xml', 3, 'menu', '1:3', 'Заказы', 'Замовлення'),
  ('admin/shop', 'features', 'feature_editor.content.xml', 4, 'menu', '1:3', 'Характеристики', 'Характеристики'),
  ('admin/shop', 'feature-groups', 'feature_group_editor.content.xml', 5, 'menu', '1:3', 'Группы характеристик', 'Групи характеристик'),
  ('admin/shop', 'producers', 'producer_editor.content.xml', 6, 'menu', '1:3', 'Производители', 'Виробники'),
  ('admin/shop', 'promotions', 'promotion_editor.content.xml', 7, 'menu', '1:3', 'Акции', 'Акції'),
  ('admin/shop', 'order-statuses', 'order_status_editor.content.xml', 8, 'menu', '1:3', 'Статусы заказов', 'Статуси замовлень'),
  ('admin/shop', 'delivery-types', 'delivery_types_editor.content.xml', 9, 'menu', '1:3', 'Способы доставки', 'Способи доставки'),
  ('admin/shop', 'payment-types', 'payment_types_editor.content.xml', 10, 'menu', '1:3', 'Способы оплаты', 'Способи оплати'),
  ('admin/shop', 'currencies', 'currency_editor.content.xml', 11, 'menu', '1:3', 'Валюты', 'Валюти'),
  ('admin/shop', 'sites', 'shop_editor.content.xml', 12, 'menu', '1:3', 'Магазины', 'Магазини'),
  ('admin/shop', 'countries', 'country_editor.content.xml', 13, 'menu', '1:3', 'Страны', 'Країни'),
  -- shop: сайт; catalog — корень категорий (тег catalogue), products — первая категория
  ('root', 'catalog', 'catalog.content.xml', 12, 'menu,catalogue', '1:3,3:1,4:1', 'Каталог', 'Каталог'),
  ('catalog', 'products', 'catalog_products.content.xml', 1, NULL, '1:3,3:1,4:1', 'Товары', 'Товари'),
  ('root', 'search', 'search.content.xml', 402, NULL, '1:3,3:1,4:1', 'Поиск товаров', 'Пошук товарів'),
  ('root', 'cart', 'cart.content.xml', 403, NULL, '1:3,3:1,4:1', 'Корзина', 'Кошик'),
  ('root', 'wishlist', 'wishlist.content.xml', 404, NULL, '1:3,4:2', 'Избранное', 'Обране'),
  ('root', 'my-orders', 'order_list.content.xml', 405, NULL, '1:3,4:2', 'Мои заказы', 'Мої замовлення');

CREATE TEMPORARY TABLE `tmp_parents` (`parent` varchar(50) NOT NULL, `smap_id` int(10) unsigned NOT NULL) DEFAULT CHARSET=utf8;
INSERT INTO `tmp_parents` VALUES ('root', @root), ('admin', @admin);

-- первый уровень: родители root и admin
INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', p.`content`, pp.`smap_id`, p.`segment`, p.`order_num`
    FROM `tmp_pages` p JOIN `tmp_parents` pp USING(`parent`)
   WHERE NOT EXISTS (SELECT 1 FROM `share_sitemap` s WHERE s.`site_id` = @site AND s.`smap_pid` = pp.`smap_id` AND s.`smap_segment` = p.`segment`);

-- второй уровень: родители созданы выше
INSERT INTO `tmp_parents`
  SELECT CONCAT('admin/', `smap_segment`), `smap_id` FROM `share_sitemap`
   WHERE `site_id` = @site AND `smap_pid` = @admin AND `smap_segment` IN ('blogs', 'shop');
INSERT INTO `tmp_parents`
  SELECT `smap_segment`, `smap_id` FROM `share_sitemap`
   WHERE `site_id` = @site AND `smap_pid` = @root AND `smap_segment` = 'catalog';

INSERT INTO `share_sitemap` (`site_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_order_num`)
  SELECT @site, 'default.layout.xml', p.`content`, pp.`smap_id`, p.`segment`, p.`order_num`
    FROM `tmp_pages` p JOIN `tmp_parents` pp USING(`parent`)
   WHERE p.`parent` NOT IN ('root', 'admin')
     AND NOT EXISTS (SELECT 1 FROM `share_sitemap` s WHERE s.`site_id` = @site AND s.`smap_pid` = pp.`smap_id` AND s.`smap_segment` = p.`segment`)
     -- «Товары» - заготовка первой категории для пустого каталога. Если категории
     -- уже есть (демо-контент переименовывает её в phones и добавляет свои),
     -- повторный импорт не должен создавать её заново.
     AND NOT (p.`parent` = 'catalog'
              AND EXISTS (SELECT 1 FROM `share_sitemap` c WHERE c.`smap_pid` = pp.`smap_id`));

CREATE TEMPORARY TABLE `tmp_page_ids` (`parent` varchar(50) NOT NULL, `segment` varchar(50) NOT NULL, `smap_id` int(10) unsigned NOT NULL) DEFAULT CHARSET=utf8;
INSERT INTO `tmp_page_ids`
  SELECT p.`parent`, p.`segment`, s.`smap_id`
    FROM `tmp_pages` p JOIN `tmp_parents` pp USING(`parent`)
    JOIN `share_sitemap` s ON s.`site_id` = @site AND s.`smap_pid` = pp.`smap_id` AND s.`smap_segment` = p.`segment`;

INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`)
  SELECT i.`smap_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', p.`name_ua`, p.`name_ru`)
    FROM `tmp_pages` p JOIN `tmp_page_ids` i USING(`parent`, `segment`) CROSS JOIN `share_languages` l;

INSERT IGNORE INTO `share_sitemap_tags` (`smap_id`, `tag_id`)
  SELECT i.`smap_id`, t.`tag_id`
    FROM `tmp_pages` p JOIN `tmp_page_ids` i USING(`parent`, `segment`)
    JOIN `share_tags` t ON FIND_IN_SET(t.`tag_code`, p.`tags`);

-- '1:3,4:2' -> (1, 3), (4, 2)
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
  SELECT i.`smap_id`,
         SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(p.`rights`, ',', n.`n`), ',', -1), ':', 1),
         SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(p.`rights`, ',', n.`n`), ',', -1), ':', -1)
    FROM `tmp_pages` p JOIN `tmp_page_ids` i USING(`parent`, `segment`)
    JOIN (SELECT 1 AS `n` UNION ALL SELECT 2 UNION ALL SELECT 3) n
      ON n.`n` <= 1 + LENGTH(p.`rights`) - LENGTH(REPLACE(p.`rights`, ',', ''));

DROP TEMPORARY TABLE `tmp_page_ids`;
DROP TEMPORARY TABLE `tmp_parents`;
DROP TEMPORARY TABLE `tmp_pages`;
