# Energine Simple — надёжность, этап 4: ядро. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ядро проще и честнее для того, кто его правит: запросы к базе — через небольшой типизированный слой с
параметрами, переводы и схема таблиц читаются одним запросом, типы полей — перечисление, реестр — явные методы;
поведение сайта не меняется, страницы делают заметно меньше запросов.

**Разведка (2026-10-06):** `QAL` (962 строки) — обёртка PDO с подстановками `%s`, `select()` через `func_get_args`,
`modify(mode, table, data, condition)`, конструктор принимает DSN; единственный экземпляр создаёт `Registry::getDB`.
`translate()` (Utils) — подготовленный запрос на каждую константу (кэш только в памяти запроса); `Cache` файловый,
включается `site.cache` и только без отладки — на стенде выключен, схема таблиц (`DBStructureInfo`) читается
`SHOW CREATE TABLE` на каждую таблицу в каждом запросе. Запросов на страницу (разница `Questions`, минимум из трёх):
гость — главная 61, `info/quick-start/` 63, вход 52; администратор — главная 74, грид пользователей 123, структура
113, переводы 153, правка страницы 72. Реестр: `E()->Utils` (43), `UserGroup` (5), `FileRepoInfo` (4),
`ErrorDocument` (2), `Response` (1), `PageStructureDocument` (1) — через `__get`; типизированных `get*()` — 12.
`FieldDescription::FIELD_TYPE_*` — 25 строковых констант, 144 использования; `setType()` принимает любую строку.

**Architecture:**
- **`Db` под фасадом `QAL`.** Новый гир `core/modules/share/gears/Db.php`: конструктор принимает `\PDO`, методы
  `rows(string $sql, array $params = []): array`, `row(...): ?array`, `scalar(...): mixed` (false, если строки нет),
  `column(...): array`, `exec(...): int`, `insert(string $table, array $row): int` (id), `update(string $table,
  array $data, array $where): int`, `delete(string $table, array $where): int`, `transaction(callable $fn): mixed`
  (вложенные — одна внешняя), `quoteName(string $name): string`; параметры — только `?`, имена таблиц и колонок —
  через `quoteName` (проверка идентификатора, иначе `SystemException ERR_DEV_BAD_IDENTIFIER`). `QAL extends Db`:
  прежний API без изменений, конструктор QAL создаёт PDO и отдаёт его родителю; все запросы QAL идут через
  `Db::run()` — один счётчик и один журнал запросов. Счётчик `Db::queryCount()`; при `site.debug` в `?debug`
  XML — атрибут `document/@queries` и элемент `<queries>` с текстом запросов (только отладка). `TextHistory`,
  `Language::isEditor` и `TextBlockHistory::loadData` переводятся на методы `Db` — образец для нового кода.
- **Переводы одним запросом.** Гир `Translator`: при первом обращении загружает все переводы языка одним запросом
  (`share_lang_tags` ⋈ `share_lang_tags_translation`), `translate($const, $langId)` — поиск в массиве,
  неизвестная константа — её имя (как сейчас); `Utils::translate` делегирует (имя `translate()` и `DBWorker`
  остаются). Другие повторяющиеся запросы по разбору журнала из задачи 1 (например, свойства сайта
  `share_sites_properties` по одному) — тоже одним запросом, если дают заметную долю.
- **Схема таблиц одним запросом; `enum FieldType`.** `DBStructureInfo` читает колонки, ключи и внешние ключи всех
  таблиц базы из `information_schema` (три запроса на процесс вместо `SHOW CREATE TABLE` на таблицу) — результат
  тот же массив `getColumnsInfo()`; сверка — снимок `tests/fixtures/schema-info.json` (tests/tools/schema-fixture.php
  `capture|compare`), снятый нынешним кодом до правки. `enum FieldType: string` с теми же значениями, что
  `FIELD_TYPE_*` (константы остаются псевдонимами `FieldType::X->value`); `FieldDescription::setType()` принимает
  `FieldType|string`, неизвестная строка — `SystemException('ERR_DEV_UNKNOWN_FIELD_TYPE')` (опечатка в
  `type="…"` конфига видна сразу, а не странным полем).
- **Реестр без `__get`.** `Registry`: `getUtils()`, `getUserGroup()`, `getFileRepoInfo()`, `getErrorDocument()`,
  `getPageStructureDocument()` (к имеющимся `getResponse()` и др.); 56 обращений `E()->Имя` переписаны на методы;
  `__get/__set/__isset/__unset` удалены, `@property` в docblock-е — тоже; PHPStan ловит пропущенное.
- Остаётся как есть: `QAL` API (вызовов сотни — не трогаем), `DBWorker` (`$this->dbh`), `Saver`, `Data`.

