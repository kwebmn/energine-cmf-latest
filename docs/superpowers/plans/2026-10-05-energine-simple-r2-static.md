# Energine Simple — надёжность, этап 2: статический анализ. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ошибки в PHP и JS видны до запуска: PHPStan и проверка типов JS входят в регрессию и не дают появиться
новым ошибкам; мёртвый код JS удалён.

**Разведка (2026-10-05):** PHPStan 2.2.17 работает под PHP 8.5; на коде ядра уровень 0 — 49 ошибок, уровень 2 — 231,
уровень 3 — 320. `tsc --checkJs` на скриптах админки — 349 ошибок, из них 203 внутри `jodit.min.js` (исключается
заглушкой типов), ~146 в нашем коде: в основном `Property … does not exist on type 'Element'` (результат
`querySelector` без уточнения типа), `Cannot find name 'Toolbar'`/`Jodit` (глобальные), присваивания классам.

**Architecture:**
- **PHPStan.**
  - `tools/get-phpstan.sh` скачивает `phpstan.phar` закреплённой версии и сверяет сумму из `tools/phpstan.phar.sha256`;
    phar не в git (`.gitignore`), как бинарник Tailwind.
  - `phpstan.neon` в корне: `paths` — `core/modules`, `setup`, `htdocs`, `site/modules`; `excludePaths` —
    `htdocs/resizer/timthumb.php` (чужой код), `core/modules/share/scripts`; `bootstrapFiles` —
    `tests/phpstan/bootstrap.php` (константы `ROOT_DIR`, `CORE_DIR`, `SITE_DIR`, `HTDOCS_DIR`, `DEBUG` …; без
    `vendor/autoload.php` — интерфейсы объявлены в файлах классов, автозагрузка даёт «Cannot redeclare»);
    `phpVersion: 80400` (8.5 анализатор ещё не знает); уровень 2; `phpstan-baseline.neon` с нынешними ошибками.
  - Перед базовой линией правятся находки уровня 0, которые дешевле исправить, чем записать: лживые `@return`
    (`main()` «should return bool»), `Container.php` без `namespace` (класс недостижим — удалить, если нет вызовов),
    `@final` на переопределяемом методе, несуществующие пути в `require`. Каждое исправление — отдельной строкой журнала.
  - `tests/phpstan.sh` (регрессия, `### phpstan`): без phar — FAIL с подсказкой (пропуск только `PHPSTAN_SKIP=1`);
    запуск `php8.5 tools/phpstan.phar analyse --no-progress --memory-limit=1G`; ошибки сверх базовой линии — провал.
- **Проверка типов JS без сборки.**
  - `jsconfig.json` в корне: `checkJs`, `allowJs`, `noEmit`, `types: []`, `lib: es2022 + dom`, `paths` для имён
    import map (`Energine`, `Toolbar`, …) → файлы скриптов; `jodit/*` → заглушка `tests/types/jodit.d.ts`.
  - `tests/types/globals.d.ts`: `Jodit`, `window.ModalBox`, `window.Energine`, `componentToolbars`, свойства, которые
    код вешает на элементы (`row.record`, `tab.pane`, `treeNode`, `options`, `iframe`), `Energine.translations`.
  - Ошибки в нашем коде доводятся до нуля уточнением типов в JSDoc (`/** @type {HTMLInputElement} */ (el)`) там, где
    это один-два знака, и исправлением настоящих ошибок; файл, где правок больше 30 без пользы, получает
    `// @ts-nocheck` с причиной — решение в журнал.
  - `tests/jscheck.sh` (регрессия, `### jscheck`): `npx -y -p typescript@5 tsc -p jsconfig.json` (Node уже стоит для
    аудитов; первый запуск тянет пакет из сети); без Node — FAIL с подсказкой (пропуск `JSCHECK_SKIP=1`).
- **Мёртвый код JS** — удаляется только то, что подтверждено grep-ом по `core`, `site`, `tests`:
  `Energine.singleMode`, `forceJSON`, `supportContentEdit`, `resize`, `request.request`; `Grid.getMetadata`, `headOff`,
  ветка `fitGridHeightToLeftCol`; `csv()` и `use()`; `Toolbar.File`, `FileRepository.uploadZip`, шаблон
  `control[@type='file']` в `toolbar.xslt`; `getElement()` в `Toolbar.js`/`PageList.js`; `TreeView.Node` из готового `li`;
  `.pane` в `Form.js`; `javascript/variable` в `document.xslt` и `DataSet.php`. Что grep находит живым — остаётся,
  с записью в журнал.

