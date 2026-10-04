# Energine Simple — интерфейс, подпроект 2: секции визиток и шаблоны страниц. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн, как подпроект 1). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Разработчик собирает визитку из готовых шаблонов страниц «Лендинг», «Услуга», «Контакты». Каждый шаблон — набор секций; секция — текстовый блок, который владелец правит на странице. Демо simple.energine.org переделано на эти шаблоны.

**Architecture:**
- **Секция** — контейнер шаблона содержимого с атрибутом `section="hero|services|prices|reviews|gallery|faq|contacts|cta"` и одним `TextBlock` внутри (`num` = имя секции).
- **Вывод секции.** Шаблон `container[@section]` в новом `site/modules/main/transformers/sections.xslt` выводит полосу `<section>` на всю ширину с классами секции из `ui.xslt`.
  - Вид текста владельца задают правила под классом секции в `@layer components` (`.ui-section-<имя>`): разметку пишет владелец, классов в ней нет — разрешённое исключение спецификации, как `.ui-text`.
  - Пустая секция посетителю не выводится, как пустой блок сейчас (`container.xslt:36`).
- **Пример текста.** В режиме правки пустая секция показывает образец разметки секции (шаблон `ui-section-sample` в `sections.xslt`, тексты — константы `TXT_SECTION_SAMPLE_*`). После первого сохранения в базе — текст владельца. Таблиц и колонок в базе не добавляется.
- **Шаблоны страниц** — `site/modules/main/templates/content/{landing,service,contacts}.content.xml`. После `setup linker` они видны в редакторе структуры как `main/landing.content.xml` и т. д. Названия — константы `CONTENT_LANDING`, `CONTENT_SERVICE`, `CONTENT_CONTACTS`.
- **База.** Константы — в `sql/cut/stage11.sql` (повторяемый). Демо-тексты — в `sql/cut/stage11-demo.sql`: применяется только к демо-базе площадки и генератором `regen-sql.sh`. Файлы установки — генератором.

**Tech Stack:** XSLT 1.0, Tailwind CSS 4.3.3 (сборка `setup css`), PHP 8.5, MariaDB, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-modern-ui-design.md` (раздел 4).

## Отступления от спецификации (на согласование)

1. **«Контакты» — без формы обратной связи.** Модуля формы в Energine Simple нет: модули вырезаны на этапах 2–6, `core/modules` = share, user, seo. Секция выводит адрес, телефон (`tel:`), почту (`mailto:`) и ссылку на карту. Форма — отдельная задача, если понадобится.
2. **«Галерея» — картинки из текста, не вложения.** Вложений страницы в Simple тоже нет. Владелец вставляет картинки в текст секции редактором (репозиторий файлов есть), секция раскладывает их сеткой.
3. **«Вопросы и ответы» — пары `h3` + абзацы, раскрытие `<details>` строит XSLT невозможно** (текст блока — строка). Секция выводит вопрос заголовком и ответ под ним; если владелец вставит `<details>`, он тоже оформлен.

## Global Constraints

- Новых таблиц в базе нет; логика JS админки не меняется.
- Без внешних адресов на страницах; тёмная схема сохраняется; без горизонтальной прокрутки от 320 px.
- Утилиты — через `ui.xslt`, в разметке — только раскладка; в классах XSLT нет `&amp;` (страж `css-build.sh`); утилиты `grid` нет — сетка `ui-grid`.
- Переход базы тексты сайтов не переписывает (правило этапа 5в): демо-тексты — только в `stage11-demo.sql`.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе; письма только локально; web93 только читается; `rebuild.sh` не запускается.

## Review Focus

1. **Админ в режиме правки.** Пустая секция видна с образцом и правится; после сохранения образец не возвращается. Очищенная секция снова пустая и посетителю не видна.
2. **Произвольный текст владельца в секции** (без картинки в первом экране, один пункт в услугах, длинное слово, таблица) не ломает раскладку на 320 px и не даёт горизонтальной прокрутки.
3. **Тёмная схема.** Контраст текста на полосах секций (первый экран с картинкой, призыв к действию на основном цвете) ≥ 4.5.
4. **Смена шаблона страницы на лендинг и обратно** не теряет и не путает тексты: `num` секций не совпадает с `1` обычной страницы.
5. **Новая установка без демо** (`fresh-check`, `install-check`) получает шаблоны и константы, а главная остаётся рабочей.

Проверки: п. 1 — `editors.js`; п. 2–3 — `theme.js`; п. 4 — `tests/sections.php`; п. 5 — `fresh-check`, `install-check`.

---

### Task 1: Вывод секции и пустая секция

**Files:**
- Create: `site/modules/main/transformers/sections.xslt`; `tests/sections.php` (в регрессии — `### sections`).
- Modify: `site/modules/main/transformers/include.xslt` (подключить после `ui.xslt`); `ui.xslt` (переменная `UI_SECTION` — полоса и внутренняя ширина); `tailwind.css` (`@source` уже видит `../transformers`); `tests/regression.sh`.

