-- Приведение демо-данных (starter.data.demo.sql, 2015-10) к ядру с неймспейсами:
-- XML страниц (share_sitemap.smap_content_xml) и виджетов (share_widgets.widget_xml)
-- хранит классы компонентов без неймспейса (module="share" class="PageList"),
-- а Component::create() ожидает полное имя класса (Energine\share\components\PageList).
-- Импортировать после starter.data.demo.sql

SET NAMES utf8;

UPDATE `share_sitemap` SET `smap_content_xml` =
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(`smap_content_xml`,
        'module="share" class="PageList"', 'class="Energine\\share\\components\\PageList"'),
        'module="share" class="TextBlock"', 'class="Energine\\share\\components\\TextBlock"'),
        'module="user" class="LoginForm"', 'class="Energine\\user\\components\\LoginForm"'),
        'module="apps" class="NewsFeed"', 'class="Energine\\apps\\components\\NewsFeed"'),
        'class="Vote" module="apps"', 'class="Energine\\apps\\components\\Vote"'),
        'class="Form" module="forms"', 'class="Energine\\forms\\components\\Form"'),
        -- конфиги компонентов переехали в подкаталог config/
        'core/modules/share/MainMenu.component.xml', 'core/modules/share/config/MainMenu.component.xml')
WHERE `smap_content_xml` IS NOT NULL;

UPDATE `share_widgets` SET `widget_xml` =
    REPLACE(REPLACE(`widget_xml`,
        'module="share" class="TextBlock"', 'class="Energine\\share\\components\\TextBlock"'),
        'class="Vote" module="apps"', 'class="Energine\\apps\\components\\Vote"');

-- reCAPTCHA удалена из ядра вместе с параметром noCaptcha: неизвестный параметр компонента — ошибка
-- ERR_DEV_NO_PARAM, а страница «Пример формы» хранит его в своём XML
UPDATE `share_sitemap` SET `smap_content_xml` = REPLACE(`smap_content_xml`, '\n<param name="noCaptcha">1</param>', '')
WHERE `smap_content_xml` LIKE '%noCaptcha%';

-- AuthUser::authenticate() использует password_verify() (коммит d312b051, 2015-04),
-- а в дампе пароль demo@energine.org хранится как sha1('demo'). Пароль остаётся тем же: demo
UPDATE `user_users` SET `u_password` = '$2y$10$L1om76/ArptFr9tRlRGa3.7E7/mmHbjCcLNUisAuu7WEQ556dRh4q'
WHERE `u_name` = 'demo@energine.org' AND `u_password` = '89e495e7941cf9e40e6980d14a16bf023ccd4c91';

-- Украинские названия разделов, оставшиеся в дампе русскими.
-- (Одинаковые в обоих языках - «Блоги», «Каталог», «Магазин», «Галерея» - не трогаем.)
UPDATE `share_sitemap_translation` x
  JOIN `share_sitemap` s ON s.`smap_id` = x.`smap_id`
   SET x.`smap_name` = CASE s.`smap_segment`
       WHEN 'test-feed' THEN 'Список проєктів'
       WHEN 'feedback-editor' THEN 'Зворотний зв’язок'
       WHEN 'polls' THEN 'Опитування'
       WHEN 'recipients' THEN 'Редактор отримувачів'
       WHEN 'widgets' THEN 'Віджети'
       WHEN 'quick-start' THEN 'Інструкція зі встановлення Energine 2.11.2.dev'
       ELSE x.`smap_name` END
 WHERE x.`lang_id` = (SELECT `lang_id` FROM `share_languages` WHERE `lang_abbr` = 'ua' LIMIT 1)
   AND s.`smap_segment` IN ('test-feed', 'feedback-editor', 'polls', 'recipients', 'widgets', 'quick-start');
