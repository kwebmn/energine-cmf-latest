# Energine Simple — интерфейс, подпроект 3: админка на Tailwind. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн, как подпроекты 1–2). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Админка (окна, формы, гриды, панели, дерево структуры) оформлена утилитами Tailwind на тех же переменных дизайна, что сайт. Двенадцать старых файлов CSS и Font Awesome удалены, значки — встроенный набор SVG. Логика JS не меняется.

**Architecture:**
- **Сборка.** Второй вход Tailwind — `core/modules/share/stylesheets/admin.tailwind.css` → `admin.css`, собирается той же командой `setup css`.
  - Утилиты админки — **с префиксом `a:`** (`@import "tailwindcss" prefix(a)`): `a:flex`, `a:px-3`.
  - Префикс развязывает их с утилитами сайта (на странице сайта у администратора грузятся оба файла) и с классами ядра, совпадающими с именами утилит (`grid`, `hidden`, `block`, `filter`).
  - Сканер — XSLT и JS ядра (`core/modules/*/transformers`, `core/modules/*/scripts`, без `jodit`).
- **Подключение.** `admin.css` грузится там же, где сейчас `energine.css` (`document.xslt`): только администратору и в окнах (`single`).
  - `Energine.loadCSS('grid.css')` и подобные убираются по мере удаления файла. Сам `loadCSS` остаётся для Jodit.
- **Классы-крючки остаются.** Классы, на которые опирается JS (`.grid`, `.e-pane`, `.e-pagelist`, `.nrgnEditor`, `li.editMode_btn` …), не переименовываются и не удаляются: вид добавляется утилитами `a:` рядом с ними. Логика JS не меняется — меняются только строки классов в местах, где JS создаёт разметку.
- **Переменные.** У админки свои переменные на `:root` (имена — как у сайта: `--bg`, `--fg`, `--accent` …). Тема сайта их не переопределяет: у админки свой слой (`@layer admin`). Тёмной схемы у админки нет, как сейчас.
- **Значки** — спрайт `core/modules/share/images/icons.svg` (около 20 `<symbol>`).
  - В XSLT — шаблон `admin-icon` (`core/modules/share/transformers/icons.xslt`), в JS — `Energine.icon(name)` (возвращает `<svg><use href="…#name"/></svg>`).
  - Кнопки панели с `icon="images/toolbar/add.png"` в конфигах получают `icon="add"`. Старые картинки удаляются, когда ссылок на них не остаётся.