**Interfaces:**
- Produces:
  - контейнер `<container name="…" section="ИМЯ"><component class="Energine\share\components\TextBlock"><params><param name="num">ИМЯ</param></params></component></container>`;
  - вывод `<section class="ui-section ui-section-ИМЯ …" data-section="ИМЯ"><div class="{$UI_CONTAINER} …">текст</div></section>`;
  - шаблоны `ui-section-sample` (param `name`) и `ui-section-class` (param `name`).

- [ ] **Red.** `tests/sections.php` — XSLT-преобразование готового XML документа (как `tests/menu.php`, без базы):
  - непустая секция `hero` → один `section[@data-section='hero']` с текстом;
  - пустая секция гостю → нет `section`;
  - пустая секция в режиме правки (`@editable`) → `section` с `div.nrgnEditor` и образцом (заголовок `h1` у `hero`);
  - имя секции не из списка → контейнер выводится как обычный блок.

  Прогон — FAIL (шаблона нет).
- [ ] **Реализация.**
  - `sections.xslt`: шаблон `container[@section]` с `priority="2"` (выше `container[@block]`); условие видимости — то же, что `container.xslt:36` для TextBlock.
  - Полоса на всю ширину внутри ограниченного `main`: шаблоны лендинга без `aside`, полоса — `mx-[calc(50%-50vw)]` (проверить отсутствие прокрутки на 320 px).
  - Режим правки: при пустой записи вместо `--&nbsp;` выводится `ui-section-sample` внутри `div.nrgnEditor` (переопределение `component[@sample='TextBlock' and @editable]/recordset/record` для предка `container[@section]`, `priority="2"`).
- [ ] **Green:** `php tests/sections.php`, `bash tests/css-build.sh`. Коммит.

### Task 2: Восемь секций — оформление текста владельца

**Files:**
- Modify: `sections.xslt` (образцы `ui-section-sample` для всех восьми); `tailwind.css` (`@layer components` — правила `.ui-section-*`, общий `.ui-text`); `main.css` (сборка).
- Test: `tests/audit/theme.js`; страница-стенд — временный раздел из `theme-db.php` (команды `sections-add` / `sections-remove`, снимок и восстановление, как `tb-restore`).

Разметка образцов, она же соглашение для владельца:

| Секция | Текст владельца | Вид |
|---|---|---|
| `hero` | `h1`, `p`, ссылка `a` (кнопка), необязательная `img` | картинка — фон полосы (`object-cover`, затемнение для контраста), ссылка — кнопка `primary` |
| `services` | `h2`, затем `ul` — каждый `li`: `strong` (название) + текст; эмодзи/значок в начале | `li` — карточки сеткой 1/2/3 колонки |
| `prices` | `h2`, `ul` — каждый `li`: `h3` название, `p` цена, вложенный `ul`, `a` кнопка | тарифы колонками, кнопка внизу |
| `reviews` | `h2`, несколько `blockquote` с `p` и `cite` | цитаты карточками |
| `gallery` | `h2`, картинки `img` в абзацах | сетка картинок, `aspect-[4/3] object-cover` |
| `faq` | `h2`, пары `h3` + `p`; или `details`/`summary` | вопрос — жирный, разделители |
| `contacts` | `h2`, `p` с адресом, ссылки `tel:`, `mailto:`, ссылка на карту | две колонки на широком экране |
| `cta` | `h2` или `p`, ссылка `a` | полоса основного цвета, ссылка — кнопка `plain` |

- [ ] **Red** (`theme.js`, раздел-стенд со всеми восемью секциями, тексты образцов):
  - у каждой `section[data-section]` применены правила своей секции: `services li` — рамка и фон карточки; `hero a` — фон `primary`; `gallery img` — `object-fit: cover`; `cta` — фон `primary`;
  - нет прокрутки на 320 px;
  - контраст ≥ 4.5 в обеих схемах для текста, ссылок и кнопок секций;
  - отдельно — `hero` без картинки и `services` с одним пунктом и словом в 60 символов.

  FAIL.
