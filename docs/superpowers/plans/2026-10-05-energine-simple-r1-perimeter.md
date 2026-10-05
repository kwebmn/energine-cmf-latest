# Energine Simple — надёжность, этап 1: периметр и защита от потери данных. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Владелец не теряет тексты и страницы по неосторожности; данные запроса не попадают в SQL строкой;
ошибки PHP не показывают посетителю сервер; четыре дефекта JS закрыты.

**Architecture:**
- **Тексты.** `TextBlock::save` при пустом тексте удаляет только перевод своего языка
  (`share_textblocks_translation` по `tb_id` и `lang_id`); строка `share_textblocks` удаляется, только когда переводов
  не осталось. Сейчас удаляется вся строка — каскад сносит переводы на всех языках (`TextBlock.php:267`).
- **Удаление страницы** (`DivisionEditor::deleteData`):
  - есть подстраницы → отказ `ERR_DIV_HAS_CHILDREN`;
  - системная страница (сегменты корня `admin`, `login`, `register`, `restore-password`, `profile`, `sitemap`,
    `google-sitemap`, `robots.txt` и всё под `admin`) → отказ `ERR_DIV_SYSTEM`;
  - на страницу ссылаются тексты (обратный поиск через `LinkChecker`) → ответ `{result: false, confirm: "…"}` со
    списком страниц; `DivManager.del` спрашивает второй раз и повторяет запрос с `?confirm=1`.
  - Константы — `sql/cut/stage14.sql`.
- **Периметр PHP.**
  - `htdocs/index.php` и `DocumentController::run` ловят `\Throwable`; `ini.func.php` включает `display_errors`
    только при `DEBUG`. Копия `web/index.php` обновляется.
  - `?struct` — только при `site.debug` (как `?debug`).
  - `ComponentConfig::getActionByURI`: заполнители по типам — `[int]`, `[pid]`, `[pageNumber]`, `[fromId]`, `[toId]`,
    `[smap_id]` → `\d+`; `[sortDir]` → `asc|desc`; `[sortField]`, `[direction]` → `[a-zA-Z_][a-zA-Z0-9_]*`;
    `[token]` → `[A-Za-z0-9_-]+`; прочие (`[any]`, `[string]`, `[login]`, `[logout]`) как были. Не подошло — 404.
  - `FileRepository`: `copyFile`, `copyDir`, `delete` — `(int)$uplID` и выборка через массив условий.
  - `DivisionEditor::getProperties`: `(int)` для `id` и `languageID`, запрос с параметрами.
  - `Grid::applyUserSort`: поле — только из описания данных, направление — только `asc|desc`, иначе сортировка
    игнорируется. `QAL::buildOrderCondition`: имя поля по образцу идентификатора, неизвестное направление —
    `SystemException`, а не `Error`.
  - `QAL` условие `IN`: значения через `quote()`. `FilterField`: значения через `quote()`, оператор только `AND|OR`,
    условие — только из таблицы условий.
  - `htdocs/resizer/timthumb-config.php`: `ALLOW_EXTERNAL false`, `DISPLAY_ERROR_MESSAGES false`; копия в `web/resizer`.
