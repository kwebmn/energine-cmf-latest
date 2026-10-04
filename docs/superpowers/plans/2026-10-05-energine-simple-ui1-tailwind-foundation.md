# Energine Simple — интерфейс, подпроект 1: Tailwind и тема сайта. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн, как этап 10). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Тема сайта на чистых утилитах Tailwind v4 с переменными дизайна и компонентами XSLT; сборка CSS без Node; админка не задета.

**Architecture:**
- Бинарник Tailwind CLI 4.3.3 (не в git, скрипт с суммой) собирает `site/modules/main/stylesheets/main.css` из `tailwind.css`, сканируя XSLT ядра и сайта. Результат лежит в git.
- Tailwind подключается слоями (`theme`, `base`, `utilities`). Стили админки без слоя сильнее любого слоя, поэтому сброс Tailwind их не перебивает.
- Повторяющиеся элементы — именованные шаблоны `site/modules/main/transformers/ui.xslt`.
- Формы сайта (вход, регистрация, профиль, восстановление пароля) переопределяются в теме сайта; `fields.xslt` админки не меняется.

**Tech Stack:** Tailwind CSS 4.3.3 standalone CLI, XSLT 1.0, PHP 8.5 (`setup css`), bash, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-modern-ui-design.md` (разделы 3, 7, 8).

## Global Constraints

- Бинарник Tailwind не в git и не нужен для работы сайта.
- Никаких внешних адресов на страницах: шрифт системный.
- Тёмная схема сохраняется (`prefers-color-scheme`).
- Логика JS не меняется; админка (`.e-pane`, панели, окна) выглядит как до подпроекта.
- Функции и адреса страниц те же; имена полей форм те же.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе; письма только локально; web93 только читается.

## Review Focus

1. Администратор на странице сайта: панель страницы, режим правки, окна, гриды — сброс Tailwind их не ломает.
2. Узкий экран 320 px: нет горизонтальной прокрутки, меню сворачивается без JS.
3. Тёмная схема: контраст текста, ссылок, кнопок, полей и ошибок достаточный.
4. Классы, которые появляются только из JS или из данных (ошибки формы, активный пункт меню), есть в собранном CSS.
5. Сборка: собранный `main.css` совпадает с исходниками; без бинарника сайт работает.

Проверки: п. 1 — `editors.js`, `grids.js`, `theme.js` (админка в странице); п. 2–3 — `theme.js`; п. 4 — `theme.js` (стили применены, а не только классы); п. 5 — `tests/css-build.sh`.

---

### Task 1: Сборка CSS и переменные дизайна

**Files:**
- Create: `tools/get-tailwind.sh`, `tools/tailwindcss.sha256`, `site/modules/main/stylesheets/tailwind.css`, `tests/css-build.sh`.
- Modify: `setup/Setup.php` (`cssAction`), `.gitignore` (`tools/tailwindcss`), `tests/regression.sh` (строка `### css`), `site/modules/main/stylesheets/main.css` (теперь собирается).

**Interfaces:**
- Produces: `php web/index.php setup css` — сборка; `bash tests/css-build.sh` — проверка «собрано из исходников»; переменные `--color-*`, `--radius-*`, `--font-sans`, `--container-page` в `@theme`.

- [ ] Red: `tests/css-build.sh` — бинарник есть (иначе `skip` с подсказкой `tools/get-tailwind.sh`), сборка во временный файл, `cmp` с `main.css`; плюс `main.css` содержит слой `utilities` и переменные `--color-primary`. Прогон — FAIL (нынешний `main.css` ручной).
- [ ] `tools/get-tailwind.sh`: скачивает `tailwindcss-linux-x64` v4.3.3 с GitHub в `tools/tailwindcss`, проверяет сумму из `tools/tailwindcss.sha256`, `chmod +x`.
- [ ] `tailwind.css`: `@layer theme, base, components, utilities;` и импорты по слоям `@import "tailwindcss/theme.css" layer(theme)`, `preflight` в `base`, `utilities` в `utilities`; `@source "../../../../core/modules/*/transformers/*.xslt"`, `@source "../transformers/*.xslt"`; `@theme` — переменные из нынешнего `main.css` (те же цвета, светлая и тёмная схемы через `@media (prefers-color-scheme: dark)` на `:root`); нынешние правила темы переносятся в `@layer components` как есть — вид сайта в этой задаче не меняется.
- [ ] `Setup::cssAction`: запуск бинарника `--input … --output … --minify`; нет бинарника — понятный отказ.
- [ ] Green: `css-build.sh`, `theme.js`, `public.js`, `editors.js`, `grids.js`, регрессия. Коммит.

