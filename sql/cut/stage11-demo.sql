-- Energine Simple, UI-подпроект 2: демо simple.energine.org на шаблонах страниц (только демо-база площадки и
-- генератор файлов установки tests/tools/regen-sql.sh; обычный переход базы — sql/cut/stage11.sql).
-- Главная — «Лендинг», новые страницы «Услуга» (service) и «Контакты» (contacts) с текстами секций.
-- Номера строк заданы явно — как в sql/demo.sql (fresh-check сверяет площадку с установкой). Повторный запуск ничего не меняет; уже написанные тексты не перезаписываются.
--   mariadb БАЗА < sql/cut/stage11-demo.sql

UPDATE `share_sitemap` SET `smap_content` = 'main/landing.content.xml' WHERE `smap_pid` IS NULL AND `smap_content` = 'main.content.xml';

-- тексты секций главной
SET @p = (SELECT `smap_id` FROM `share_sitemap` WHERE `smap_pid` IS NULL);
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 80, @p, '11' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '11');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h1>Energine Simple</h1><p>Сайт-візитка за вечір: готові шаблони сторінок, тексти редагуються просто на сторінці.</p><p><a href="#contacts">Написати нам</a></p>', '<h1>Energine Simple</h1><p>Сайт-визитка за вечер: готовые шаблоны страниц, тексты правятся прямо на странице.</p><p><a href="#contacts">Написать нам</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '11';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 81, @p, '12' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '12');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Що всередині</h2><ul><li><strong>Шаблони сторінок</strong> Лендінг, послуга і контакти — розробник обирає шаблон, власник пише текст.</li><li><strong>Редагування на сторінці</strong> Власник змінює тексти й зображення там, де їх бачить відвідувач.</li><li><strong>Дві мови</strong> Російська та українська версії з перемикачем у шапці.</li></ul>', '<h2>Что внутри</h2><ul><li><strong>Шаблоны страниц</strong> Лендинг, услуга и контакты — разработчик выбирает шаблон, владелец пишет текст.</li><li><strong>Правка на странице</strong> Владелец меняет тексты и картинки там же, где их видит посетитель.</li><li><strong>Два языка</strong> Русская и украинская версии с переключателем в шапке.</li></ul>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '12';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 82, @p, '14' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '14');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Відгуки</h2><blockquote><p>Зібрали сайт майстерні за один вечір, тексти тепер змінюємо самі.</p><cite>Майстерня, приклад відгуку</cite></blockquote><blockquote><p>Зрозуміла адмінка і нічого зайвого.</p><cite>Студія, приклад відгуку</cite></blockquote>', '<h2>Отзывы</h2><blockquote><p>Собрали сайт мастерской за один вечер, тексты теперь меняем сами.</p><cite>Мастерская, пример отзыва</cite></blockquote><blockquote><p>Понятная админка и ничего лишнего.</p><cite>Студия, пример отзыва</cite></blockquote>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '14';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 83, @p, '18' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '18');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Потрібен такий сайт?</h2><p><a href="ua/service/">Дізнатися, як ми працюємо</a></p>', '<h2>Нужен такой сайт?</h2><p><a href="service/">Узнать, как мы работаем</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '18';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 84, @p, '17' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '17');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Контакти</h2><p>Демо-адреса: місто, вулиця, будинок</p><p><a href="tel:+380000000000">+380 00 000 00 00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="ua/contacts/">Усі контакти</a></p>', '<h2>Контакты</h2><p>Демо-адрес: город, улица, дом</p><p><a href="tel:+70000000000">+7 000 000-00-00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="contacts/">Все контакты</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '17';

-- страница «Услуга» (service)
INSERT INTO `share_sitemap` (`smap_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_in_menu`, `smap_order_num`)
    SELECT 3730, 'default.layout.xml', 'main/service.content.xml', r.`smap_id`, 'service', 1, 900 FROM `share_sitemap` r
     WHERE r.`smap_pid` IS NULL AND NOT EXISTS (SELECT 1 FROM `share_sitemap` s WHERE s.`smap_pid` = r.`smap_id` AND s.`smap_segment` = 'service');