**Tech Stack:** PHP 8.5 (enum, readonly), MariaDB (information_schema), PHPStan, тесты HTTP и гир-уровня.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-reliability-design.md` (этап 4).

## Global Constraints

- Поведение сайта не меняется: `xslt-golden` (XML снят до правок) — 0 разниц; снимок схемы — совпадает; полный
  прогон, обход и аудиты после каждой задачи. База не меняется (нет `stage17.sql`).
- Запросов на страницу после этапа: гость ≤ 35 (главная), администратор ≤ 70 (грид пользователей) — бюджет
  закрепляется тестом `tests/queries.php` по `document/@queries` (стенд в отладке).
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе;
  письма только локально; web93 только читается; `rebuild.sh` не запускается.

## Review Focus

1. **Эквивалентность `Db` и прежнего пути QAL:** транзакции (`beginTransaction/commit/rollback` QAL и
   `Db::transaction` — один счётчик вложенности), `quote()`, `%s`-подстановки, `getLastRequest()` — без изменений;
   `insert()` возвращает id и для таблиц без автоинкремента не падает.
2. **Переводы:** константа без перевода → её имя; язык, которого нет; регистр имени (`strtoupper`); перевод,
   добавленный в этом же запросе (`setup translations`, `TranslationEditor::save`) — кэш сбрасывается или
   перечитывается.
3. **Схема:** таблица, появившаяся после старта процесса (переход базы), — читается заново; поля `SET`/`ENUM`
   (значения), внешние ключи и `PRI/UNI/MUL` — как прежде; представления.
4. **Типы полей:** конфиг с неизвестным `type` — ошибка разработчика с именем поля, а не страница 500 без
   объяснения; все 25 прежних значений принимаются.
5. **Реестр:** ни одного `E()->Имя` не осталось (статическая проверка), `E()->getUtils()` отдаёт тот же экземпляр.

Проверки: п. 1 — `tests/db.php`; п. 2 — `tests/queries.php`, `tests/untranslated.php`, `xslt-golden`; п. 3 —
`tests/tools/schema-fixture.php compare`; п. 4 — `tests/field-type.php`; п. 5 — `tests/registry.php`.

---

### Task 1: `Db` и журнал запросов

**Files:** `core/modules/share/gears/Db.php` (новый), `QAL.php`, `Registry.php` (getDB), `Document.php` (`@queries`,
`<queries>` при отладке), `TextHistory.php`, `Language.php`, `TextBlockHistory.php`, `tests/db.php` (новый,
регрессия), `tests/queries.php` (новый, регрессия: пока — наличие атрибута и запись замера).

- [ ] **Red:** `tests/db.php` — `new Db(pdo())`: `rows/row/scalar/column` с параметрами, `insert` отдаёт id,
  `update/delete` отдают число строк, `transaction` откатывает при исключении и возвращает результат, вложенная
  транзакция — одна внешняя, `quoteName('a b')` — исключение, `queryCount()` растёт. FAIL (класса нет).
- [ ] **Реализация.** `QAL extends Db`; `?debug` XML — `@queries` и `<queries>`.
- [ ] **Green:** `db.php`, `queries.php` (атрибут есть; значения записываются в журнал как база для задач 2–3),
  регрессия, обход, `xslt-golden` — 0. Коммит.

### Task 2: Переводы и повторяющиеся запросы одним запросом

**Files:** `core/modules/share/gears/Translator.php` (новый), `Utils.php` (`translate` делегирует), по разбору
журнала — `Site.php`/другие; `tests/queries.php` (бюджеты), `tests/translator.php` (новый, регрессия: имя
константы без перевода, регистр, другой язык, перевод добавлен в этом же процессе — виден).

- [ ] **Red:** `queries.php` с бюджетами (главная ≤ 35, грид пользователей ≤ 70) — FAIL; `translator.php` — FAIL.
- [ ] **Реализация.**
- [ ] **Green:** оба, `untranslated.php`, `xslt-golden` — 0, обход. Коммит.

### Task 3: Схема одним запросом и `enum FieldType`

**Files:** `tests/tools/schema-fixture.php` (новый), `tests/fixtures/schema-info.json` (снимок до правки),
`DBStructureInfo.php`, `core/modules/share/gears/FieldType.php` (новый), `FieldDescription.php`,
`tests/field-type.php` (новый, регрессия), `tests/schema-info.php` (новый, регрессия: compare).

- [ ] **Снимок** `schema-fixture.php capture` нынешним кодом (до правки `DBStructureInfo`).
- [ ] **Red:** `field-type.php` — `FieldType::from('string')->value === FieldDescription::FIELD_TYPE_STRING` для всех
  25, `setType('strng')` — `ERR_DEV_UNKNOWN_FIELD_TYPE`. FAIL. `queries.php` после переписывания схемы — бюджет
  гостя ужесточается по факту.
- [ ] **Реализация.** `schema-info.php compare` — 0 отличий.
- [ ] **Green:** `field-type.php`, `schema-info.php`, `queries.php`, регрессия, аудиты grids/editors, обход. Коммит.

### Task 4: Реестр без `__get`

**Files:** `Registry.php`, 56 обращений в `core/**/*.php`, `phpstan-baseline.neon` (перегенерировать),
`tests/registry.php` (новый, регрессия: статически — нет `E()->Имя`; `Registry` без `__get`).

- [ ] **Red:** `registry.php` — FAIL (обращения есть, `__get` есть).
- [ ] **Реализация.** `sed` по образцам, PHPStan чисто.
- [ ] **Green:** `registry.php`, `phpstan.sh`, регрессия, обход. Коммит.

### Task 5: Итог

- [ ] `docs/INSTALL.md` («Ошибки и отладка»: `?debug` показывает запросы; `setup clearCache` не нужен — кэша схемы
  нет), `docs/NEW-SITE.md` (разработчику: `Db` для нового кода, `FieldType`), `tests/README.md`.
- [ ] Полный прогон, финальное ревью, исправления, финиш (вариант 3).