### Task 2: Компоненты XSLT и каркас страницы

**Files:**
- Create: `site/modules/main/transformers/ui.xslt` (шаблоны `ui-button`, `ui-link-button`, `ui-card`, `ui-section-title`, `ui-alert`, `ui-container`).
- Modify: `site/modules/main/transformers/include.xslt` (подключить `ui.xslt`), `energine.xslt` (шапка, меню, язык, вход, подвал, крошки, ссылка «к содержимому» — утилиты), `tailwind.css` (убрать перенесённые правила этих частей), `tests/audit/theme.js`.

- [ ] Red (`theme.js`): у шапки, меню, подвала — утилиты Tailwind (например, класс шапки содержит `flex`), правила старой темы `.site-header`/`.main-menu` в `main.css` отсутствуют. Прогон — FAIL.
- [ ] `ui.xslt` с параметрами (`href`, `text`, `variant`); `energine.xslt` вызывает компоненты; меню остаётся `<details>` с раскрытием на широком экране утилитами (`md:` + `open` по умолчанию на широком — через CSS `details::details-content` в `@layer components` с `@supports`, как сейчас).
- [ ] Green: `theme.js` (включая 320 px и тёмную схему), `public.js`, обход. Коммит.

### Task 3: Содержимое страниц

**Files:**
- Modify: `energine.xslt` (списки страниц, карта сайта), `error_page.xslt`, шаблон текстового блока сайта (оформление текста — утилиты `[&_h2]:…` или класс-обёртка `prose`-стиля в `@layer components`), листалка; `tailwind.css` (убрать перенесённое).

- [ ] Red (`theme.js`): текст блока, список подразделов, карта сайта, страница 404 и листалка — с утилитами, без старых классов темы. FAIL.
- [ ] Перевод; оформление текста из редактора (заголовки, списки, ссылки, таблицы, картинки) — один набор правил в `@layer components` под классом-обёрткой `.ui-text`: разметку текста пишет владелец, классы в ней не нужны (разрешённое исключение спецификации «утилиты для раскладки»).
- [ ] Green: `theme.js`, `public.js`, `editors.js` (правка на странице), обход. Коммит.

### Task 4: Формы сайта

**Files:**
- Modify: `ui.xslt` (`ui-field`, `ui-checkbox`, `ui-select`, `ui-form-actions`), `energine.xslt` (шаблоны полей с приоритетом для компонентов `LoginForm`, `Register`, `UserProfile`, `RestorePassword`), `tailwind.css`.
- Test: `tests/audit/theme.js`, `tests/audit/public.js`.

- [ ] Red: у полей форм входа, регистрации, профиля, восстановления — `label for` совпадает с `id` поля, класс поля из `ui-field`; сообщение об ошибке — `ui-alert` с `role="alert"`. FAIL.
- [ ] Перевод; имена полей и `id` не меняются; ошибки валидации (класс, который ставит `Validator.js`) — в `@source inline(...)`.
- [ ] Green: `public.js` (вход, регистрация, профиль, ошибки), `smoke-profile`, `smoke-mail`, `theme.js`. Коммит.

### Task 5: Итог

- [ ] `tailwind.css` без остатков старой темы (кроме `.ui-text` и `details`-меню); `main.css` пересобран.
- [ ] `theme.js`: контраст обеих схем, 320 px, видимый фокус, нет внешних адресов, админка в странице (п. 1 Review Focus).
- [ ] Документы: `docs/INSTALL.md` (раздел «Тема и CSS»: `tools/get-tailwind.sh`, `setup css`, переменные), `tests/README.md` (`css-build.sh`).
- [ ] Полный прогон, финальное ревью, исправления, финиш (вариант 3).