- **JS.**
  - `Form.save`: флаг «идёт сохранение», повторный щелчок не отправляет; снимается в `processServerResponse` и
    `processServerError`.
  - `Form.processServerError` и `GridManager.processServerError`: понятное сообщение (константа `ERR_SERVER` через
    `Energine.translations`, иначе «Ошибка сервера»), сырой HTML — только в `console.error`.
  - `Filters.remove()` без аргумента удаляет все фильтры (так его зовут при смене языка и папки).
  - `toolbar.xslt`: строки в JS через рекурсивный шаблон `js-string` (экранирует `\`, `'`, перевод строки).

**Tech Stack:** PHP 8.5, MariaDB, XSLT 1.0, ES-модули, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-reliability-design.md` (этап 1).

## Global Constraints

- Поведение меняется только в названных местах; прочее — сверка `xslt-golden.sh`, полный прогон.
- Копии в `web/` (`index.php`, `resizer/`) обновляются от `web97`, как при развёртывании.
- База меняется только `sql/cut/stage14.sql`.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе;
  письма только локально; web93 только читается; `rebuild.sh` не запускается.

## Review Focus

1. **Адреса, которые раньше работали, с нечисловыми заполнителями:** нет ли состояний, куда по `[int]`/`[pid]`
   приходит не число (например `0`, пустое, `current`)? — обход `crawl.js`, `grids.js`, `editors.js`.
2. **Очистка последнего перевода блока:** строка `share_textblocks` удаляется, образец секции возвращается
   (`editors.js`).
3. **Удаление страницы, на которую есть ссылки, без второго подтверждения через прямой запрос** — отказ, а не удаление.
4. **Ошибка внутри компонента в JSON-ответе** (`TypeError`) — ответ JSON без путей, а не пустая страница.
5. **Форма сайта (вход, регистрация) после правок `Form.js`** — `Form.js` админки и формы сайта не связаны; проверить
   `public.js`.

Проверки: п. 1 — обход и аудиты; п. 2 — `editors.js`; п. 3 — `tests/perimeter.php`; п. 4 — `tests/perimeter.php`
(статически: `catch (\Throwable)`), `smoke-errors.php`; п. 5 — `public.js`.

---

### Task 1: Тексты и удаление страниц

**Files:** `TextBlock.php`, `DivisionEditor.php`, `DivManager.js`, `sql/cut/stage14.sql`, `tests/smoke-editing.php`,
`tests/pages-delete.php` (новый, регрессия), `tests/audit/editors.js`.

- [ ] **Red:**
  - `smoke-editing.php`: у блока два перевода; пустое сохранение на ru — ru пропал, ua на месте, строка блока есть;
    пустое на ua — строки блока нет. FAIL.
  - `pages-delete.php`: удаление страницы с подстраницей — отказ с `ERR_DIV_HAS_CHILDREN`, страница на месте;
    удаление `admin/users/` и `login/` — отказ `ERR_DIV_SYSTEM`; страница, на которую ссылается текст стенда:
    без `confirm` — `{result:false, confirm:…}` и страница на месте, с `?confirm=1` — удалена. FAIL.
- [ ] **Реализация.** `stage14.sql` применить к площадке, `regen-sql.sh`.
- [ ] **Green:** оба теста, `editors.js` (образец секции после очистки), `fresh-check`, `migration-check`. Коммит.

### Task 2: Периметр PHP

**Files:** `htdocs/index.php` (+ копия `web/index.php`), `DocumentController.php`, `ini.func.php`, `ComponentConfig.php`,
`FileRepository.php`, `DivisionEditor.php`, `Grid.php`, `QAL.php`, `FilterField.php`, `htdocs/resizer/timthumb-config.php`
(+ копия), `tests/perimeter.php` (новый, регрессия).

- [ ] **Red** (`perimeter.php`):
  - статически: `index.php` и `DocumentController.php` ловят `\Throwable`; в `ini.func.php` нет безусловного
    `display_errors=1`; `timthumb-config.php` задаёт `ALLOW_EXTERNAL` false и `DISPLAY_ERROR_MESSAGES` false;
  - гость `/?struct` — не XML структуры (HTML страницы, 200);
  - администратор: `…/userEditor/get-data/u_name)-asc/` и `…/get-data/u_name-evil/` — 404 или обычный ответ без
    текста ошибки SQL; `…/file-library/1 OR 1=1/delete/` — 404; `getProperties` с `languageID=1 OR 1=1` — не 200
    с данными, без утечки.
  - `xslt-escaping.php`: подпись кнопки панели с `'` и `\` — в скрипте экранирована.
  FAIL.
- [ ] **Реализация.** Копии в `web/` от `web97`.
- [ ] **Green:** `perimeter.php`, `smoke-errors.php`, `smoke-csrf.php`, обход, `grids.js`, `editors.js`. Коммит.

### Task 3: JS

**Files:** `Form.js`, `GridManager.js`, `Filters.js`, `toolbar.xslt`, `tests/audit/grids.js`.

- [ ] **Red** (`grids.js`):
  - окно добавления пользователя: двойной щелчок «Сохранить» → одна запись;
  - ответ 500 с HTML на save → `alert` без `<html`, затемнение снято, форма открыта;
  - фильтр грида переводов: применить, сменить вкладку языка → фильтр пуст, строк — как без фильтра.
  FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `grids.js`, `editors.js`, `admin.js`, `public.js`. Коммит.

### Task 4: Итог

- [ ] `tests/README.md`, `docs/INSTALL.md` (безопасное удаление, `?struct`).
- [ ] Полный прогон, финальное ревью, исправления, финиш (вариант 3).
