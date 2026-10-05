-- Схема модулей ядра mail, ads, blog и shop — таблиц, которых нет в starter.structure.sql.
-- SQL для этих модулей в апстриме не публиковался: схема восстановлена по коду модулей
-- (запросы, конфиги редакторов, шаблоны) и проверена на PHP 8.5 и MariaDB 10.11.
-- Импортировать после starter.structure.sql и starter.structure.fixes.sql, затем modules.data.sql.
-- Повторный запуск ничего не меняет: CREATE ... IF NOT EXISTS, ALTER ... IF NOT EXISTS.
--
-- Как схема превращается в формы админки (share/gears/DBStructureInfo.php, FieldDescription::convertType()):
--   tinyint(1) -> флажок; enum -> список (подписи FIELD_<ПОЛЕ>_ENUM_<ЗНАЧЕНИЕ>); int с FOREIGN KEY -> список
--   или lookup (подпись — колонка <префикс>_name ссылочной таблицы или её _translation); *_rtf -> HTML-редактор;
--   datetime -> дата и время; decimal(10,2) -> сумма; *_img, *_email, *_phone -> соответствующие поля.
--   Внешние ключи только по одной колонке, в COMMENT колонок не использовать скобки (разбор SHOW CREATE TABLE).
--   Колонки, которых нет среди полей редактора, должны допускать NULL или иметь DEFAULT (STRICT_TRANS_TABLES).
--   Поле *_multi: в основной таблице фиктивная колонка (всегда NULL) с FOREIGN KEY на таблицу связи;
--   таблица связи находится только по этому ключу, её колонка-значение тоже должна быть внешним ключом.
--   Строки вкладок (файлы, значения, товары заказа...), добавленные до сохранения родительской записи,
--   хранятся с NULL в ключе родителя и session_id и привязываются при сохранении — такие ключи NULL-able.

SET NAMES utf8;
SET FOREIGN_KEY_CHECKS=0;

-- =============================================================================================
-- mail: шаблоны писем, рассылки, подписчики
-- =============================================================================================