**Tech Stack:** Tailwind CSS 4.3.3 (prefix), XSLT 1.0, ES-модули, PHP 8.5, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-modern-ui-design.md` (раздел 5).

## Global Constraints

- Логика JS не меняется; классы-крючки JS не переименовываются. Аудиты `editors.js`, `grids.js` и обход проходят после каждой задачи без правки их проверок поведения.
- Стили админки — только администратору: гость не загружает `admin.css` (как сейчас `energine.css`).
- Утилиты админки — только с префиксом `a:`. В классах XSLT нет `&amp;` (варианты — `@custom-variant`, страж `css-build.sh` — на оба входа).
- Ничего со сторонних адресов; Font Awesome удаляется целиком (CSS и шрифты).
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе; письма только локально; web93 только читается; `rebuild.sh` не запускается.

## Review Focus

1. **Администратор на странице сайта в режиме правки.** Панель страницы, Jodit, окна поверх сайта: стили сайта (`main.css`) и админки (`admin.css`) не ломают друг друга — ни утилиты, ни элементные правила.
2. **Окно в окне** (форма из грида, библиотека файлов из формы, выбор раздела): z-index, затемнение, прокрутка и закрытие работают на 1280 и 800 px.
3. **Длинные данные в гриде** (длинное слово, HTML-разметка в поле, 100 строк, пустой грид): нет горизонтальной прокрутки страницы, разметка не исполняется (проверка `grids.js` остаётся).
4. **Клавиатура:** кнопки панелей, вкладки, листалка и дерево достижимы с Tab, фокус виден.
5. **Значки:** у кнопки только со значком есть доступное имя (`title`/`aria-label`); значок без спрайта не даёт пустую кнопку без текста.

Проверки: п. 1–2, 4–5 — новый `tests/audit/admin.js`; п. 3 — `grids.js` и `admin.js`.

---

### Task 1: Сборка админки, переменные, значки, снимки «до»

**Files:**
- Create: `core/modules/share/stylesheets/admin.tailwind.css` → `admin.css` (сборка); `core/modules/share/images/icons.svg`; `core/modules/share/transformers/icons.xslt`; `tests/audit/admin.js`.
- Modify: `setup/Setup.php` (`cssAction`: оба входа); `tests/css-build.sh` (оба входа, страж `&amp;` и страж «утилиты админки только с `a:`» — нет класса без префикса, который совпал бы с утилитой Tailwind); `document.xslt` (`admin.css` рядом с `energine.css`); `Energine.js` (`Energine.icon`); `core/modules/share/transformers/include.xslt` или место подключения `icons.xslt`.

**Interfaces:**
- Produces:
  - префикс `a:`;
  - `<xsl:call-template name="admin-icon"><xsl:with-param name="name" select="'add'"/></xsl:call-template>`;
  - `Energine.icon(name: string): string` (HTML);
  - имена значков: `add edit delete up down save close list search filter sort-asc sort-desc prev next folder file image upload eye gear check`;
  - аудит `admin.js` — функция `shot(page, name)` и каталог снимков `SHOTS`.

- [ ] **Снимки «до» (не тест, опора для сравнения).** `admin.js` в режиме `BASELINE=1` снимает: панель страницы и режим правки на главной и `info/quick-start/`; гриды пользователей, ролей, переводов, файлов; форму пользователя (вкладки); окно библиотеки файлов из формы; редактор структуры (дерево); форму раздела; «Настройки сайта». Ширины 1280 и 800. Снимки — в scratchpad, каталог `admin-before`.
- [ ] **Red** (`admin.js`, обычный режим):
  - `admin.css` грузится администратору на странице и в окне, гостю — нет;
  - `Energine.icon('add')` даёт `svg > use[href$="#add"]`, спрайт отвечает 200 и содержит все 20 `symbol`;
  - `css-build.sh`: оба входа собраны.

  FAIL.
- [ ] **Реализация.**
  - `admin.tailwind.css`: `@layer theme, base, admin, utilities;` `@import "tailwindcss/theme.css" layer(theme) prefix(a);` `@import "tailwindcss/utilities.css" layer(utilities) prefix(a);`, `@source` — XSLT и JS ядра, `@source not` — `jodit`. `@theme` — те же имена переменных, что у сайта. В `@layer admin` пока пусто.
  - Спрайт — простые контурные значки 24×24, `stroke="currentColor"`, без внешних ссылок.
  - `setup css` собирает оба файла; `css-build.sh` сверяет оба.
- [ ] **Green:** `admin.js`, `css-build.sh`, `editors.js`, `grids.js`. Коммит.

### Task 2: Окна и формы

**Files:**
- Delete: `modalbox.css`, `form.css`, `controls.css`, `tabpane.css`.
- Modify: `ModalBox.js`, `TabPane.js`, `Form.js` (только строки классов и `loadCSS`); `form.xslt`, `fields.xslt`, `toolbar.xslt` (вид полей, кнопок формы, вкладок в окне); `admin.tailwind.css` (`@layer admin`: элементные правила внутри `.e-pane`, где разметку пишет не XSLT — например, содержимое Jodit не трогается); `tests/audit/admin.js`.

Правило переноса: каждое правило удаляемого файла либо становится утилитами `a:` в месте, где создаётся элемент (XSLT или строка класса в JS), либо остаётся в `@layer admin` с комментарием, почему не утилиты (разметка без XSLT: поля, созданные Validator.js, таблицы Jodit).

- [ ] **Red** (`admin.js`):
  - запросов к `modalbox.css`, `form.css`, `controls.css`, `tabpane.css` нет;
  - окно формы пользователя: затемнение и рамка окна видны (`position: fixed`, фон затемнения с прозрачностью), кнопка закрытия — значок `close` с `aria-label`;
  - вкладки: активная отличается фоном и рамкой, Tab доходит до вкладок, фокус виден;
  - поле с ошибкой Validator — рамка цвета `--danger`;
  - окно в окне (библиотека файлов из формы): верхнее окно выше нижнего по `z-index`, закрытие верхнего оставляет нижнее;
  - на 800 px окно без горизонтальной прокрутки страницы.

  FAIL.
- [ ] **Перенос** по правилу выше; снимки «после» тех же экранов; сравнить со снимками «до» — расположение и состав элементов те же, вид — новый.
- [ ] **Green:** `admin.js`, `editors.js`, `grids.js`, `public.js`, `smoke-*` (регрессия), обход. Коммит.

### Task 3: Гриды, листалка, панель кнопок; Font Awesome

**Files:**
- Delete: `grid.css`, `pagelist.css`, `toolbar.css`, `stylesheets/font-awesome/` (весь каталог), картинки `asc.gif`, `desc.gif`, `pagelist.gif`, `prev_page.gif`, `next_page.gif`, `checkbox_on.png`, `checkbox_off.png`, `toolbar/separator.gif`, `toolbar/{add,edit,delete,up,down}.png` — когда ссылок не осталось.
- Modify: `list.xslt` (грид, фильтр — стрелка фильтра `<i class="fa">` → значок `filter`), `toolbar.xslt`, `GridManager.js` (флажок в ячейке — значок `check` вместо картинки; строки классов), `PageList.js` (стрелки — значки `prev`/`next`), `Toolbar.js`; конфиги `*.component.xml` с `icon="images/toolbar/…"` → `icon="имя"`; `tests/audit/admin.js`; `tests/no-traces.sh` (след: `font-awesome`, `FontAwesome`, `class="fa`).