- [ ] **Реализация:** правила в `@layer components` (не утилиты: разметку пишет владелец); цвета — только переменные `@theme`; образцы для всех секций. `setup css` от web97, `chown`.
- [ ] **Green:** `theme.js`, `css-build.sh`, `sections.php`. Коммит.

### Task 3: Шаблоны страниц и константы

**Files:**
- Create: `site/modules/main/templates/content/landing.content.xml` (hero, services, reviews, cta, contacts), `service.content.xml` (hero, `textBlock_1` с `num=1` в блоке `alfa`, prices, faq, cta), `contacts.content.xml` (contacts, `textBlock_1`); `sql/cut/stage11.sql`.
- Modify: `tests/sections.php` (п. 4 Review Focus); `sql/data.sql` (генератором).

- [ ] **Red** (`tests/sections.php`, с базой через `tests/testlib.php`):
  - три файла есть в `web/templates/content/main/` после `setup linker`;
  - список шаблонов редактора структуры (`DivisionEditor`, тот же метод, что строит выпадающий список) содержит `main/landing.content.xml` с названием из `CONTENT_LANDING` (не сам ключ);
  - имена `num` секций не пересекаются между собой и с `1`.

  FAIL.
- [ ] **Реализация.**
  - XML шаблонов: у лендинга нет `aside`; блок `alfa` с заголовком страницы — только у «Услуги» и «Контактов».
  - `stage11.sql`: `INSERT IGNORE` в `share_lang_tags` и переводы (ru, uk) для `CONTENT_LANDING`, `CONTENT_SERVICE`, `CONTENT_CONTACTS` и `TXT_SECTION_SAMPLE_*`. Повторный запуск ничего не меняет.
  - Применить к базе площадки (`mariadb c1senergine < sql/cut/stage11.sql` — пароль из конфигурации не печатается, тем же способом, что stage10).
  - `bash tests/tools/regen-sql.sh`.
- [ ] **Green:** `sections.php`, `migration-check`, `fresh-check`, `install-check`. Коммит.

### Task 4: Демо на новых шаблонах

**Files:**
- Create: `sql/cut/stage11-demo.sql`.
- Modify: `tests/tools/regen-sql.sh` (после `stage$last.sql` применить `stage$last-demo.sql`, если есть; строки демо по-прежнему уходят в `demo.sql`); `sql/demo.sql` (генератором); `tests/audit/public.js`, `tests/audit/crawl-guest.txt`.

- [ ] **Red** (`public.js`): главная демо — лендинг: видны секции `hero`, `services`, `reviews`, `cta`, `contacts`; есть страницы «Услуга» и «Контакты» со своими секциями; на всех — один `h1`, нет пустых `section`. FAIL.
- [ ] **Реализация.**
  - `stage11-demo.sql`, повторяемый:
    - главная (smap 80) → `main/landing.content.xml`;
    - одна из демо-страниц → `main/service.content.xml`, страница контактов → `main/contacts.content.xml`;
    - тексты секций (ru, uk) — `INSERT IGNORE` в `share_textblocks` / `_translation` с `smap_id` страницы и `tb_num` = имя секции.
  - Применить к базе площадки.
  - Генератор: `sql/demo.sql` содержит новые строки; `data.sql` главной не меняется — шаблон главной в чистой установке остаётся `main.content.xml`.
- [ ] **Green:** `public.js`, обход (`crawl.js`), `fresh-check`, `migration-check`. Коммит.

### Task 5: Правка на странице и итог

**Files:**
- Modify: `tests/audit/editors.js`; `docs/INSTALL.md` (раздел «Шаблоны страниц и секции»: соглашение разметки из таблицы Task 2, как добавить секцию); `tests/README.md` (`sections.php`).

- [ ] **Red** (`editors.js`, п. 1 Review Focus, на разделе-стенде):
  - пустая секция у администратора — с образцом и редактором;
  - сохранить образец → гостю секция видна с этим текстом;
  - очистить и сохранить → гостю секции нет, у администратора снова образец;
  - стенд удаляется со снимком.

  FAIL до проверки поведения сохранения пустого блока (этап 10: пустой блок сохраняется пустым).
- [ ] Исправления по итогам; документы.
- [ ] Полный прогон (`suite.sh … 20`), финальное ревью, исправления, финиш (вариант 3).
