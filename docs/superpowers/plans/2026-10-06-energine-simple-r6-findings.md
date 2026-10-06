# Energine Simple — надёжность 6: находки сравнения с xSight. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Закрыть дыры ядра, найденные сравнением с xSight (цикл в дереве, код 200 у страницы ошибки, мёртвая очистка
HTML, фиксация сессии, форма сохранения от клиента, транзакции, код переадресации), и добавить чистую вставку в
редакторе и время блоков в отладке.

**Architecture:**
- **Цикл:** `DivisionSaver::save` — до записи обход предков нового родителя (`smap_pid`) по базе; встретилась сама
  страница — `SystemException('ERR_DIV_PARENT_LOOP', ERR_WARNING)` (форма показывает текст).
- **Код 500:** внешний `catch (\Throwable)` `DocumentController::run` — в режиме HTML (не JSON) для `SystemException`,
  чей код не 403/404/422/503 и не ERR_WARNING/ERR_NOTICE, если код ответа ещё 200, — `setStatus(500)`.
- **Очистка:** гир `HtmlCleaner::clean(string $html): string` (Dom\HTMLDocument; без признаков Office — строка как
  есть); `DataSet::cleanupHTML` при `site.aggressive_cleanup` вызывает его вместо tidy (ветка tidy убирается).
- **Сессия:** `UserSession::start($UID)` — сессия уже была (cookie) и пользователь меняется: `session_write_close`,
  новый `createIdentifier()` в строке сессии, `session_id(новый)`, `session_start` (cookie с новым номером).
  `User::generatePassword` — `random_int`.
- **Форма:** `DBDataSet::getPreviousState()` — ключ записи в POST → `edit`, нет → `add` (если такие состояния есть в
  конфиге); иное имя — только состояние конфига с `<fields>`, иначе `DEFAULT_STATE_NAME`. `Component` не берёт
  состояние из `$_POST[имя][state]`. `Saver::validate` — необязательные поля с непустым значением проверяются,
  ошибки собираются все.
- **Транзакции:** `DivisionEditor::save` — `try { … commit } catch { rollBack; throw }`; `changeOrder` — оба UPDATE в
  транзакции. `Document` (страница-ссылка) — без `setStatus('301')`, 302 осознанно.
- **Вставка:** `EnergineEditor.js` — `defaultActionOnPaste` и `defaultActionOnPasteFromWord` = `insert_clear_html`.
- **Время блоков:** `Document::runComponents` и `build` меряют каждый компонент (`hrtime`, `Db::queryCount`); при
  `site.debug` — `<timings><component name class run build queries/></timings>` в корне XML.

**Tech Stack:** PHP 8.5 (Dom\HTMLDocument), MariaDB, XSLT 1.0, ES-модули, Jodit 4.15, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-06-energine-simple-r6-findings-design.md`.

## Global Constraints

- Поведение меняется только в названных местах; ответы JSON админки, 403/404/422/503, вид страниц — как прежде.
- Бюджет запросов на страницу (`tests/queries.php`): гость 20, администратор 30.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1` — сразу после правки файлов, которые
  отдаёт nginx (JS, CSS); живые PHP — правка в копии, `php8.5 -l`, подмена (комментарии `//` без `?>`); новый API —
  отдельным шагом с проверкой, потом вызывающий код; пароли не в git и не в выводе; письма только локально; web93 и
  web94 только читаются; `rebuild.sh` не запускается; `setup` — от web97; константы — `sql/cut/stage19.sql`, файлы
  установки — `tests/tools/regen-sql.sh`.
- Полный прогон после каждой задачи; регрессия считает и упавшие наборы.

## Review Focus

1. **Перенос страниц не сломан:** перенос в соседний и в чужой раздел, правка корня (родителя нет), добавление
   новой страницы — работают; отказ — только сама страница или потомок любой глубины.
2. **Ошибки:** ответы JSON админки (ошибка базы в форме, отказ проверки) — те же коды и тексты; 404/403/422 — как
   прежде; страница ошибки с кодом 500 по-прежнему показывает общий текст, без путей и SQL.