- [ ] **Red:**
  - `admin.js`:
    - запросов к `grid.css`, `pagelist.css`, `toolbar.css`, `font-awesome` и удаляемым картинкам нет;
    - грид пользователей: шапка с сортировкой (значок `sort-asc`/`sort-desc` у отсортированной колонки), чередование строк, выделенная строка отличается фоном;
    - кнопки панели грида — значок плюс текст, у кнопки без текста — `aria-label`;
    - листалка — стрелки-значки, Tab по номерам;
    - грид с длинным словом и 100 строками — без горизонтальной прокрутки страницы;
  - `no-traces.sh`: новый след `fontawesome` — FAIL, пока каталог есть.
- [ ] **Перенос**; снимки «после»; сравнение.
- [ ] **Green:** `admin.js`, `grids.js` (включая листалку и вкладки языков), `editors.js`, `no-traces.sh`, регрессия, обход. Коммит.

### Task 4: Панель страницы, режим правки, окно single

**Files:**
- Delete: `pagetoolbar.css`, `singlemode.css`, `energine.css` (последние правила — в `@layer admin`), `images/toolbar/nrgnptb.png`, `nrgnptbdbg.png` (значок `gear`), `overlay_loading.gif` (затемнение с CSS-анимацией).
- Modify: `PageToolbar.js`, `document.xslt` (подключение — только `admin.css`), `print.xslt`; `tests/audit/admin.js`.

- [ ] **Red** (`admin.js`):
  - нет запросов к удаляемым файлам;
  - панель страницы: кнопка-шестерёнка — значок `gear` с `aria-label`, панель открывается и закрывается;
  - режим правки: рамка у `.nrgnEditor` видна, у ошибочного блока — цвет `--danger`;
  - стили сайта на этой странице те же, что у гостя: у `header`, `main`, `footer` вычисленные стили совпадают с гостевыми (кроме отступа под панель) — п. 1 Review Focus;
  - окно `single`: фон и шрифт админки.

  FAIL.
- [ ] **Перенос**; снимки; сравнение.
- [ ] **Green:** `admin.js`, `editors.js`, `theme.js` (админка в странице), регрессия, обход. Коммит.

### Task 5: Дерево структуры и боковая панель разделов

**Files:**
- Delete: `treeview.css`, `div.css`, `images/treeview/` (линии и плюсы — CSS и значки `folder`/`file`), `templates/icons/*.icon.gif` и `getDirsTree.js`/`DivManager.js`-ссылки на них, если ссылок не осталось.
- Modify: `TreeView.js`, `DivManager.js`, `DivSidebar.js`, `divisionEditor.xslt`; `tests/audit/admin.js`.

- [ ] **Red** (`admin.js`):
  - нет запросов к удаляемым файлам;
  - редактор структуры: узлы с вложенными разделами раскрываются и сворачиваются щелчком и с клавиатуры (Enter), выбранный узел отличается фоном, значки `folder`/`file`;
  - боковая панель разделов в режиме правки открывается и закрывается.

  FAIL.
- [ ] **Перенос**; снимки; сравнение.
- [ ] **Green:** `admin.js`, `editors.js`, `grids.js`, регрессия, обход. Коммит.

### Task 6: Итог

- [ ] В `core/modules/share/stylesheets/` — только `admin.tailwind.css`, `admin.css`; в `images/` — только используемое (`no-traces.sh` или `admin.js`: на каждую картинку каталога есть ссылка).
- [ ] `admin.js`: п. 4–5 Review Focus на всех экранах — у каждой кнопки доступное имя, фокус виден.
- [ ] Документы: `docs/INSTALL.md` («Тема»: два входа сборки, префикс `a:`, значки), `tests/README.md` (`admin.js`).
- [ ] Полный прогон (`suite.sh … 20` + `admin.js`), финальное ревью, исправления, финиш (вариант 3).
