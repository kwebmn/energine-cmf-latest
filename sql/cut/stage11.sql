-- Energine Simple, UI-подпроект 2: секции визиток и шаблоны страниц
-- (docs/superpowers/plans/2026-10-05-energine-simple-ui2-sections.md). Переход базы после sql/cut/stage10.sql;
-- повторный запуск ничего не меняет. Тексты сайта не трогает: демо — sql/cut/stage11-demo.sql.
--   mariadb БАЗА < sql/cut/stage11.sql

-- 1. Образцы пустых секций (HTML, показываются только администратору в режиме правки: TextBlock section_sample).
--    Это и соглашение разметки секций: какие элементы текста владельца как оформлены (tailwind.css, .ui-section-*).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_HERO');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h1>Назва вашої справи</h1><p>Одна-дві фрази: що ви робите і чим корисні клієнту.</p><p><a href="#contacts">Зв’язатися</a></p>',
           '<h1>Название вашего дела</h1><p>Одна-две фразы: что вы делаете и чем полезны клиенту.</p><p><a href="#contacts">Связаться</a></p>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_HERO';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_SERVICES');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Послуги</h2><ul><li><strong>Перша послуга</strong> Короткий опис: що отримає клієнт.</li><li><strong>Друга послуга</strong> Короткий опис: що отримає клієнт.</li><li><strong>Третя послуга</strong> Короткий опис: що отримає клієнт.</li></ul>',
           '<h2>Услуги</h2><ul><li><strong>Первая услуга</strong> Короткое описание: что получит клиент.</li><li><strong>Вторая услуга</strong> Короткое описание: что получит клиент.</li><li><strong>Третья услуга</strong> Короткое описание: что получит клиент.</li></ul>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_SERVICES';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_PRICES');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Ціни</h2><ul><li><h3>Базовий</h3><p>1 000 ₴</p><ul><li>Що входить</li><li>Що входить</li></ul><p><a href="#contacts">Замовити</a></p></li><li><h3>Розширений</h3><p>2 000 ₴</p><ul><li>Що входить</li><li>Що входить</li></ul><p><a href="#contacts">Замовити</a></p></li></ul>',
           '<h2>Цены</h2><ul><li><h3>Базовый</h3><p>1 000 ₽</p><ul><li>Что входит</li><li>Что входит</li></ul><p><a href="#contacts">Выбрать</a></p></li><li><h3>Расширенный</h3><p>2 000 ₽</p><ul><li>Что входит</li><li>Что входит</li></ul><p><a href="#contacts">Выбрать</a></p></li></ul>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_PRICES';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_REVIEWS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Відгуки</h2><blockquote><p>Текст відгуку клієнта.</p><cite>Ім’я клієнта</cite></blockquote><blockquote><p>Текст відгуку клієнта.</p><cite>Ім’я клієнта</cite></blockquote>',
           '<h2>Отзывы</h2><blockquote><p>Текст отзыва клиента.</p><cite>Имя клиента</cite></blockquote><blockquote><p>Текст отзыва клиента.</p><cite>Имя клиента</cite></blockquote>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_REVIEWS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_GALLERY');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Галерея</h2><p>Вставте зображення кнопкою «Зображення» — секція розкладе їх сіткою.</p>',
           '<h2>Галерея</h2><p>Вставьте картинки кнопкой «Изображение» — секция разложит их сеткой.</p>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_GALLERY';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_FAQ');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Питання та відповіді</h2><h3>Перше часте питання?</h3><p>Відповідь на питання.</p><h3>Друге часте питання?</h3><p>Відповідь на питання.</p>',
           '<h2>Вопросы и ответы</h2><h3>Первый частый вопрос?</h3><p>Ответ на вопрос.</p><h3>Второй частый вопрос?</h3><p>Ответ на вопрос.</p>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_FAQ';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_CONTACTS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Контакти</h2><p>Місто, вулиця, будинок</p><p><a href="tel:+380000000000">+380 00 000 00 00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="https://www.openstreetmap.org/">Відкрити на мапі</a></p>',
           '<h2>Контакты</h2><p>Город, улица, дом</p><p><a href="tel:+70000000000">+7 000 000-00-00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="https://www.openstreetmap.org/">Открыть на карте</a></p>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_CONTACTS';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('TXT_SECTION_SAMPLE_CTA');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           '<h2>Готові почати?</h2><p><a href="#contacts">Залишити заявку</a></p>',
           '<h2>Готовы начать?</h2><p><a href="#contacts">Оставить заявку</a></p>')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'TXT_SECTION_SAMPLE_CTA';

-- 2. Названия шаблонов страниц в редакторе структуры (site/modules/main/templates/content/*.content.xml).
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_LANDING');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Лендінг',
           'Лендинг')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'CONTENT_LANDING';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_SERVICE');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Послуга',
           'Услуга')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'CONTENT_SERVICE';
INSERT IGNORE INTO `share_lang_tags` (`ltag_name`) VALUES ('CONTENT_CONTACTS');
INSERT IGNORE INTO `share_lang_tags_translation` (`ltag_id`, `lang_id`, `ltag_value_rtf`)
    SELECT t.`ltag_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua',
           'Контакти',
           'Контакты')
      FROM `share_lang_tags` t JOIN `share_languages` l
     WHERE t.`ltag_name` = 'CONTENT_CONTACTS';