3. **Очистка не портит текст владельца:** HTML без признаков Office — байт в байт (iframe, script, `<i class="fa">`,
   `target="_blank"`, сущности); из Word остаются текст, жирный, ссылки, списки, таблицы, пустые строки (`&nbsp;`).
4. **Сессия:** после смены номера сохранены вход и данные сессии (токен формы вошедшего), выход работает, прежний
   номер не входит; вход без прежней сессии — как прежде.
5. **Формы админки сохраняются как прежде:** пользователи (пароль пустой при правке — не меняется), страницы,
   переводы, языки, роли, файлы, шаблоны писем, настройки сайта; неверное необязательное поле — ошибка с именем
   поля, несколько ошибок — все сразу.

Проверки: п. 1 — `tests/page-parent.php`; п. 2 — `tests/error-status.php`, `tests/smoke-errors.php`; п. 3 —
`tests/html-cleanup.php`; п. 4 — `tests/session-id.php`; п. 5 — `tests/form-state.php`, регрессия, аудиты.

---

### Task 1: Цикл в дереве страниц

**Files:** `core/modules/share/gears/DivisionSaver.php`, `sql/cut/stage19.sql` (раздел 1: `ERR_DIV_PARENT_LOOP` ru/ua),
`tests/page-parent.php` (новый, регрессия).

- [ ] **Red:** стенд `claude-pp` → `claude-pp/a` → `claude-pp/a/b`, отдельно `claude-pp2`. Через форму раздела
  (`/admin/structure/single/divEditor/save`, JSON): родитель `claude-pp` = сам — отказ с текстом константы, база
  прежняя, главная отвечает 200; родитель `claude-pp` = `b` (внук) — отказ; `a` → `claude-pp2` — сохранено; новая
  страница в `b` — сохранена. FAIL.
- [ ] **Реализация.** Обход предков нового родителя (`smap_pid`) до корня (не глубже 64) при правке; константа.
- [ ] **Green:** `page-parent.php`, регрессия, обход. Коммит.

### Task 2: Код ответа страницы ошибки

**Files:** `core/modules/share/gears/DocumentController.php`, `tests/error-status.php` (новый, регрессия).

- [ ] **Red:** стенд `claude-es` со своим XML страницы — испорченным (`<content><container>`): гость GET → 500 и
  текст страницы ошибки без путей сервера; `/claude-es-nope/` → 404; JSON-ошибка админки (как `smoke-errors.php`) —
  прежний код. FAIL (сейчас 200).
- [ ] **Реализация.** Условие 500 во внешнем `catch`.
- [ ] **Green:** `error-status.php`, `smoke-errors.php`, регрессия, обход. Коммит.

### Task 3: Очистка HTML без tidy

**Files:** `core/modules/share/gears/HtmlCleaner.php` (новый), `core/modules/share/components/DataSet.php`
(`cleanupHTML`), `tests/html-cleanup.php` (новый, регрессия).

**Interfaces:** Produces `HtmlCleaner::clean(string $html): string`.

- [ ] **Red:** (консоль) образец из Word (`<p class="MsoNormal" style="margin:0;mso-line-height:1">…<o:p>&nbsp;</o:p>`,
  `<!--[if gte mso 9]>…<![endif]-->`, `<span lang="EN-US" style="mso-bidi-font-weight:bold">`, `<font face>`,
  `<style>…mso-…</style>`, `<meta>`, `<w:Sdt>`) → без мусора, текст, `<b>`, ссылки, список, таблица, `&nbsp;` целы;
  HTML владельца без признаков Office (iframe, script, `<i class="fa fa-x"></i>`, `target="_blank"`, `&amp;`) —
  байт в байт. (HTTP) сохранение блока с мусором Word — в базе чисто, если `aggressive_cleanup` включена, иначе SKIP.
  FAIL (класса нет; через HTTP — без tidy мусор остаётся).
- [ ] **Реализация.** Гир; `cleanupHTML` — гир вместо tidy.
- [ ] **Green:** `html-cleanup.php`, `text-history.php`, `smoke-editing.php`, регрессия, аудит editors. Коммит.

