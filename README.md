# Energine Simple

Форк [Energine](https://github.com/energine-cmf/energine), приведённый к ядру, на котором строится свой сайт:
дерево разделов и текстовые страницы, пользователи, группы и права на каждый раздел, многоязычность (переводятся
и страницы, и подписи интерфейса), регистрация и личный кабинет, файловый репозиторий, визуальный редактор,
шаблоны писем, карта сайта и `robots.txt`.

Сейчас **этап 7 — чистое ядро**. Остаются модули share, user и seo, в базе 21 таблица. Сайт ставится в пустую
базу одной командой — `php web/index.php setup install`, демо-контент — `setup demo` (`docs/INSTALL.md`). Одна
установка — один сайт: адрес сайта — из конфига (`site.domain`, `site.root`), «Настройки сайта» в админке правят
единственную запись сайта. Меню сайта строится по флагу страницы «Показывать в меню». Визуальный редактор — Jodit
(MIT), загрузка файлов — `fetch`. Почта уходит через `mail()` или через SMTP (свой клиент).

Этап 8 — переход с MooTools 1.5.2 на чистый JavaScript, файл за файлом, без изменений на сервере
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-public-without-mootools-design.md`). Шаг 1 сделан:
публичные страницы — без MooTools, общий `Energine.js` и формы сайта (`Validator`, вход, регистрация, профиль) —
на чистом JavaScript с прежним интерфейсом; админка переходила шагами 2–7, после шага 7 MooTools в проекте нет. Адрес
каждого скрипта несёт версию (`?v=` — время изменения файла).
Шаг 2 (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md`): основа
админки — затемнение, окна, вкладки и листалка — тоже на чистом JavaScript; стили этих элементов подключает
`Energine.loadCSS`, данные вкладок шаблоны пишут как JSON. Шаг 3
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step3-toolbars-design.md`): панели кнопок админки и панель
страницы — на чистом JavaScript; администратор на страницах сайта вне режима правки MooTools не получает. Шаг 4
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step4-filters-tree-design.md`): фильтры гридов и дерево
разделов — на чистом JavaScript; значение фильтра со «+», «&», «%» доходит до сервера как есть. Шаг 5
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step5-forms-editor-design.md`): формы админки, визуальный
редактор и правка на странице — на чистом JavaScript; окна форм и режим правки MooTools не получают. Шаг 6
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step6-grids-design.md`): гриды админки — на чистом
JavaScript; гриды и их окна MooTools не получают. Шаг 7
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step7-structure-no-mootools-design.md`): структура сайта —
на чистом JavaScript; `mootools.min.js` и `MooCompat.js` удалены, MooTools не загружает ни одна страница. Этап 8
закончен.

Этап 9 (`docs/superpowers/specs/2026-10-03-energine-simple-stage9-es-modules-design.md`): скрипты ядра — ES-модули
с `import`/`export`; страница подключает их через import map (`<script type="importmap">`: имя модуля → адрес с
версией файла `?v=`), классы глобально не видны — глобальны только `Energine`, `ModalBox`, экземпляры поведений и
`componentToolbars`. `ScriptLoader`, карта зависимостей `system.jsmap.php` и `setup scriptMap` удалены, сборщика нет:
после обновления кода достаточно `setup linker`.

Что вырезано:
- этапы 1–6: модули shop, blog, comments, calendar, forms, ads и рассылки; теги, виджеты и редактор блоков,
  нелокальные хранилища, водяные знаки, видео и Flash, Lookup и select2, CKEditor и FileAPI; мультисайт;
- этап 7 (`docs/superpowers/specs/2026-10-01-energine-simple-stage7-core-design.md`): модуль apps — новости и
  обратная связь, выбор раздела для новостей; галерея и вложения разделов (вкладка вложений в гридах, миниатюры
  подразделов, картинки вложений в OpenGraph — остаётся `og:url`); мёртвый код ядра — файлы и классы без ссылок,
  CSV-экспорт гридов, сжатие ответа, `xslcache`, JSqueeze и копирование статики в установщике,
  `symfony/console`; CodeMirror и свой календарь — поле кода стало обычным `textarea` моноширинным шрифтом,
  даты — встроенными полями браузера (`type="date"` и `datetime-local`).

Безопасность (этап 5а):
- каждый POST сайта и админки несёт токен посетителя (`Csrf`), форма с чужого сайта
  отклоняется кодом 422; удаление, порядок, включение и очистка выполняются только POST-ом —
  ссылка с чужого сайта ничего не меняет;
- после 5 неудачных входов на один логин с одного IP или 20 с одного IP вход с этого IP
  закрыт на 15 минут (владелец со своего IP входит); заблокированный пользователь не входит;
- пароль восстанавливается по одноразовой ссылке со сроком в час, в базе хранится только
  хэш токена, ответ на запрос не выдаёт, зарегистрирован ли адрес;
- регистрация отклоняет ботов: поле-ловушка и минимальное время заполнения;
- гриды админки, дерево страниц и формы выводят данные текстом, разметка из них
  не исполняется;
- регистрация и профиль сохраняют только поля своей формы; пароль в профиле меняется только
  с верным текущим паролем;
- cookie — SameSite=Lax, на HTTPS — Secure, сессия и токен — HttpOnly;
- возврат после входа — только на свой сайт.

Тема (этап 5в):
- без фреймворков и шрифтов иконок: разметка — `site/modules/main/transformers/energine.xslt`,
  стили — один `main.css`; ничего не грузится со сторонних адресов;
- от 320 px до широкого экрана без горизонтальной прокрутки, светлая и тёмная схемы, печать;
- меню на телефоне свёрнуто в `<details>` и работает без JS, на широком экране раскрыто;
  ссылка «к содержимому», видимый фокус; содержимое в исходном порядке раньше боковой колонки;
- страницы ошибок — в каркасе темы, с понятным текстом и ссылкой на главную.

- Спецификации: `docs/superpowers/specs/2026-09-26-energine-simple-design.md` (этапы 1–6),
  `docs/superpowers/specs/2026-10-01-energine-simple-stage7-core-design.md` (этап 7),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-public-without-mootools-design.md` (этап 8, шаг 1),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md` (этап 8, шаг 2),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step3-toolbars-design.md` (этап 8, шаг 3),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step4-filters-tree-design.md` (этап 8, шаг 4),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step5-forms-editor-design.md` (этап 8, шаг 5),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step6-grids-design.md` (этап 8, шаг 6),
  `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step7-structure-no-mootools-design.md` (этап 8, шаг 7),
  `docs/superpowers/specs/2026-10-03-energine-simple-stage9-es-modules-design.md` (этап 9)
- Установка: `docs/INSTALL.md`
- Тесты: `tests/README.md`

---

Исходный README Energine:

energine - mod
========

Energine is a content management framework which allows to support web-applications/websites of any level of complexity.
Energine is component oriented system based on MVC pattern where all internal data is stored in XML format and View layer is implemented through XSLT transformations .

Main features of Energine are:

* Multi-language support. Energine supports unbounded quantity of languages with ability to translate not only content of a site, but buttons, emails, captions too.
* User's access delimitation. User's access control system allows to edit user's rights to access and edit different parts of a website.
* Visual text editor. A built in WYSIWYG (what you see is what you get) editor is a handy tool to edit web site's content and preview it.
* Files. Common file storage allows to use one method to work with files in forms and with a help of text editor.
* Structure site management. Web site's structure represented as a tree. User can add, edit and delete it's nodes to modify parts of a site.
* Shop module. Additional module which allows to create and use eShop.


