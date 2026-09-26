# Energine Simple — этап 4: Jodit и загрузка через fetch. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Визуальный редактор — Jodit (MIT) вместо CKEditor: в формах админки и при правке
прямо на странице. Загрузка файлов — `fetch` и `FormData` вместо FileAPI. CKEditor и FileAPI
уходят из репозитория целиком.

**Architecture:**
- **Сборка Jodit** лежит в `core/modules/share/scripts/jodit/`: `jodit.min.js`, `jodit.min.css`, `LICENSE.txt`. Это сборка `es2021` версии 4.15.14 с языками, в ней есть `ru` и `ua` — те же коды, что у Energine.
- **Подключение:**
  - `setup scriptMap` не сканирует каталог `jodit`, как сейчас `ckeditor`;
  - скрипт подключается как зависимость `ScriptLoader.load('jodit/jodit.min')`;
  - стили — через `Asset.css('../scripts/jodit/jodit.min.css')`.
- **Общая настройка** — один модуль `EnergineEditor.js`, его используют форма и правка на странице:
  - язык `Energine.lang`;
  - панель инструментов;
  - кнопки «Картинка из репозитория» и «Файл из репозитория». Они повторяют плагины `energineimage` и `energinefile`: окно библиотеки файлов, затем менеджер картинок, затем вставка HTML.
- **Встроенные загрузчик и файловый браузер** Jodit отключены: файлы идут только через репозиторий Energine.
- **Загрузка файла в форме репозитория** (`FileRepoForm`) — `fetch` с `FormData` на тот же `upload-temp/`. Поля прежние: `key`, `pid`, файл под именем поля.
- **Ветка JSONP** в `FileRepository::uploadTemporaryFile` (запасной путь FileAPI через iframe) уходит. В ней параметр `callback` без экранирования попадал в `<script>`.

**Tech Stack:** PHP 8.5, MooTools, Jodit 4.15.14, XSLT, bash, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — раздел 3 («CKEditor
заменяется на Jodit», «FileAPI: загрузка переходит на fetch»), раздел 4 «Клиентская часть»,
раздел 9 (этап 4).

## Global Constraints

Те же, что на этапах 1–3:
- конфиги веб-сервера не трогаются;
- владелец файлов `web97:client1`, git работает от root, после него `chown`;
- PHP — `php8.5`;
- пароли не попадают ни в git, ни в вывод команд;
- письма уходят только на `web97@loki.kweb.biz`;
- `web93` только читается;
- коммиты делаются с явными путями (`git add` — без путей, уже снятых через `git rm`).

Особое на этом этапе:
- **`rebuild.sh` не запускается**, пока пользователь не решит судьбу утёкшего тестового пароля администратора: скрипт пишет новый пароль в `tests/local.php`. Сверка установки с нуля откладывается. Изменения базы на этом этапе — только удаление переводов (детерминированно).
- Сторонние файлы Jodit не правятся. Всё своё — в коде Energine.

Остаются:
- **CodeMirror** — поля кода;
- **настройка `wysiwyg.styles`** (закомментирована в шаблоне конфига, на площадке не используется): её поддержка с CKEditor уходит, в Jodit не переносится. Решение — YAGNI.

## Review Focus

1. **Текст, сохранённый из формы с Jodit, совпадает с введённым.** Проверяются абзацы, ссылки, картинки, таблица. После повторного открытия формы разметка не теряется. Тест — `editors.js`: ввод, сохранение, чтение из базы; `smoke-roundtrip`.
2. **Правка на странице.** Администратор меняет текстовый блок главной, уходит со страницы — изменения сохранены. Правка новости в ленте тоже работает (`.nrgnEditor` в `feed.xslt`). Тест — `editors.js`, `smoke-editing`.
3. **Картинка и файл из репозитория вставляются в текст.** Кнопки открывают библиотеку и менеджер картинок, в текст попадает `<img>` или ссылка. Тест — `editors.js` (окно открывается, вставка через возвращённое значение).
4. **Загрузка через fetch.** Файл уходит на `upload-temp`, превью и имя подставляются, большой файл и отказ сервера показываются, а не глотаются. `.php` по-прежнему отвергается. Тест — `editors.js` (загрузка в форме репозитория), `smoke-upload`.
5. **Нет ошибок JS и 404 на страницах с редакторами:** формы новостей, разделов, текстовых блоков, режим правки. Тест — обход.

---

### Task 1: Тесты: следы CKEditor и FileAPI, браузерный тест редакторов

- [ ] В `tests/no-traces.sh` — категории `ckeditor`, `fileapi`, `jsonp`:
  - **код:** `CKEDITOR`, `ckeditor`, `energineimage`, `energinefile`, `sourcedialog`, `cke_`, `FileAPI`, `ctx[jsonp]`, `callback` в `uploadTemporaryFile`;
  - **файлы:** каталоги `scripts/ckeditor`, `scripts/FileAPI`.