### Task 4: Новый номер сессии при входе

**Files:** `core/modules/share/gears/UserSession.php`, `core/modules/user/…/User.php` (`generatePassword`),
`tests/session-id.php`.

- [ ] **Red:** строка сессии гостя с известным номером в базе (стенд), cookie `NRGNSID` с ним, вход (форма входа с
  токеном) → cookie сессии другое, строки с прежним номером нет, новая принадлежит вошедшему; запрос с прежним
  номером — гость; `generatePassword` — без `mt_rand` (по коду). FAIL.
- [ ] **Реализация.** Смена номера в `start`; `random_int`.
- [ ] **Green:** `session-id.php`, `smoke-login-limit.php`, `csrf`, регрессия, аудиты. Коммит.

### Task 5: Форма сохранения решается на сервере

**Files:** `core/modules/share/components/DBDataSet.php` (`getPreviousState`), `core/modules/share/components/Component.php`
(состояние из POST), `core/modules/share/gears/Saver.php` (`validate`), `tests/form-state.php` (новый, регрессия).

- [ ] **Red:** (a) пользователь: `componentAction=edit`, ключа нет, логин существующий → понятный отказ
  `ERR_USER_EXISTS`, не ошибка базы; (b) `POST /` с `langSwitcher[state]=claudeNope` (с токеном) → обычная главная
  200; (c) пользователь: телефон длиннее колонки и пустое ФИО → ошибка проверки с обоими именами полей; правка
  пользователя с пустым паролем — пароль прежний. FAIL.
- [ ] **Реализация.** `getPreviousState`, `Component`, `Saver::validate`.
- [ ] **Green:** `form-state.php`, регрессия (формы всех редакторов), аудиты grids и editors. Коммит.

### Task 6: Транзакции и код переадресации

**Files:** `core/modules/share/components/DivisionEditor.php` (`save`, `changeOrder`), `core/modules/share/gears/Document.php`,
`tests/page-parent.php` (проверка по коду), `tests/page-link.php` (302).

- [ ] **Red:** `page-link.php` — заход на страницу-ссылку: ровно 302 (проходит и сейчас — фиксирует решение);
  `page-parent.php` — по коду: `save` с откатом (`rollBack`), `changeOrder` в транзакции; в `Document` нет
  `setStatus('301')` перед переадресацией страницы-ссылки. FAIL (по коду).
- [ ] **Реализация.**
- [ ] **Green:** `page-parent.php`, `page-link.php`, `sections.php`, `page-aliases.php`, регрессия. Коммит.

### Task 7: Чистая вставка в редакторе

**Files:** `core/modules/share/scripts/EnergineEditor.js`, `tests/audit/editors.js`.

- [ ] **Red:** `editors.js` — вставка в блок (событие paste с `text/html` из Word: стили, классы `Mso…`, `<o:p>`,
  `<b>`, ссылка) → в редакторе без `style`/`class`/`o:p`, `<b>` и ссылка на месте. FAIL.
- [ ] **Реализация.** Две опции Jodit.
- [ ] **Green:** аудит editors, jscheck. Коммит.

### Task 8: Время блоков в отладке

**Files:** `core/modules/share/gears/Document.php`, `tests/queries.php`.

- [ ] **Red:** `queries.php` — у главной (`?debug`) есть `<timings>`: на каждый компонент `<component>` с `name`,
  `run`, `build` (числа, мс) и `queries`; сумма `queries` компонентов не больше `document/@queries`. FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `queries.php`, регрессия, xslt-golden (разницы нет: `<timings>` шаблоны не выводят). Коммит.

### Task 9: Итог

- [ ] `docs/INSTALL.md` (stage19), `tests/README.md` (наборы page-parent, error-status, html-cleanup, form-state; дополнения
  session-id, queries, editors), `docs/OWNER.md` (вставка из Word — без чужих стилей).
- [ ] Полный прогон (регрессия, обход, аудиты grids/editors/admin/public/theme, install/migration/fresh-check,
  xslt-golden), финальное ревью (Opus, Review Focus дословно), один проход исправлений, финиш (вариант 3).