SET @p = (SELECT s.`smap_id` FROM `share_sitemap` s JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` WHERE r.`smap_pid` IS NULL AND s.`smap_segment` = 'service');
INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
    SELECT @p, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Послуга', 'Услуга'), 0 FROM `share_languages` l;
-- права — как у «Информации»
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
    SELECT @p, a.`group_id`, a.`right_id` FROM `share_access_level` a JOIN `share_sitemap` s USING (`smap_id`)
      JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` WHERE r.`smap_pid` IS NULL AND s.`smap_segment` = 'info';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 85, @p, '11' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '11');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h1>Сайт-візитка під ключ</h1><p>Зберемо сайт із готових секцій і навчимо редагувати тексти.</p><p><a href="ua/contacts/">Обговорити</a></p>', '<h1>Сайт-визитка под ключ</h1><p>Соберём сайт из готовых секций и научим править тексты.</p><p><a href="contacts/">Обсудить</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '11';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 86, @p, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '1');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Приклад сторінки «Послуга»: перший екран, опис, ціни, питання і заклик до дії. Кожна частина — окремий текст, який власник редагує на сторінці.</p>', '<p>Пример страницы «Услуга»: первый экран, описание, цены, вопросы и призыв к действию. Каждая часть — отдельный текст, который владелец правит на странице.</p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '1';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 87, @p, '13' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '13');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Ціни</h2><ul><li><h3>Візитка</h3><p>від 5 000 ₴</p><ul><li>Лендінг і контакти</li><li>Дві мови</li></ul><p><a href="ua/contacts/">Замовити</a></p></li><li><h3>Візитка і послуги</h3><p>від 10 000 ₴</p><ul><li>Сторінки послуг</li><li>Навчання власника</li></ul><p><a href="ua/contacts/">Замовити</a></p></li></ul>', '<h2>Цены</h2><ul><li><h3>Визитка</h3><p>от 10 000 ₽</p><ul><li>Лендинг и контакты</li><li>Два языка</li></ul><p><a href="contacts/">Выбрать</a></p></li><li><h3>Визитка и услуги</h3><p>от 20 000 ₽</p><ul><li>Страницы услуг</li><li>Обучение владельца</li></ul><p><a href="contacts/">Выбрать</a></p></li></ul>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '13';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 88, @p, '16' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '16');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Питання та відповіді</h2><h3>Скільки часу займає сайт?</h3><p>Зазвичай один-два дні: шаблони готові, залишаються тексти й зображення.</p><h3>Чи зможу я змінювати тексти сам?</h3><p>Так: увійдіть на сайт і редагуйте текст просто на сторінці.</p>', '<h2>Вопросы и ответы</h2><h3>Сколько времени занимает сайт?</h3><p>Обычно один-два дня: шаблоны готовы, остаются тексты и картинки.</p><h3>Смогу ли я менять тексты сам?</h3><p>Да: войдите на сайт и правьте текст прямо на странице.</p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '16';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 89, @p, '18' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '18');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Готові почати?</h2><p><a href="ua/contacts/">Залишити заявку</a></p>', '<h2>Готовы начать?</h2><p><a href="contacts/">Оставить заявку</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '18';

-- страница «Контакты» (contacts)
INSERT INTO `share_sitemap` (`smap_id`, `smap_layout`, `smap_content`, `smap_pid`, `smap_segment`, `smap_in_menu`, `smap_order_num`)
    SELECT 3731, 'default.layout.xml', 'main/contacts.content.xml', r.`smap_id`, 'contacts', 1, 901 FROM `share_sitemap` r
     WHERE r.`smap_pid` IS NULL AND NOT EXISTS (SELECT 1 FROM `share_sitemap` s WHERE s.`smap_pid` = r.`smap_id` AND s.`smap_segment` = 'contacts');
SET @p = (SELECT s.`smap_id` FROM `share_sitemap` s JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` WHERE r.`smap_pid` IS NULL AND s.`smap_segment` = 'contacts');
INSERT IGNORE INTO `share_sitemap_translation` (`smap_id`, `lang_id`, `smap_name`, `smap_is_disabled`)
    SELECT @p, l.`lang_id`, IF(l.`lang_abbr` = 'ua', 'Контакти', 'Контакты'), 0 FROM `share_languages` l;
-- права — как у «Информации»
INSERT IGNORE INTO `share_access_level` (`smap_id`, `group_id`, `right_id`)
    SELECT @p, a.`group_id`, a.`right_id` FROM `share_access_level` a JOIN `share_sitemap` s USING (`smap_id`)
      JOIN `share_sitemap` r ON r.`smap_id` = s.`smap_pid` WHERE r.`smap_pid` IS NULL AND s.`smap_segment` = 'info';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 90, @p, '1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '1');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<p>Приклад сторінки «Контакти». Напишіть або зателефонуйте — відповімо протягом дня.</p>', '<p>Пример страницы «Контакты». Напишите или позвоните — ответим в течение дня.</p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '1';
INSERT INTO `share_textblocks` (`tb_id`, `smap_id`, `tb_num`)
    SELECT 91, @p, '17' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `share_textblocks` WHERE `smap_id` = @p AND `tb_num` = '17');
INSERT IGNORE INTO `share_textblocks_translation` (`tb_id`, `lang_id`, `tb_content`)
    SELECT t.`tb_id`, l.`lang_id`, IF(l.`lang_abbr` = 'ua', '<h2>Контакти</h2><p>Демо-адреса: місто, вулиця, будинок</p><p><a href="tel:+380000000000">+380 00 000 00 00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="https://www.openstreetmap.org/">Відкрити на мапі</a></p>', '<h2>Контакты</h2><p>Демо-адрес: город, улица, дом</p><p><a href="tel:+70000000000">+7 000 000-00-00</a></p><p><a href="mailto:info@example.org">info@example.org</a></p><p><a href="https://www.openstreetmap.org/">Открыть на карте</a></p>')
      FROM `share_textblocks` t JOIN `share_languages` l WHERE t.`smap_id` = @p AND t.`tb_num` = '17';
