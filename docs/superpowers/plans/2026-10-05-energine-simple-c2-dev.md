# Energine Simple — удобство, этап 2: удобство разработчика. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Новая страница или секция — меньше мест и меньше «магии»:
- короткие имена компонентов;
- секция по имени вместо номера;
- переводы сайта файлом;
- генератор страницы;
- проверка непереведённых констант.

**Architecture:**
- **Короткие имена.** `Component::create()` принимает `class="TextBlock"` без пространства имён: ищет `EnergineSite\<модуль>\components\<Имя>` среди модулей сайта, затем `Energine\{share,user,seo}\components\<Имя>`. Не нашлось — `ERR_DEV_NO_COMPONENT_CLASS` с именем. Полное имя по-прежнему работает.
- **Секция по имени.** У `TextBlock` новый параметр `section` (`hero` … `cta`). Номер блока и константа образца берутся из таблицы в `TextBlock` (`SECTIONS`: hero 11 … cta 18). Шаблоны страниц переходят на `<param name="section">hero</param>`. Номера в базе прежние — тексты не теряются.
- **Переводы файлом.**
  - `site/modules/main/translations.php` — массив `КОНСТАНТА => ['ru' => …, 'ua' => …]` для констант сайта: `CONTENT_*`, `TXT_SECTION_SAMPLE_*`.
  - Команда `setup translations` добавляет недостающие константы и переводы и не перезаписывает правленые в админке. `setup install` вызывает её после базовых данных.
- **Генератор.** `setup page --name=<имя> --title="<название>" --sections=hero,services,…` создаёт:
  - `site/modules/main/templates/content/<имя>.content.xml` с секциями (короткие имена, `section`);
  - строку `CONTENT_<ИМЯ>` в `translations.php`.

  Затем запускает `translations` и `linker` и печатает, что делать дальше. Неизвестная секция или существующий файл — отказ без изменений.
- **Непереведённые константы.** Проверка `tests/untranslated.php` запускает `setup untranslated` и ждёт «все переведены». `docs/NEW-SITE.md` упоминает команду.

**Tech Stack:** PHP 8.5, XML, bash.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-convenience-design.md` (этап 2).

## Global Constraints

- Прежние полные имена классов и `num` в XML работают как раньше.
- Тексты секций в базе не меняются.
- Общие правила проекта:
  - конфиги веб-сервера не трогаются;
  - владелец `web97:client1`;
  - пароли не в git и не в выводе;
  - письма только локально;
  - web93 только читается;
  - `rebuild.sh` не запускается;
  - команды `setup` — от `web97`.

## Review Focus

1. **Короткое имя, совпадающее у сайта и ядра:** сайт важнее, без двусмысленности.
2. **`setup translations` на базе, где администратор изменил перевод:** правка не теряется.
3. **`setup page` с плохим именем** (`../x`, пробелы, заглавные, существующий файл, неизвестная секция): отказ, ничего не создано.
4. **Шаблон с `section` и с прежним `num`** на одной площадке: тексты на месте (сверка `xslt-golden` — без разницы для демо-страниц).
5. **Чистая установка** получает константы сайта из файла (`fresh-check`).

Проверки:
- п. 1, 3 — `tests/dev-tools.php`;
- п. 2, 5 — `tests/dev-tools.php`, `fresh-check`;
- п. 4 — `xslt-golden` и `public.js`.

---

### Task 1: Короткие имена компонентов и секция по имени

- [ ] **Red** (`tests/dev-tools.php`, регрессия):
  - XML страницы с `class="TextBlock"` даёт компонент `TextBlock`;
  - `class="NoSuchThing"` — ошибка разработчика с именем;
  - `TextBlock` с `section=hero` получает `num` 11 и образец `TXT_SECTION_SAMPLE_HERO`.

  Через временную страницу со своим XML (`smap_content_xml`) и `?debug`, затем удаление. FAIL.
- [ ] **Реализация** в `Component::create` и `TextBlock::defineParams/main`. Шаблоны `landing`/`service`/`contacts` — на `section` и короткие имена.
- [ ] **Green:**
  - `dev-tools.php`;
  - `xslt-golden capture` до правки шаблонов и `compare` после — без разницы;
  - `public.js`, `editors.js`.
- [ ] Коммит.

### Task 2: Переводы файлом

- [ ] **Red:**
  - `setup translations` есть;
  - на временной константе из файла добавляет её;
  - повторный запуск ничего не меняет;
  - изменённый в базе перевод не перезаписывает.

  FAIL.
- [ ] **Реализация.**
  - `translations.php` — 3 `CONTENT_*` и 8 `TXT_SECTION_SAMPLE_*`, значения из `sql/cut/stage11.sql`;
  - `translationsAction`;
  - вызов из `installAction`;
  - тест подменяет путь файла через переменную окружения `ENERGINE_TRANSLATIONS`.
- [ ] **Green:** тест, `install-check`, `fresh-check`. Коммит.

### Task 3: Генератор страницы

- [ ] **Red** (`dev-tools.php`):
  - `setup page --name=claude-test --title=… --sections=hero,cta` создаёт файл и константу, страница выбирается в списке шаблонов;
  - плохие имена и секции — отказ, ничего не создано;
  - уборка: файл, строка в `translations.php`, константа в базе.

  FAIL.
- [ ] **Реализация** `pageAction`. **Green**, коммит.

### Task 4: Непереведённые константы и документы

- [ ] **Red:** `tests/untranslated.php` — вывод `setup untranslated` без непереведённых. Если сейчас есть — перевести (переход `stage13.sql`) или признать мёртвыми.
- [ ] **Документы:**
  - `docs/NEW-SITE.md` — `setup page`, `setup translations`, `setup untranslated`, короткие имена, `section`;
  - `docs/INSTALL.md` — раздел секций;
  - `tests/README.md`.
- [ ] **Green**, полный прогон, финальное ревью, исправления, финиш (вариант 3).
