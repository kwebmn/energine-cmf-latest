# Energine Simple — интерфейс, подпроект 4: разработка (чистка XSLT, новая визитка). Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн, как подпроекты 1–3). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Шаблоны XSLT без небезопасного `disable-output-escaping` и без повторов; тема визитки перекрашивается одним файлом переменных; новая визитка выпускается по инструкции `docs/NEW-SITE.md`.

**Architecture:**
- **Сверка вывода «до/после».**
  - Инструмент `tests/tools/xslt-golden.sh`:
    - снимает XML набора страниц через `?debug` (на площадке `site.debug` включён) — гость и администратор, страницы сайта, формы и гриды;
    - преобразует каждый XML шаблонами из выбранной ревизии (`git archive` во временный каталог) и текущими;
    - сравнивает HTML.
  - Чистка без изменения поведения даёт пустое сравнение. Задуманное изменение (экранирование) даёт только ожидаемые строки.
- **Экранирование.** Каждое из 41 `disable-output-escaping` получает решение:
  1. **Разметка по замыслу** — текст блока, описание раздела, образец секции, тексты-константы с разметкой. Остаётся, с комментарием `<!-- d-o-e: … -->` в строке выше.
  2. **Текст, который надо экранировать** — подписи полей, заголовки, значения полей «только чтение», название раздела, сегмент. Убирается.
  3. **`&nbsp;`** — заменяется на `&#160;` без `disable-output-escaping`.
  4. **Строка JS** (`divisionEditor.xslt:11`) — переводы передаются JSON-ом через атрибут `data-` и читаются `JSON.parse`, без вставки в код.
  5. **Сломанная разметка** (`user.xslt:113/147`, `<tbody>` текстом) — обычная структура.
- **Страж.** `tests/xslt-escaping.php`:
  - число `disable-output-escaping` в шаблонах ровно равно числу комментариев `d-o-e:`;
  - XSLT-тест на собранном документе: разметка в подписи поля, значении «только чтение», заголовке страницы и названии раздела выводится текстом.
- **Повторы.**
  - Поля ввода `fields.xslt` (`email`, `phone`, `color`, `integer`, `float`, `money`, `password`, строка) — один шаблон `field-input` с параметрами `type` и `class`.
  - Остатки Bootstrap (`form-group`, `form-control`) — убираются: стилей у них нет.
- **Тема визитки.** Цвета, шрифт, радиус и ширина страницы — в отдельном файле `site/modules/main/stylesheets/theme.css` (светлая и тёмная схемы), его импортирует `tailwind.css`. Новая визитка меняет только этот файл.
- **Новая визитка.** `docs/NEW-SITE.md`:
  1. установка (`setup install`);
  2. шаблоны страниц (лендинг, услуга, контакты) и секции;
  3. тема (`theme.css`, `setup css`);
  4. проверка.

  Команды из инструкции проверяет `tests/new-site-doc.sh`: каждая `setup <команда>` существует в `Setup.php`, каждый упомянутый файл есть.

**Tech Stack:** XSLT 1.0, PHP 8.5 (XSLTProcessor), bash, Tailwind 4.3.3, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-modern-ui-design.md` (раздел 6; «своя тема визитки — файл переменных в `site/`» — раздел 3).

## Global Constraints

- Вид и поведение сайта и админки не меняются, кроме экранирования текста, который раньше выводился как разметка. Сверка «до/после» — пустая или только ожидаемые строки.
- Тексты, которые владелец пишет как разметку (текстовые блоки, описание раздела), разметкой и остаются.
- Общие правила:
  - конфиги веб-сервера не трогаются;
  - владелец `web97:client1`;
  - пароли не в git и не в выводе;
  - письма только локально;
  - web93 только читается;
  - `rebuild.sh` не запускается.

## Review Focus

1. **Константы перевода с разметкой** (`TXT_REQUIRED_FIELDS`, `TXT_REGISTRATION_TEXT` и подобные): после чистки разметка в них работает, а не видна текстом. Проверить по базе, какие константы содержат теги.
2. **Заголовок страницы и названия разделов с `&`, кавычками, `<`** на сайте, в крошках, меню и `<title>`: нет двойного экранирования (`&amp;amp;`).
3. **Перевод с апострофом** (украинский «Зв’язатися», `'`) в редакторе разделов: JS не ломается.
4. **Тёмная схема после выноса переменных:** контраст тот же (`theme.js`).
5. **Инструкция новой визитки на чистой установке:** шаги проходят по порядку (`fresh-check`).

Проверки: п. 1–3 — `tests/xslt-escaping.php` и сверка `xslt-golden.sh`; п. 2–3 — ещё `editors.js` и `public.js`; п. 4 — `theme.js`; п. 5 — `tests/new-site-doc.sh` и `fresh-check`.

---

### Task 1: Сверка «до/после»

**Files:**
- Create: `tests/tools/xslt-golden.sh`, `tests/tools/xslt-golden.php`.

**Interfaces:**
- Produces:
  - `bash tests/tools/xslt-golden.sh capture DIR` — XML страниц в `DIR`;
  - `bash tests/tools/xslt-golden.sh compare DIR REV` — HTML по шаблонам ревизии `REV` и текущим, разница — в вывод.

  Выход: 0 — без разницы, 1 — есть разница.

- [ ] **Red.**
  - `compare` с несуществующим каталогом — выход 2.
  - На снятых XML `compare DIR HEAD` — 0.
  - Пробная правка шаблона (пробел в классе в рабочей копии) — 1 и строка с разницей. Правка откатывается.