**Tech Stack:** PHPStan 2.2.17 (phar), TypeScript 5 (`tsc --noEmit`, только на машине разработчика/стенде), bash.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-reliability-design.md` (этап 2).

## Global Constraints

- Поведение сайта и админки не меняется: правки — только типы в JSDoc, docblock-и, мёртвый код; сверка
  `xslt-golden.sh` — без разницы; полный прогон после каждой задачи.
- Сайту и установке ни PHPStan, ни Node не нужны: оба — инструменты разработчика; phar и `node_modules` не в git.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе;
  письма только локально; web93 только читается; `rebuild.sh` не запускается.

## Review Focus

1. **Базовая линия PHPStan не прячет настоящие ошибки:** просмотреть `phpstan-baseline.neon` глазами — вызовы
   несуществующих методов и неопределённые переменные либо исправлены, либо названы в журнале.
2. **Правка docblock-ов не меняет поведение:** `@return` и `@final` — только комментарии; `Container.php` удалён
   лишь при нуле вызовов.
3. **Уточнения типов в JS не меняют код:** только `/** @type */`-приведения и JSDoc; `xslt-golden` — 0, аудиты зелёные.
4. **Мёртвый код:** каждое удаление — grep по `core`, `site`, `tests`, конфигам и XSLT до удаления.
5. **Проверки не требуют сети на каждом запуске:** `npx` берёт TypeScript из кеша; без Node или phar — понятный провал,
   не тихий пропуск.

Проверки: п. 1, 2 — `tests/phpstan.sh`, регрессия, обход; п. 3, 4 — `tests/jscheck.sh`, `grids.js`, `editors.js`,
`admin.js`, `public.js`, `xslt-golden`; п. 5 — `tests/phpstan.sh`, `tests/jscheck.sh` с подменой окружения.

---

### Task 1: PHPStan в регрессии

**Files:** `tools/get-phpstan.sh`, `tools/phpstan.phar.sha256`, `.gitignore`, `phpstan.neon`, `phpstan-baseline.neon`,
`tests/phpstan/bootstrap.php`, `tests/phpstan.sh`, `tests/regression.sh`; точечные правки docblock-ов и `Container.php`.

- [ ] **Red:** `tests/phpstan.sh` — нет phar → FAIL с подсказкой; с phar и без базовой линии — FAIL (ошибки есть).
- [ ] **Правки находок уровня 0** (каждая — строка журнала), затем `--generate-baseline` на уровне 2.
- [ ] **Green:** `tests/phpstan.sh` чисто; регрессия; обход. Коммит.

### Task 2: Проверка типов JS

**Files:** `jsconfig.json`, `tests/types/globals.d.ts`, `tests/types/jodit.d.ts`, `tests/jscheck.sh`, `tests/regression.sh`;
JSDoc-правки в `core/modules/share/scripts/*.js`, `core/modules/user/scripts/*.js`.

- [ ] **Red:** `tests/jscheck.sh` — ~146 ошибок, FAIL.
- [ ] **Уточнения типов** до нуля ошибок; настоящие ошибки (вызов несуществующего, неверное число аргументов) — в журнал
    с решением.
- [ ] **Green:** `tests/jscheck.sh`; `grids.js`, `editors.js`, `admin.js`, `public.js`; `xslt-golden` — 0. Коммит.

### Task 3: Мёртвый код JS

- [ ] **Red:** проверка в `tests/jscheck.sh`-соседе `tests/js-dead.php`: перечисленные имена не встречаются в `core`/`site`
    (кроме `jodit`). FAIL.
- [ ] **Удаление** по списку с grep-подтверждением; `toolbar.xslt`/`document.xslt`/`DataSet.php` — соответствующие ветки.
- [ ] **Green:** `js-dead.php`, `jscheck.sh`, аудиты, `xslt-golden` — 0 (или только удалённые пустые ветки). Коммит.

### Task 4: Итог

- [ ] `docs/INSTALL.md` (раздел «Проверка»: PHPStan, tsc), `tests/README.md`.
- [ ] Полный прогон, финальное ревью, исправления, финиш (вариант 3).