-- Шаблоны писем (mail/gears/MailTemplate.php): ищутся по template_sysname среди активных.
-- Используются регистрацией, восстановлением пароля, обратной связью и рассылками.
CREATE TABLE IF NOT EXISTS `mail_templates` (
  `template_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `template_sysname` varchar(100) NOT NULL,
  `template_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `template_hints` text DEFAULT NULL,
  PRIMARY KEY (`template_id`),
  UNIQUE KEY `template_sysname` (`template_sysname`),
  KEY `template_is_active` (`template_is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Тема и текст письма: template_body — текстовая часть, template_body_rtf — HTML.
-- Тема необязательна: шаблоны *_item описывают один элемент внутри письма рассылки.
CREATE TABLE IF NOT EXISTS `mail_templates_translation` (
  `template_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `template_name` varchar(255) NOT NULL,
  `template_subject` varchar(255) DEFAULT NULL,
  `template_body` text DEFAULT NULL,
  `template_body_rtf` mediumtext DEFAULT NULL,
  PRIMARY KEY (`template_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `mail_templates_translation_ibfk_1` FOREIGN KEY (`template_id`) REFERENCES `mail_templates` (`template_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_templates_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Рассылки. subscription_type выбирает источник данных из конфига mail.subscriptions.<тип>
-- (MailSourceNews, MailSourceCRM); MailProcessor отправляет по периоду и пишет subscription_sent_date.
CREATE TABLE IF NOT EXISTS `mail_subscriptions` (
  `subscription_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `subscription_type` enum('news','crm') NOT NULL DEFAULT 'news',
  `subscription_period` enum('hourly','daily','weekly','monthly') NOT NULL DEFAULT 'daily',
  `subscription_sent_date` datetime DEFAULT NULL,
  `subscription_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `subscription_is_default` tinyint(1) NOT NULL DEFAULT 0,
  `subscription_is_hidden` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`subscription_id`),
  KEY `subscription_is_active` (`subscription_is_active`),
  KEY `subscription_is_default` (`subscription_is_default`),
  KEY `subscription_is_hidden` (`subscription_is_hidden`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `mail_subscriptions_translation` (
  `subscription_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `subscription_name` varchar(255) NOT NULL,
  `subscription_description` text DEFAULT NULL,
  PRIMARY KEY (`subscription_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `mail_subscriptions_translation_ibfk_1` FOREIGN KEY (`subscription_id`) REFERENCES `mail_subscriptions` (`subscription_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_subscriptions_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Подписанные зарегистрированные пользователи (вкладка редактора рассылок и «Мои подписки»).
-- u_id — настоящий внешний ключ: на нём работает выбор пользователя (lookup).
CREATE TABLE IF NOT EXISTS `mail_subscriptions2users` (
  `su_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `subscription_id` int(10) unsigned DEFAULT NULL,
  `u_id` int(10) unsigned NOT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`su_id`),
  KEY `subscription_id` (`subscription_id`),
  KEY `u_id` (`u_id`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `mail_subscriptions2users_ibfk_1` FOREIGN KEY (`subscription_id`) REFERENCES `mail_subscriptions` (`subscription_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_subscriptions2users_ibfk_2` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Подписчики по e-mail без регистрации. Адрес лежит в me_name: по колонке <префикс>_name ядро
-- строит подписи списков и lookup.
CREATE TABLE IF NOT EXISTS `mail_email_subscribers` (
  `me_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `me_name` varchar(255) NOT NULL,
  `me_date` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`me_id`),
  UNIQUE KEY `me_name` (`me_name`),
  KEY `me_date` (`me_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Подписки e-mail на рассылки (вкладка «Подписанные e-mail» редактора рассылок).
CREATE TABLE IF NOT EXISTS `mail_email2subscriptions` (
  `mes_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `me_id` int(10) unsigned NOT NULL,
  `subscription_id` int(10) unsigned DEFAULT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`mes_id`),
  KEY `me_id` (`me_id`),
  KEY `subscription_id` (`subscription_id`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `mail_email2subscriptions_ibfk_1` FOREIGN KEY (`me_id`) REFERENCES `mail_email_subscribers` (`me_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_email2subscriptions_ibfk_2` FOREIGN KEY (`subscription_id`) REFERENCES `mail_subscriptions` (`subscription_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Сообщения информационной рассылки (тип crm), редактируются обычным Grid.
CREATE TABLE IF NOT EXISTS `mail_crm` (
  `crm_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `crm_date` datetime NOT NULL,
  `crm_is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`crm_id`),
  KEY `crm_date` (`crm_date`),
  KEY `crm_is_active` (`crm_is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `mail_crm_translation` (
  `crm_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `crm_name` varchar(255) NOT NULL,
  `crm_text_rtf` text NOT NULL,
  PRIMARY KEY (`crm_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `mail_crm_translation_ibfk_1` FOREIGN KEY (`crm_id`) REFERENCES `mail_crm` (`crm_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `mail_crm_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- =============================================================================================
-- ads: баннерные места и баннеры (не путать с таблицей apps_ads старого AdsManager модуля apps)
-- =============================================================================================

-- Баннерные места: компонент Ads выбирает место по ads_type_sysname (параметр type), размеры задают
-- размер картинки баннера.
CREATE TABLE IF NOT EXISTS `ads_types` (
  `ads_type_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ads_type_sysname` varchar(50) NOT NULL,
  `ads_type_name` varchar(255) NOT NULL,
  `ads_type_width` int(10) unsigned DEFAULT NULL,
  `ads_type_height` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`ads_type_id`),
  UNIQUE KEY `ads_type_sysname` (`ads_type_sysname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Баннеры: картинка со ссылкой (image) или HTML-код (html) — AdsItemForm.js показывает нужные поля,
-- поэтому img/url/html допускают NULL. Сайты и рубрики — поля *_multi (таблицы связи ниже).
-- Без таблицы переводов: баннер один на все языки.
CREATE TABLE IF NOT EXISTS `ads_items` (
  `ads_item_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ads_type_id` int(10) unsigned NOT NULL,
  `ads_item_name` varchar(255) NOT NULL,
  `ads_item_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `ads_item_mode` enum('image','html') NOT NULL DEFAULT 'image',
  `ads_item_img` varchar(255) DEFAULT NULL,
  `ads_item_url` varchar(255) DEFAULT NULL,
  `ads_item_html` text DEFAULT NULL,
  `ads_item_site_multi` int(10) unsigned DEFAULT NULL,
  `ads_item_smap_multi` int(10) unsigned DEFAULT NULL,
  `ads_item_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`ads_item_id`),
  KEY `ads_type_id` (`ads_type_id`),
  KEY `ads_item_is_active` (`ads_item_is_active`),
  KEY `ads_item_site_multi` (`ads_item_site_multi`),
  KEY `ads_item_smap_multi` (`ads_item_smap_multi`),
  KEY `ads_item_order_num` (`ads_item_order_num`),
  CONSTRAINT `ads_items_ibfk_1` FOREIGN KEY (`ads_type_id`) REFERENCES `ads_types` (`ads_type_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `ads_items_ibfk_2` FOREIGN KEY (`ads_item_site_multi`) REFERENCES `ads_items2sites` (`ads_item_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `ads_items_ibfk_3` FOREIGN KEY (`ads_item_smap_multi`) REFERENCES `ads_items2sitemap` (`ads_item_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Сайты баннера (в списке — сайты с тегом shop). Имя таблицы задано в AdsItemEditor.
CREATE TABLE IF NOT EXISTS `ads_items2sites` (
  `ads_item_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`ads_item_id`,`site_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `ads_items2sites_ibfk_1` FOREIGN KEY (`ads_item_id`) REFERENCES `ads_items` (`ads_item_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `ads_items2sites_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Рубрики баннера: разделы под страницей с тегом ads (параметр rootTag редактора баннеров).
-- Код обращается к таблице только через внешний ключ ads_item_smap_multi, имя выбрано по аналогии.
CREATE TABLE IF NOT EXISTS `ads_items2sitemap` (
  `ads_item_id` int(10) unsigned NOT NULL,
  `smap_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`ads_item_id`,`smap_id`),
  KEY `smap_id` (`smap_id`),
  CONSTRAINT `ads_items2sitemap_ibfk_1` FOREIGN KEY (`ads_item_id`) REFERENCES `ads_items` (`ads_item_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `ads_items2sitemap_ibfk_2` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- =============================================================================================
-- blog: блоги пользователей, записи, комментарии
-- =============================================================================================

-- Блог пользователя. Уникальность u_id не требуется: пользователь пишет в свой первый блог.
CREATE TABLE IF NOT EXISTS `blog_title` (
  `blog_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `blog_name` varchar(255) NOT NULL,
  `u_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`blog_id`),
  KEY `u_id` (`u_id`),
  CONSTRAINT `blog_title_ibfk_1` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Записи. Запись с post_created в будущем на сайте не показывается до наступления даты.
CREATE TABLE IF NOT EXISTS `blog_post` (
  `post_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `blog_id` int(10) unsigned NOT NULL,
  `post_created` datetime NOT NULL,
  `post_name` varchar(255) NOT NULL,
  `post_text_rtf` mediumtext NOT NULL,
  PRIMARY KEY (`post_id`),
  KEY `blog_id` (`blog_id`),
  KEY `post_created` (`post_created`),
  CONSTRAINT `blog_post_ibfk_1` FOREIGN KEY (`blog_id`) REFERENCES `blog_title` (`blog_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Комментарии к записям (модуль comments: таблица <таблица записей>_comment, как apps_news_comment).
CREATE TABLE IF NOT EXISTS `blog_post_comment` (
  `comment_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `comment_parent_id` int(10) unsigned DEFAULT NULL,
  `target_id` int(10) unsigned NOT NULL,
  `u_id` int(10) unsigned DEFAULT NULL,
  `comment_created` datetime NOT NULL,
  `comment_name` varchar(250) NOT NULL,
  `comment_approved` tinyint(1) NOT NULL DEFAULT 0,
  `comment_nick` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`comment_id`),
  KEY `parent_id` (`comment_parent_id`),
  KEY `target_id` (`target_id`),
  KEY `u_id` (`u_id`),
  CONSTRAINT `blog_post_comment_ibfk_1` FOREIGN KEY (`comment_parent_id`) REFERENCES `blog_post_comment` (`comment_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `blog_post_comment_ibfk_2` FOREIGN KEY (`target_id`) REFERENCES `blog_post` (`post_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `blog_post_comment_ibfk_3` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- =============================================================================================
-- shop: справочники, производители, характеристики, товары, акции, заказы, корзина
-- =============================================================================================

-- Валюты: gears/Currency.php требует хотя бы одну активную валюту с currency_is_default = 1.
-- currency_rate — стоимость единицы валюты в базовой валюте.
CREATE TABLE IF NOT EXISTS `shop_currencies` (
  `currency_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `currency_code` char(3) NOT NULL,
  `currency_shortname` varchar(20) NOT NULL,
  `currency_shortname_order` enum('before','after') NOT NULL DEFAULT 'after',
  `currency_rate` decimal(10,4) NOT NULL DEFAULT 1.0000,
  `currency_is_default` tinyint(1) NOT NULL DEFAULT 0,
  `currency_is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`currency_id`),
  UNIQUE KEY `currency_code` (`currency_code`),
  KEY `currency_is_default` (`currency_is_default`),
  KEY `currency_is_active` (`currency_is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_currencies_translation` (
  `currency_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `currency_name` varchar(100) NOT NULL,
  PRIMARY KEY (`currency_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_currencies_translation_ibfk_1` FOREIGN KEY (`currency_id`) REFERENCES `shop_currencies` (`currency_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_currencies_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Наличие товара (shop_goods.sell_status_id, lookup в редакторе и списке товаров).
-- В коде есть только внешний ключ, имя таблицы выбрано по соглашениям ядра.
CREATE TABLE IF NOT EXISTS `shop_sell_statuses` (
  `sell_status_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sell_status_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`sell_status_id`),
  KEY `sell_status_order_num` (`sell_status_order_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_sell_statuses_translation` (
  `sell_status_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `sell_status_name` varchar(100) NOT NULL,
  PRIMARY KEY (`sell_status_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_sell_statuses_translation_ibfk_1` FOREIGN KEY (`sell_status_id`) REFERENCES `shop_sell_statuses` (`sell_status_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_sell_statuses_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Статусы заказов: gears/OrderStatus.php ищет системные имена new (первый по порядку) и valid.
CREATE TABLE IF NOT EXISTS `shop_order_statuses` (
  `status_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `status_sysname` varchar(50) NOT NULL,
  `status_is_cancellable` tinyint(1) NOT NULL DEFAULT 0,
  `status_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `status_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`status_id`),
  UNIQUE KEY `status_sysname` (`status_sysname`),
  KEY `status_is_active` (`status_is_active`),
  KEY `status_order_num` (`status_order_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_order_statuses_translation` (
  `status_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `status_name` varchar(100) NOT NULL,
  PRIMARY KEY (`status_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_order_statuses_translation_ibfk_1` FOREIGN KEY (`status_id`) REFERENCES `shop_order_statuses` (`status_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_order_statuses_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Способы доставки и оплаты (списки в редакторе заказов).
CREATE TABLE IF NOT EXISTS `shop_delivery_types` (
  `type_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type_sysname` varchar(50) NOT NULL,
  `type_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `type_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`type_id`),
  UNIQUE KEY `type_sysname` (`type_sysname`),
  KEY `type_is_active` (`type_is_active`),
  KEY `type_order_num` (`type_order_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_delivery_types_translation` (
  `type_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `type_name` varchar(100) NOT NULL,
  PRIMARY KEY (`type_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_delivery_types_translation_ibfk_1` FOREIGN KEY (`type_id`) REFERENCES `shop_delivery_types` (`type_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_delivery_types_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_payment_types` (
  `type_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type_sysname` varchar(50) NOT NULL,
  `type_is_online` tinyint(1) NOT NULL DEFAULT 0,
  `type_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `type_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`type_id`),
  UNIQUE KEY `type_sysname` (`type_sysname`),
  KEY `type_is_active` (`type_is_active`),
  KEY `type_order_num` (`type_order_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_payment_types_translation` (
  `type_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `type_name` varchar(100) NOT NULL,
  PRIMARY KEY (`type_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_payment_types_translation_ibfk_1` FOREIGN KEY (`type_id`) REFERENCES `shop_payment_types` (`type_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_payment_types_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Страны (справочник уровня сайта): share_sites.country_id задаёт маску и код телефона в заказах
-- (share/gears/GridExtender.php). country_tel_code — цифры кода без «+».
CREATE TABLE IF NOT EXISTS `site_country` (
  `country_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `country_tel_code` varchar(10) DEFAULT NULL,
  `country_tel_format` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`country_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `site_country_translation` (
  `country_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `country_name` varchar(100) NOT NULL,
  PRIMARY KEY (`country_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `site_country_translation_ibfk_1` FOREIGN KEY (`country_id`) REFERENCES `site_country` (`country_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `site_country_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Производители. producer_segment заполняется из названия, если пуст; магазины — поле *_multi.
CREATE TABLE IF NOT EXISTS `shop_producers` (
  `producer_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `producer_segment` varchar(255) DEFAULT NULL,
  `producer_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `producer_site_multi` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`producer_id`),
  KEY `producer_segment` (`producer_segment`),
  KEY `producer_is_active` (`producer_is_active`),
  KEY `producer_site_multi` (`producer_site_multi`),
  CONSTRAINT `shop_producers_ibfk_1` FOREIGN KEY (`producer_site_multi`) REFERENCES `shop_producers2sites` (`producer_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_producers_translation` (
  `producer_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `producer_name` varchar(255) NOT NULL,
  PRIMARY KEY (`producer_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_producers_translation_ibfk_1` FOREIGN KEY (`producer_id`) REFERENCES `shop_producers` (`producer_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_producers_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_producers2sites` (
  `producer_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`producer_id`,`site_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `shop_producers2sites_ibfk_1` FOREIGN KEY (`producer_id`) REFERENCES `shop_producers` (`producer_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_producers2sites_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Группы характеристик (порядок групп на странице товара).
CREATE TABLE IF NOT EXISTS `shop_feature_groups` (
  `group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `group_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`group_id`),
  KEY `group_is_active` (`group_is_active`),
  KEY `group_order_num` (`group_order_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_feature_groups_translation` (
  `group_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `group_name` varchar(255) NOT NULL,
  `group_description` text DEFAULT NULL,
  PRIMARY KEY (`group_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_feature_groups_translation_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `shop_feature_groups` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_feature_groups_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Характеристики товаров: тип значения, вид фильтра, магазины и категории (поля *_multi).
-- Набор колонок совпадает со списком, который копирует FeatureEditor::copy().
CREATE TABLE IF NOT EXISTS `shop_features` (
  `feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int(10) unsigned DEFAULT NULL,
  `feature_type` enum('STRING','INT','BOOL','OPTION','MULTIOPTION','VARIANT') NOT NULL DEFAULT 'STRING',
  `feature_site_multi` int(10) unsigned DEFAULT NULL,
  `feature_smap_multi` int(10) unsigned DEFAULT NULL,
  `feature_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `feature_is_filter` tinyint(1) NOT NULL DEFAULT 0,
  `feature_is_order_param` tinyint(1) NOT NULL DEFAULT 0,
  `feature_is_main` tinyint(1) NOT NULL DEFAULT 0,
  `feature_sysname` varchar(100) DEFAULT NULL,
  `feature_filter_type` enum('DEFAULT','RADIOGROUP','CHECKBOXGROUP','SELECT','RANGE') NOT NULL DEFAULT 'DEFAULT',
  `feature_order_num` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`feature_id`),
  KEY `group_id` (`group_id`),
  KEY `feature_site_multi` (`feature_site_multi`),
  KEY `feature_smap_multi` (`feature_smap_multi`),
  KEY `feature_is_active` (`feature_is_active`),
  KEY `feature_is_filter` (`feature_is_filter`),
  KEY `feature_sysname` (`feature_sysname`),
  KEY `feature_order_num` (`feature_order_num`),
  CONSTRAINT `shop_features_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `shop_feature_groups` (`group_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_features_ibfk_2` FOREIGN KEY (`feature_site_multi`) REFERENCES `shop_features2sites` (`feature_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_features_ibfk_3` FOREIGN KEY (`feature_smap_multi`) REFERENCES `shop_sitemap2features` (`feature_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_features_translation` (
  `feature_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `feature_name` varchar(255) NOT NULL,
  `feature_title` varchar(255) DEFAULT NULL,
  `feature_description` text DEFAULT NULL,
  `feature_unit` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`feature_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_features_translation_ibfk_1` FOREIGN KEY (`feature_id`) REFERENCES `shop_features` (`feature_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_features_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_features2sites` (
  `feature_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`feature_id`,`site_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `shop_features2sites_ibfk_1` FOREIGN KEY (`feature_id`) REFERENCES `shop_features` (`feature_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_features2sites_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Характеристики категорий. Таблица обслуживает два поля *_multi — shop_features.feature_smap_multi
-- и share_sitemap.smap_features_multi, поэтому в ней ровно две колонки, обе с внешними ключами.
CREATE TABLE IF NOT EXISTS `shop_sitemap2features` (
  `smap_id` int(10) unsigned NOT NULL,
  `feature_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`smap_id`,`feature_id`),
  KEY `feature_id` (`feature_id`),
  CONSTRAINT `shop_sitemap2features_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_sitemap2features_ibfk_2` FOREIGN KEY (`feature_id`) REFERENCES `shop_features` (`feature_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Значения характеристик типа OPTION/MULTIOPTION/VARIANT (вкладка редактора характеристик).
CREATE TABLE IF NOT EXISTS `shop_feature_options` (
  `option_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `feature_id` int(10) unsigned DEFAULT NULL,
  `option_img` varchar(255) DEFAULT NULL,
  `option_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`option_id`),
  KEY `feature_id` (`feature_id`),
  KEY `option_order_num` (`option_order_num`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_feature_options_ibfk_1` FOREIGN KEY (`feature_id`) REFERENCES `shop_features` (`feature_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_feature_options_translation` (
  `option_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `option_value` varchar(255) NOT NULL,
  PRIMARY KEY (`option_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_feature_options_translation_ibfk_1` FOREIGN KEY (`option_id`) REFERENCES `shop_feature_options` (`option_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_feature_options_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Товары. smap_id — категория (раздел под страницей с тегом catalogue); goods_segment заполняется
-- из названия, если пуст.
CREATE TABLE IF NOT EXISTS `shop_goods` (
  `goods_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `smap_id` int(10) unsigned NOT NULL,
  `goods_segment` varchar(255) DEFAULT NULL,
  `producer_id` int(10) unsigned DEFAULT NULL,
  `sell_status_id` int(10) unsigned DEFAULT NULL,
  `goods_type` varchar(50) DEFAULT NULL,
  `goods_code` varchar(100) DEFAULT NULL,
  `currency_id` int(10) unsigned DEFAULT NULL,
  `goods_price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `goods_price_old` decimal(10,2) DEFAULT NULL,
  `goods_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `goods_date` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`goods_id`),
  KEY `smap_id` (`smap_id`),
  KEY `goods_segment` (`goods_segment`),
  KEY `producer_id` (`producer_id`),
  KEY `sell_status_id` (`sell_status_id`),
  KEY `goods_code` (`goods_code`),
  KEY `currency_id` (`currency_id`),
  KEY `goods_price` (`goods_price`),
  KEY `goods_is_active` (`goods_is_active`),
  KEY `goods_date` (`goods_date`),
  CONSTRAINT `shop_goods_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_ibfk_2` FOREIGN KEY (`producer_id`) REFERENCES `shop_producers` (`producer_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_ibfk_3` FOREIGN KEY (`sell_status_id`) REFERENCES `shop_sell_statuses` (`sell_status_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_ibfk_4` FOREIGN KEY (`currency_id`) REFERENCES `shop_currencies` (`currency_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Название, описание и SEO-поля товара.
CREATE TABLE IF NOT EXISTS `shop_goods_translation` (
  `goods_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `goods_name` varchar(255) NOT NULL,
  `goods_short_description` text DEFAULT NULL,
  `goods_description_rtf` mediumtext DEFAULT NULL,
  `goods_seo_title` varchar(255) DEFAULT NULL,
  `goods_seo_keywords` text DEFAULT NULL,
  `goods_seo_description` text DEFAULT NULL,
  PRIMARY KEY (`goods_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  KEY `goods_name` (`goods_name`),
  CONSTRAINT `shop_goods_translation_ibfk_1` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Изображения товара (соглашение AttachmentManager: <таблица>_uploads, как apps_news_uploads).
CREATE TABLE IF NOT EXISTS `shop_goods_uploads` (
  `sgu_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `goods_id` int(10) unsigned DEFAULT NULL,
  `upl_id` int(10) unsigned NOT NULL,
  `sgu_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`sgu_id`),
  KEY `goods_id` (`goods_id`),
  KEY `upl_id` (`upl_id`),
  KEY `session_id` (`session_id`),
  KEY `sgu_order_num` (`sgu_order_num`),
  CONSTRAINT `shop_goods_uploads_ibfk_1` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_uploads_ibfk_2` FOREIGN KEY (`upl_id`) REFERENCES `share_uploads` (`upl_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Теги товара (соглашение TagManager: первая колонка — id сущности, затем tag_id).
CREATE TABLE IF NOT EXISTS `shop_goods_tags` (
  `goods_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`goods_id`,`tag_id`),
  KEY `tag_id` (`tag_id`),
  CONSTRAINT `shop_goods_tags_ibfk_1` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_tags_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `share_tags` (`tag_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Значения характеристик товара (вкладка «Характеристики» редактора товаров).
-- Уникального ключа (goods_id, feature_id) нет: сохранение товара может создавать повторы.
CREATE TABLE IF NOT EXISTS `shop_feature2good_values` (
  `fpv_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `goods_id` int(10) unsigned DEFAULT NULL,
  `feature_id` int(10) unsigned NOT NULL,
  `fpv_order_num` int(10) unsigned DEFAULT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`fpv_id`),
  KEY `goods_id` (`goods_id`),
  KEY `feature_id` (`feature_id`),
  KEY `fpv_order_num` (`fpv_order_num`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_feature2good_values_ibfk_1` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_feature2good_values_ibfk_2` FOREIGN KEY (`feature_id`) REFERENCES `shop_features` (`feature_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- fpv_data: строка, число, флаг или id значений через запятую (FIND_IN_SET); строки создаются без значения.
CREATE TABLE IF NOT EXISTS `shop_feature2good_values_translation` (
  `fpv_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `fpv_data` text DEFAULT NULL,
  PRIMARY KEY (`fpv_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_feature2good_values_translation_ibfk_1` FOREIGN KEY (`fpv_id`) REFERENCES `shop_feature2good_values` (`fpv_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_feature2good_values_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Связанные товары (блок «Похожие товары» под товаром — relation_type = similar).
CREATE TABLE IF NOT EXISTS `shop_goods_relations` (
  `relation_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `goods_from_id` int(10) unsigned DEFAULT NULL,
  `goods_to_id` int(10) unsigned NOT NULL,
  `relation_type` enum('similar','accessory') NOT NULL DEFAULT 'similar',
  `relation_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`relation_id`),
  KEY `goods_from_id` (`goods_from_id`),
  KEY `goods_to_id` (`goods_to_id`),
  KEY `relation_type` (`relation_type`),
  KEY `relation_order_num` (`relation_order_num`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_goods_relations_ibfk_1` FOREIGN KEY (`goods_from_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods_relations_ibfk_2` FOREIGN KEY (`goods_to_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Акции: активны между датами начала и окончания.
CREATE TABLE IF NOT EXISTS `shop_promotions` (
  `promotion_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned DEFAULT NULL,
  `promotion_is_active` tinyint(1) NOT NULL DEFAULT 1,
  `promotion_start_date` datetime NOT NULL,
  `promotion_end_date` datetime NOT NULL,
  PRIMARY KEY (`promotion_id`),
  KEY `site_id` (`site_id`),
  KEY `promotion_is_active` (`promotion_is_active`),
  KEY `promotion_start_date` (`promotion_start_date`),
  KEY `promotion_end_date` (`promotion_end_date`),
  CONSTRAINT `shop_promotions_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `shop_promotions_translation` (
  `promotion_id` int(10) unsigned NOT NULL,
  `lang_id` int(10) unsigned NOT NULL,
  `promotion_name` varchar(255) NOT NULL,
  PRIMARY KEY (`promotion_id`,`lang_id`),
  KEY `lang_id` (`lang_id`),
  CONSTRAINT `shop_promotions_translation_ibfk_1` FOREIGN KEY (`promotion_id`) REFERENCES `shop_promotions` (`promotion_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_promotions_translation_ibfk_2` FOREIGN KEY (`lang_id`) REFERENCES `share_languages` (`lang_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Товары акции (вкладка редактора акций).
CREATE TABLE IF NOT EXISTS `shop_goods2promotions` (
  `gp_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `promotion_id` int(10) unsigned DEFAULT NULL,
  `goods_id` int(10) unsigned NOT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`gp_id`),
  KEY `promotion_id` (`promotion_id`),
  KEY `goods_id` (`goods_id`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_goods2promotions_ibfk_1` FOREIGN KEY (`promotion_id`) REFERENCES `shop_promotions` (`promotion_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_goods2promotions_ibfk_2` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Заказы. order_goods_count считается SUM() по строкам и бывает NULL; session_id текущим кодом не используется.
CREATE TABLE IF NOT EXISTS `shop_orders` (
  `order_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned NOT NULL,
  `u_id` int(10) unsigned DEFAULT NULL,
  `status_id` int(10) unsigned DEFAULT NULL,
  `delivery_type_id` int(10) unsigned DEFAULT NULL,
  `payment_type_id` int(10) unsigned DEFAULT NULL,
  `currency_id` int(10) unsigned DEFAULT NULL,
  `order_user_name` varchar(255) NOT NULL,
  `order_email` varchar(255) DEFAULT NULL,
  `order_phone` varchar(50) DEFAULT NULL,
  `order_city` varchar(255) DEFAULT NULL,
  `order_address` varchar(255) DEFAULT NULL,
  `order_comment` text DEFAULT NULL,
  `order_created` datetime NOT NULL DEFAULT current_timestamp(),
  `order_updated` datetime DEFAULT NULL,
  `order_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `order_discount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `order_total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `order_promocode` varchar(50) DEFAULT NULL,
  `order_goods_count` int(10) unsigned DEFAULT NULL,
  `order_campagin` varchar(255) DEFAULT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`order_id`),
  KEY `site_id` (`site_id`),
  KEY `u_id` (`u_id`),
  KEY `status_id` (`status_id`),
  KEY `delivery_type_id` (`delivery_type_id`),
  KEY `payment_type_id` (`payment_type_id`),
  KEY `currency_id` (`currency_id`),
  KEY `order_created` (`order_created`),
  KEY `order_updated` (`order_updated`),
  KEY `order_promocode` (`order_promocode`),
  KEY `order_campagin` (`order_campagin`),
  CONSTRAINT `shop_orders_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_ibfk_2` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_ibfk_3` FOREIGN KEY (`status_id`) REFERENCES `shop_order_statuses` (`status_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_ibfk_4` FOREIGN KEY (`delivery_type_id`) REFERENCES `shop_delivery_types` (`type_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_ibfk_5` FOREIGN KEY (`payment_type_id`) REFERENCES `shop_payment_types` (`type_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_ibfk_6` FOREIGN KEY (`currency_id`) REFERENCES `shop_currencies` (`currency_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Строки заказа (вкладка «Товары заказа»): цена, цена без скидки, количество, сумма.
CREATE TABLE IF NOT EXISTS `shop_orders_goods` (
  `og_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned DEFAULT NULL,
  `goods_id` int(10) unsigned DEFAULT NULL,
  `goods_title` varchar(255) NOT NULL,
  `goods_description` text DEFAULT NULL,
  `goods_real_price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `goods_price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `goods_quantity` int(10) unsigned NOT NULL DEFAULT 1,
  `goods_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`og_id`),
  KEY `order_id` (`order_id`),
  KEY `goods_id` (`goods_id`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_orders_goods_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `shop_orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_orders_goods_ibfk_2` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Корзина посетителя. session_id — числовой id из share_session (UserSession::getID()); share_session
-- в памяти, поэтому без внешнего ключа. Уникальный ключ нужен для INSERT ... ON DUPLICATE KEY UPDATE.
CREATE TABLE IF NOT EXISTS `shop_cart` (
  `cart_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned NOT NULL,
  `session_id` int(10) unsigned NOT NULL,
  `u_id` int(10) unsigned DEFAULT NULL,
  `goods_id` int(10) unsigned NOT NULL,
  `cart_goods_count` int(10) unsigned NOT NULL DEFAULT 1,
  `cart_date` datetime NOT NULL,
  PRIMARY KEY (`cart_id`),
  UNIQUE KEY `site_session_goods` (`site_id`,`session_id`,`goods_id`),
  KEY `session_id` (`session_id`),
  KEY `u_id` (`u_id`),
  KEY `goods_id` (`goods_id`),
  KEY `cart_date` (`cart_date`),
  CONSTRAINT `shop_cart_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_cart_ibfk_2` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_cart_ibfk_3` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Избранное зарегистрированного пользователя (INSERT IGNORE — отсюда уникальный ключ).
-- session_id текущим кодом не используется.
CREATE TABLE IF NOT EXISTS `shop_wishlist` (
  `w_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned NOT NULL,
  `u_id` int(10) unsigned NOT NULL,
  `goods_id` int(10) unsigned NOT NULL,
  `w_date` datetime NOT NULL,
  `session_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`w_id`),
  UNIQUE KEY `site_user_goods` (`site_id`,`u_id`,`goods_id`),
  KEY `u_id` (`u_id`),
  KEY `goods_id` (`goods_id`),
  KEY `session_id` (`session_id`),
  CONSTRAINT `shop_wishlist_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_wishlist_ibfk_2` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_wishlist_ibfk_3` FOREIGN KEY (`goods_id`) REFERENCES `shop_goods` (`goods_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Сохранённые фильтры каталога (GoodsFilter, SavedFilters).
CREATE TABLE IF NOT EXISTS `shop_saved_filters` (
  `sf_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned NOT NULL,
  `u_id` int(10) unsigned NOT NULL,
  `smap_id` int(10) unsigned NOT NULL,
  `sf_name` varchar(255) NOT NULL,
  `sf_data` text NOT NULL,
  PRIMARY KEY (`sf_id`),
  KEY `site_user` (`site_id`,`u_id`),
  KEY `u_id` (`u_id`),
  KEY `smap_id` (`smap_id`),
  CONSTRAINT `shop_saved_filters_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_saved_filters_ibfk_2` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shop_saved_filters_ibfk_3` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ---------------------------------------------------------------------------------------------
-- Таблицы и колонки ядра, которые нужны магазину
-- ---------------------------------------------------------------------------------------------

-- Логотипы магазинов (вкладка файлов редактора магазинов). Побочный эффект: вкладка файлов появляется
-- и у редактора сайтов в разделе «Управление структурой».
CREATE TABLE IF NOT EXISTS `share_sites_uploads` (
  `ssu_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(10) unsigned DEFAULT NULL,
  `upl_id` int(10) unsigned NOT NULL,
  `ssu_order_num` int(10) unsigned NOT NULL DEFAULT 1,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ssu_id`),
  KEY `site_id` (`site_id`),
  KEY `upl_id` (`upl_id`),
  KEY `session_id` (`session_id`),
  KEY `ssu_order_num` (`ssu_order_num`),
  CONSTRAINT `share_sites_uploads_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_sites_uploads_ibfk_2` FOREIGN KEY (`upl_id`) REFERENCES `share_uploads` (`upl_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Сайты, доступные роли (UserGroup::getSites()): без строк редакторы магазина у не-администраторов пусты.
CREATE TABLE IF NOT EXISTS `share_groups2sites` (
  `group_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`group_id`,`site_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `share_groups2sites_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `user_groups` (`group_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `share_groups2sites_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `share_sites` (`site_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Адреса покупателей: читает только OrderEditor при выборе пользователя в заказе (иначе ошибка
-- «table doesn't exist»). Колонки — из этого запроса, типы подобраны.
CREATE TABLE IF NOT EXISTS `site_address` (
  `adr_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `u_id` int(10) unsigned NOT NULL,
  `adr_is_main` tinyint(1) NOT NULL DEFAULT 0,
  `adr_index` varchar(20) DEFAULT NULL,
  `adr_street` varchar(255) DEFAULT NULL,
  `adr_building` varchar(20) DEFAULT NULL,
  `adr_apt` varchar(20) DEFAULT NULL,
  `adr_floor` varchar(10) DEFAULT NULL,
  `adr_aux_phone` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`adr_id`),
  KEY `u_id` (`u_id`),
  KEY `adr_is_main` (`adr_is_main`),
  CONSTRAINT `site_address_ibfk_1` FOREIGN KEY (`u_id`) REFERENCES `user_users` (`u_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Валюта и страна магазина: Site::$currencyId / $countryId, поля редактора магазинов (ShopEditor).
ALTER TABLE `share_sites`
  ADD COLUMN IF NOT EXISTS `currency_id` int(10) unsigned DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `country_id` int(10) unsigned DEFAULT NULL,
  ADD KEY IF NOT EXISTS `currency_id` (`currency_id`),
  ADD KEY IF NOT EXISTS `country_id` (`country_id`),
  ADD CONSTRAINT `share_sites_shop_ibfk_1` FOREIGN KEY IF NOT EXISTS (`currency_id`) REFERENCES `shop_currencies` (`currency_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `share_sites_shop_ibfk_2` FOREIGN KEY IF NOT EXISTS (`country_id`) REFERENCES `site_country` (`country_id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- Характеристики товаров категории — поле *_multi редакторов категорий (данные в shop_sitemap2features).
ALTER TABLE `share_sitemap`
  ADD COLUMN IF NOT EXISTS `smap_features_multi` int(10) unsigned DEFAULT NULL,
  ADD KEY IF NOT EXISTS `smap_features_multi` (`smap_features_multi`),
  ADD CONSTRAINT `share_sitemap_shop_ibfk_1` FOREIGN KEY IF NOT EXISTS (`smap_features_multi`) REFERENCES `shop_sitemap2features` (`smap_id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- Шаблон catalog_products.content.xml передаёт фильтру товаров tableName = shop_goods_view.
-- Исходное определение представления неизвестно, коду достаточно всех колонок shop_goods.
CREATE VIEW IF NOT EXISTS `shop_goods_view` AS SELECT * FROM `shop_goods`;

-- Журнал действий админки.
-- ActionLog::write() пишет колонку al_action, а ActionList выводит её как поле,
-- но в стартовой схеме этой колонки нет — без неё любая запись в журнал падает.
ALTER TABLE `share_action_log`
  ADD COLUMN IF NOT EXISTS `al_action` char(20) DEFAULT NULL AFTER `al_objectname`;

-- Рекламные врезки на конкретной странице (компонент apps\Ads).
-- Каждая колонка - отдельное место; значение наследуется дочерними страницами.
-- В стартовой схеме таблицы нет, поэтому компонент отключал сам себя.
CREATE TABLE IF NOT EXISTS `apps_ads` (
  `ad_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `smap_id` int(10) unsigned NOT NULL,
  `ad_top_728_90` text DEFAULT NULL COMMENT 'Шапка, 728x90',
  `ad_content_468_60` text DEFAULT NULL COMMENT 'В содержимом, 468x60',
  PRIMARY KEY (`ad_id`),
  UNIQUE KEY `smap_id` (`smap_id`),
  CONSTRAINT `fk_apps_ads_smap` FOREIGN KEY (`smap_id`)
    REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

SET FOREIGN_KEY_CHECKS=1;