- [ ] **Реализация.**
  - Набор страниц:
    - гость: `/`, `info/quick-start/`, `service/`, `contacts/`, `login/`, `register/`, `sitemap/`;
    - администратор: `admin/users/single/userEditor/add/`, `admin/users/single/userEditor/<id>/edit/`, `admin/structure/single/divEditor/<id>/edit/`, `admin/mail-templates/single/mailTemplateEditor/1/edit/`, `admin/translations/`, грид пользователей.
  - Вход — как в `testlib.php`.
  - Преобразование — `XSLTProcessor` с `include.xslt` сайта, как у `XSLTTransformer`.
  - Сравнение — после нормализации пробелов и токена CSRF.
- [ ] Коммит.

### Task 2: Экранирование и страж

**Files:**
- Create: `tests/xslt-escaping.php` (регрессия `### escaping`).
- Modify: `fields.xslt`, `form.xslt`, `list.xslt`, `text.xslt`, `container.xslt`, `document.xslt`, `print.xslt`, `divisionEditor.xslt` (+ `DivManager.js`/`DivForm.js` — чтение переводов из `data-`), `user.xslt`, `site/.../energine.xslt`, `sections.xslt`; `tests/regression.sh`.

- [ ] **Red** (`xslt-escaping.php`):
  - число `disable-output-escaping` = числу `d-o-e:` → сейчас FAIL;
  - harness на собранном документе — `<b>x</b>` выводится текстом в:
    - подписи поля формы;
    - значении поля «только чтение»;
    - `h1` страницы;
    - названии раздела в форме раздела;
    - сегменте.

    FAIL;
  - перевод с `'` в редакторе разделов → `Energine.translations.get` возвращает его без ошибки JS (`editors.js`, новая проверка) — FAIL.
- [ ] **Перед правкой:** выписать из базы константы и данные с тегами (п. 1 Review Focus) — какие из «текстовых» источников реально содержат разметку. Такие получают решение «разметка по замыслу» с комментарием, а не экранирование. Всё это — в журнал.
- [ ] **Правка по категориям 1–5** из Architecture.
- [ ] **Сверка:** `xslt-golden.sh compare DIR <BASE>` — разница только в экранированных строках, каждая разобрана в журнале.
- [ ] **Green:** `xslt-escaping.php`, регрессия, `editors.js`, `public.js`, `grids.js`, `admin.js`, обход. Коммит.

### Task 3: Повторы в полях форм, остатки Bootstrap

**Files:**
- Modify: `fields.xslt`, `form.xslt`.

- [ ] **Red:** `xslt-escaping.php` (или новый `tests/xslt-lint.php`, в регрессии) — в шаблонах нет классов `form-group`, `form-control`, `btn btn-`; шаблонов `mode="field_input"` с одинаковым телом `<input>` нет (поиск по нормализованному телу). FAIL.
- [ ] **Шаблон `field-input`** (params `type`, `class`) вызывается из восьми шаблонов полей. Классы `inp_*` остаются: на них опираются Validator.js и стили.
- [ ] **Сверка `compare`:** разница — только снятые `form-group`/`form-control`.
- [ ] **Green:** регрессия, `editors.js`, `grids.js`, `admin.js`. Коммит.

### Task 4: Файл темы визитки

**Files:**
- Create: `site/modules/main/stylesheets/theme.css` (переменные светлой и тёмной схем, шрифт, радиус, ширина — вынесены из `tailwind.css`).
- Modify: `tailwind.css` (`@import "./theme.css" layer(components);` на месте переменных), `main.css` (сборка), `tests/css-build.sh` (`theme.css` есть и содержит обе схемы; в `tailwind.css` нет значений цветов `#…`).

- [ ] **Red:** `css-build.sh` — FAIL (файла нет, цвета в `tailwind.css`).
- [ ] **Вынос.** Собранный `main.css` по содержимому тот же: сравнить правила до/после без учёта порядка.
- [ ] **Green:** `css-build.sh`, `theme.js` (контраст обеих схем), `public.js`. Коммит.

### Task 5: Инструкция новой визитки

**Files:**
- Create: `docs/NEW-SITE.md`, `tests/new-site-doc.sh` (в регрессии `### new-site-doc`).
- Modify: `docs/INSTALL.md` (ссылка), `tests/README.md`.

- [ ] **Red:** `new-site-doc.sh` — нет файла → FAIL.

  Проверки:
  - каждая `setup <команда>` из инструкции есть в `Setup.php` (`<команда>Action`);
  - каждый путь в обратных кавычках существует;
  - шаблоны `main/landing|service|contacts.content.xml` упомянуты.
- [ ] **`NEW-SITE.md`:**
  1. установка (`setup install` от владельца, без демо);
  2. главная — «Лендинг»: в редакторе структуры выбрать шаблон;
  3. страницы «Услуга», «Контакты»;
  4. тексты секций правятся на странице: соглашение разметки — ссылка на `INSTALL.md`;
  5. тема — `theme.css`, `setup css`;
  6. проверка — `tests/css-build.sh`, аудит `theme.js`;
  7. перенос на хостинг — собранный `main.css` в git, бинарник не нужен.
- [ ] **Green:** `new-site-doc.sh`, `fresh-check`. Коммит.

### Task 6: Итог

- [ ] Полный прогон (`suite.sh … 22` + `admin.js`), финальное ревью, исправления, финиш (вариант 3).
