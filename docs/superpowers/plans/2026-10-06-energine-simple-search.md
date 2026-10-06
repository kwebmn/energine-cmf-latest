# Energine Simple — поиск по сайту. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Посетитель ищет по сайту на своём языке по любой форме слова и видит только доступные ему страницы с
отрывком и выделенными словами; индекс обновляется сам; владелец видит, что искали и не нашли.

**Architecture:**
- **Таблицы** (`sql/cut/stage20.sql`): `share_search_index` (smap_id + lang_id — ключ, title, body — текст для отрывка,
  title_stems, body_stems — основы через пробел; FULLTEXT по title_stems, body_stems и обоим; FK на страницу каскадом,
  на язык каскадом), `share_search_log` (log_query + lang_id — ключ, log_count, log_results, log_last). Обе — без
  строк в файлах установки; `tests/tools/fingerprint.php` их пропускает (производные и посетительские данные).
- **`Stemmer`** (гир): `stem(string $word): string` — нижний регистр, ё→е, отсечение окончаний ru/ua (кириллица) или en
  (латиница) по спискам в коде, основа не короче 3 букв; `words(string $text): string[]` — слова текста (буквы и цифры).
- **`SearchIndex`** (гир, `__construct(Db $db)`): `text(string $html): string` — HTML → текст (блочные теги — пробел,
  сущности раскрыты, пробелы схлопнуты); `page(int $smapId, ?int $langId = null): void` — строка индекса страницы на
  языке(ах): название (smap_name), заголовок (smap_title), описание (smap_description_rtf) и тексты её блоков
  (share_textblocks этой страницы); служебные страницы (сегменты `SYSTEM_SEGMENTS` у корня и всё под admin/) и
  страницы-ссылки не индексируются (их строка удаляется); `all(): int` — переиндексация всего, число строк.
- **Обновление:** `TextHistory::store` (правка и откат текста) → `SearchIndex::page(smap_id, lang)`;
  `DivisionEditor::save` → `page(id)`; удаление страницы — каскад. `setup reindex`; `setup install` и `setup demo` —
  в конце `all()`; `setup check` — строка «поиск: в индексе N страниц».
- **`SiteSearch`** (гир): `find(string $q, int $langId, int $page = 1): array` → `['query', 'terms', 'total', 'page',
  'pages', 'items' => [['id', 'url', 'title', 'snippet']]]`. Запрос: слова → основы (служебные знаки FULLTEXT убраны,
  слова короче 3 букв необязательны, не больше 10 слов); кандидаты — `MATCH(title_stems, body_stems) AGAINST
  ('осн1* осн2*' IN BOOLEAN MODE)` на языке, до 200; в PHP — все обязательные основы есть (префикс слова), страница видна
  посетителю (`E()->getMap()`: в дереве и права > 0), вес: в названии ×3 + в тексте ×1 (по числу совпадений);
  отрывок ~200 знаков вокруг первого совпадения, текст экранирован, совпадения — `<mark>`; по 10 на страницу.
  Журнал: `log(string $q, int $langId, int $total)` — upsert.
- **`SearchResults`** (компонент, страница `search`, шаблон `search.content.xml`): параметр `q`, `page`; XML запроса и
  результатов; XSLT темы (`energine.xslt`) — поле, «Найдено: N», список, листалка, «ничего не найдено». Поле поиска в
  шапке темы. **`SearchLog`** (компонент, админка `admin/search`, права 3): что искали, сначала без результатов.
- **Данные:** страница `search` у корня (права — как у `sitemap`), страница `admin/search` (права — как у журнала
  действий), константы — `stage20.sql`; `search` — служебный сегмент (`DivisionEditor::SYSTEM_SEGMENTS`,
  `tests/tools/regen-sql.sh`, `tests/pages-delete.php`).

**Tech Stack:** PHP 8.5, MariaDB 10.11 FULLTEXT (InnoDB, токен ≥ 3), XSLT 1.0, Tailwind v4 (`setup css`), Playwright.

**Spec:** `docs/superpowers/specs/2026-10-06-energine-simple-search-design.md`.

## Global Constraints

- Поведение сайта меняется только названным: поле поиска в шапке, страница результатов, админ-страница журнала,
  индекс при сохранении; прочие страницы — как прежде (`xslt-golden` — разница только в шапке и новых страницах).
- Бюджет запросов: гость на главной ≤ 20 (не растёт), страница результатов ≤ 20; сохранение текста — плюс запросы
  индекса одной страницы.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1` (JS/CSS — сразу после правки); живые
  PHP — правка в копии, `php8.5 -l`, подмена, новый API — отдельным шагом до вызывающего кода; комментарии `//` без
  `?>`; пароли не в git и не в выводе; письма только локально; web93/web94 только читаются; `rebuild.sh` не
  запускается; `setup` — от web97; новые скрипты — `setup linker`; константы и таблицы — `sql/cut/stage20.sql`,
  файлы установки — `tests/tools/regen-sql.sh`.
- Полный прогон после каждой задачи.

## Review Focus