- [ ] `tests/audit/editors.js` (Playwright, по образцу `crawl.js`; всё изменённое возвращается):
  1. Форма новости в админке: у поля текста есть редактор Jodit (`.jodit-container`). Ввести текст со ссылкой, сохранить форму — в базе новость с этим текстом, затем прежний текст возвращается. Ошибок JS нет.
  2. Главная в режиме правки: текстовый блок становится редактором Jodit. Ввести текст, уйти со страницы — в базе новый текст, затем прежний возвращается.
  3. Кнопка «Картинка из репозитория» открывает окно библиотеки файлов.
  4. Форма добавления файла в репозиторий: выбрать картинку — превью и имя подставлены, временный файл лежит в `uploads/temp`. Отменить, временный файл удалить.
- [ ] Красный прогон: `no-traces.sh all ckeditor fileapi jsonp`; `editors.js` падает (Jodit нет). Коммит.

### Task 2: Сборка Jodit и общий модуль настройки

- [ ] `scripts/jodit/`: `jodit.min.js`, `jodit.min.css`, `LICENSE.txt` из пакета `jodit@4.15.14`, сборка `es2021`.
- [ ] `setup/Setup.php`: каталог `jodit` исключён из сканирования `scriptMap`.
- [ ] `scripts/EnergineEditor.js`:
  - `EnergineEditor.make(element, options)`:
    - язык `Energine.lang`;
    - панель: исходник, жирный, курсив, подчёркнутый, зачёркнутый, списки, отступы, выравнивание, ссылка, таблица, формат абзаца (p, h1–h6), отмена и повтор, очистка формата, картинка и файл из репозитория;
    - вставка из буфера — очистка Word и HTML по умолчанию Jodit;
    - загрузчик и браузер файлов Jodit выключены.
  - Кнопки `energineImage` и `energineFile`: `ModalBox` → `file-library/` → для картинки `imagemanager`, затем `editor.s.insertHTML(...)`. Разметка — как в плагинах CKEditor.

### Task 3: Редактор в формах

- [ ] `Form.RichEditor`:
  - `EnergineEditor.make(textarea, {singlePath})` вместо `CKEDITOR.replace`;
  - `onSaveForm` переносит `editor.value` в `textarea`;
  - `ScriptLoader.load` без `ckeditor/ckeditor`, с `jodit/jodit.min` и `EnergineEditor`.
- [ ] Зелёные пункты 1 и 3 `editors.js`, `smoke-roundtrip`, обход форм.

### Task 4: Правка на странице

- [ ] `PageEditor.BlockEditor` — Jodit в режиме `inline` на элементе `.nrgnEditor`:
  - «грязность» — сравнение `editor.value` с исходным;
  - сохранение — `save-text`, как было, при уходе со страницы.
- [ ] `energine.css`: стиль фокуса вместо `.cke_focus`.
- [ ] Зелёный пункт 2 `editors.js`, `smoke-editing`.

### Task 5: Загрузка через fetch

- [ ] `FileRepoForm.xhrFileUpload` — `fetch` + `FormData`, ответ JSON:
  - ошибка сервера (`error`, `error_message`) показывается через валидатор формы;
  - `getFiles` — `input.files`.
- [ ] `FileRepository::uploadTemporaryFile` — без ветки JSONP.
- [ ] Удалить `scripts/FileAPI/`, исключение `FileAPI` в `Setup.php`.
- [ ] Зелёный пункт 4 `editors.js`, `smoke-upload`, `no-traces.sh all fileapi jsonp`.

### Task 6: Удаление CKEditor и переводы

- [ ] Удалить `scripts/ckeditor/` вместе с плагинами `energineimage` и `energinefile`, исключение `ckeditor` в `Setup.php`, остатки в стилях (`cke_`).
- [ ] `DataSet::addWYSIWYGTranslations` и её вызовы — если строки читал только CKEditor (проверить поиском в JS и XSLT).
- [ ] Поддержка `wysiwyg.styles` (`DBDataSet`, `TextBlock`, закомментированный блок в шаблоне конфига) — удалить.
- [ ] Переводы — `sql/cut/stage4.sql`:
  - `cut-constants.php` по удалённым файлам и строкам;
  - поиск по именам (`CKE`, `WYSIWYG`, `EDITOR`, `FILEAPI`);
  - буквальные имена удалённого кода, которых нет в оставшемся.

  Проверки: `no-traces.sh i18n`, `raw-constants.php`, `setup untranslated`.
- [ ] `setup linker`/`scriptMap`, висячие ссылки, `setup-linker.sh`. Зелёный `no-traces.sh all`.

### Task 7: Проверка этапа и документы

- [ ] Регрессия (9 наборов), `editors.js`, обход.
- [ ] Повторный прогон `stage4.sql` на базе ничего не меняет. Сверка установки с нуля — после решения пользователя о пароле (см. Global Constraints).
- [ ] Документы:
  - `INSTALL.md` — этап 4, `stage4.sql`;
  - `README.md`;
  - `tests/README.md` — `editors.js`, категории этапа 4.
- [ ] Скан секретов, коммит.