1. **Видимость:** гостю не попадают страницы, закрытые правами, выключенные на его языке, служебные (вход,
   регистрация, профиль, админка, карта, robots, sitemap, сама страница поиска), страницы-ссылки; на втором языке —
   только страницы этого языка.
2. **Безопасность текста:** отрывок и эхо запроса экранированы (HTML и сущности в тексте страницы, `<script>` в
   запросе), подсветка не ломает разметку; служебные знаки FULLTEXT и кавычки в запросе — без ошибки; очень длинный
   запрос обрезается.
3. **Формы слов и языки:** «услуги/услуга/услугами», «цены/цена», украинские и английские формы; ё/е; регистр;
   слова через дефис и с цифрами; пустой запрос и запрос из одних коротких слов.
4. **Свежесть индекса:** правка текста, откат из истории, переименование страницы, удаление, выключение на языке —
   выдача отражает; общие блоки (подвал) не индексируются; `setup reindex` повторяем.
5. **Бюджет и ошибки:** страница результатов ≤ 20 запросов; сохранение текста не ломается, если индексирование
   упало (текст сохранён, ошибка в журнале).

---

### Task 1: Основы слов и индекс страниц

**Files:** `sql/cut/stage20.sql` (раздел 1: таблицы), `core/modules/share/gears/{Stemmer,SearchIndex}.php`,
`setup/Setup.php` (`reindexAction`, `all()` в конце install/demo, строка `check`), `tests/tools/fingerprint.php`
(пропуск таблиц), `tests/search.php` (новый, регрессия).

- [ ] **Red:** основы (ru: услуги/услуга/услугами/услугу — одна основа; цены/цена; ua: послуги/послуга; en:
  services/service; ё/е, регистр); `text()` (теги → пробелы, `&amp;`/`&nbsp;` раскрыты); индекс стенда `claude-sr`
  (текст блока, название) — строка с основами; служебная страница и страница-ссылка — строки нет; `setup reindex` от
  web97 — код 0, строк столько же, сколько индексируемых страниц × языков. FAIL.
- [ ] **Реализация.** Таблицы (живая база), гиры, команда.
- [ ] **Green:** `search.php`, регрессия, fresh/install/migration. Коммит.

### Task 2: Индекс обновляется сам

**Files:** `core/modules/share/gears/TextHistory.php`, `core/modules/share/components/DivisionEditor.php`, `tests/search.php`.

- [ ] **Red:** сохранение текста стенда через сайт → новое слово в индексе; откат из истории → прежнее; переименование
  страницы → новое название; удаление → строки нет; общий блок — не в индексе; сбой индексирования не мешает
  сохранению (по коду: try/catch с журналом). FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `search.php`, `text-history.php`, `smoke-editing.php`, регрессия. Коммит.

### Task 3: Поиск и страница результатов

**Files:** `core/modules/share/gears/SiteSearch.php`, `core/modules/share/components/SearchResults.php`,
`core/modules/share/templates/content/search.content.xml`, `site/modules/main/transformers/energine.xslt` (поле в
шапке, результаты), `sql/cut/stage20.sql` (раздел 2: страница `search`, константы), `DivisionEditor::SYSTEM_SEGMENTS`,
`tests/tools/regen-sql.sh`, `tests/pages-delete.php`, `tests/search.php`, `tests/audit/public.js`.

- [ ] **Red:** (HTTP, гость) `/search/?q=услуги` находит стенд с «услугами»; название выше текста; закрытая, выключенная
  на языке, служебная, страница-ссылка — нет; `/ua/search/?q=` — страницы второго языка; отрывок с `<mark>`, текст со
  `<script>` экранирован; пустой запрос — поле и подсказка; ничего — текст совета; `q` с `+-*"()<>~@` — 200; листалка
  `&page=2`; ≤ 20 запросов; поле поиска в шапке главной. `public.js` — поле в шапке и страница результатов без ошибок
  JS. FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `search.php`, аудит public, обход, xslt-golden (разница — шапка и новая страница), регрессия. Коммит.

### Task 4: Журнал поиска для владельца

**Files:** `core/modules/share/gears/SiteSearch.php` (`log`), `core/modules/share/components/SearchLog.php`,
`core/modules/share/templates/content/search_log.content.xml`, XSLT списка, `sql/cut/stage20.sql` (раздел 3: страница
`admin/search`, константы), `tests/search.php`, `tests/audit/admin.js`.

- [ ] **Red:** поиск гостя — строка журнала (запрос в нижнем регистре, число поисков растёт, найдено); админ-страница
  «Поиск по сайту» — запросы, сначала без результатов; гостю — 404. FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `search.php`, аудит admin, обход, регрессия. Коммит.

### Task 5: Итог

- [ ] `docs/OWNER.md` (поиск, журнал), `docs/INSTALL.md` (`stage20.sql`, `setup reindex`), `tests/README.md` (`search.php`).
- [ ] Полный прогон (регрессия, обход, аудиты, install/migration/fresh-check, xslt-golden), финальное ревью (Opus,
  Review Focus дословно), один проход исправлений, финиш (вариант 3).
