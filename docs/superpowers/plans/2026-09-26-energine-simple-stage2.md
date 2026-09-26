# Energine Simple — этап 2: разобрать apps. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Из модуля `apps` остаются только новости и обратная связь. Врезки раздела,
брендинг, подборки, опросы, облако тегов, похожие новости, RSS, общая лента проектов,
сокеты и Flash вырезаются из кода и базы. Редактор разделов больше не знает про `AdsManager`.

**Architecture:** Как на этапе 1:
- переходный скрипт `sql/cut/stage2.sql` применяется после `stage1.sql`, `stage2.files` — список демо-файлов;
- `tests/no-traces.sh` получает категории этапа 2;
- чистку переводов делает `tests/tools/cut-constants.php`, проверяет `tests/raw-constants.php`.

Урок этапа 1 учтён: код, который читает удаляемые таблицы (макет по умолчанию,
тема, редактор разделов), правится в той же задаче, что и база. Иначе сайт падает
между задачами. Инструменты сверки установки (`fingerprint.php`, `rebuild.sh`)
переезжают в `tests/tools`.

**Tech Stack:** PHP 8.5, MariaDB 10.11, XSLT, bash, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — раздел 3 «Из apps», раздел 5, раздел 9 (этап 2).

## Global Constraints

Те же, что на этапе 1:
- конфиги веб-сервера не трогаются;
- владелец `web97:client1`, git от root и после него `chown`, PHP `php8.5`;
- пароли не попадают ни в git, ни в вывод команд;
- письма только на `web97@loki.kweb.biz`;
- `web93` только читается;
- коммиты — с явными путями.

Остаются:
- компоненты `Feed`, `ExtendedFeed`, `FeedEditor`, `ExtendedFeedEditor` (базовые классы новостей);
- `NewsFeed`, `NewsEditor`, `NewsRepository`, `NewsCategoriesEditor`;
- `FeedbackForm`, `FeedbackList`;
- скрипты `AttachmentsCarousel.js`, `FeedToolbar.js`, `FeedbackForm.js`.

Архив новостей по датам остаётся: это фильтр в `NewsFeed::main()`. Теги — этап 3.

## Review Focus

1. **`DivisionEditor` и `DivisionSaver` после удаления `AdsManager`.** Ожидание: форма раздела открывается, сохраняется и не теряет права. Тест — `smoke-roundtrip`, `smoke-write`.
2. **Главная без опроса.** Компонент `Vote` убирается из XML страницы, остальные компоненты и тексты главной на месте. Тест — чтение всех страниц и обход.
3. **Константа, собираемая динамически, удалена вместе с вырезанным.** Ожидание: набор сырых имён не шире базовой линии. Тест — `raw-constants.php`.
4. **Картинки подборок и брендов удалены, а новости или галерея на них ссылаются.** Ожидание: удаляется только неиспользуемое. Тест — ответы 200 на картинки новостей и галереи.
5. **Установка с нуля расходится с переведённой базой.** Тест — `fingerprint.php` до и после `rebuild.sh`.

---

### Task 1: Тест «нет следов» для этапа 2, инструменты сверки, снимок базы

- [ ] Снимок базы: `backup/db-stage2-before-*.sql.gz`.
- [ ] В `tests/no-traces.sh` — категории `pageads`, `branding`, `tops`, `vote`, `feed`, `tagcloud`, `similar`, `rss`, `sockets`, `htmlcap`, у каждой код и база. По коду: классы, пути, таблицы, шаблоны, скрипты. По базе:
  - таблицы `apps_ads`, `apps_branding`, `apps_feed%`, `apps_tops%`, `apps_top_groups%`, `apps_vote%`, `test_feed`;
  - колонка `share_sitemap.brand_id`;
  - страницы и виджеты с этими компонентами;
  - демо-новость `podborki-na-glavnoj`;
  - слова в текстовых блоках.

  Выражения калибруются на красном прогоне так, чтобы не задевать оставшееся: новости, `Feed`, `ExtendedFeed`, теги этапа 3.
- [ ] `tests/tools/fingerprint.php` (отпечаток таблиц без колонок времени импорта) и `tests/tools/rebuild.sh` (установка с нуля по INSTALL.md) — из инструментов этапа 1.
- [ ] Красный прогон `no-traces.sh all` по новым категориям, коммит.

### Task 2: База и код, который её читает

**Files:**
- `sql/cut/stage2.sql`, `sql/cut/stage2.files`;
- `share/templates/layout/default.layout.xml` — без `pageAds` и `branding`;
- `site/.../energine.xslt` — без врезки и брендинга;
- `share/components/DivisionEditor.php`, `share/gears/DivisionSaver.php` — без `AdsManager`;
- `apps/templates/content/news.content.xml` — без `SimilarNews`.

**`stage2.sql`:**
1. `share_sitemap.brand_id` вместе с внешним ключом.
2. Таблицы по списку из `information_schema`.
3. Страницы от корня: `test-feed`, `admin/polls` с поддеревом, `admin/branding`, `admin/tops`, `admin/tops-groups`.
4. Виджет «Опрос».
5. Компонент `Vote` в XML страниц.
6. Демо-контент: новость `podborki-na-glavnoj`, тексты 61, 62, 73 — точными заменами.
7. Осиротевшие демо-файлы по правилу этапа 1.
8. Переводы — задача 4.

- [ ] Красный: `no-traces.sh db` (категории этапа 2).
- [ ] Скрипт и правки кода, применить, удалить файлы из `stage2.files`. Перед удалением файлов — поиск ссылок по полному дампу.
- [ ] Зелёный `no-traces.sh db`, повторный прогон без изменений, регрессия.

### Task 3: Код `apps` и ссылки на него

Удаляются:
- компоненты `Ads`, `Branding`, `TopOfThePops`, `Vote`, `VoteEditor`, `VoteQuestionEditor`, `TagCloud`, `SimilarNews`;
- `gears/AdsManager.php`;
- конфиги `SimilarNews`, `Vote*`, `ExtendedFeed`, `ExtendedFeedEditor` — только для прямого использования, у новостей свои;
- шаблоны `extfeed`, `branding_editor`, `totp_*` и в теме `vote_*`;
- XSLT `branding`, `rss`, `single_vote`, `tagcloud`, `totp`, `vote`;
- скрипты `MooSocket.js`, `swfobject.js`, `TOTP.js`, `Vote.js`, `web_socket.js`, `WebSocketMain.swf`;
- состояние `rss` у `NewsFeed` и ссылка на RSS в `feed.xslt`;
- `share/components/HTMLCap.php` — в описании ссылка на `apps\Ads`;
- стили опроса и врезки.

- [ ] Красный `no-traces.sh code`, удаления, `php -l` и проверка XML, `setup linker`/`scriptMap`, `setup-linker.sh`, зелёный `no-traces.sh all`, регрессия и обход, коммит.

### Task 4: Переводы

- [ ] `raw-constants.php` — базовая линия.
- [ ] `cut-constants.php`: удалённые файлы берутся из копии `apps` на web93, колонки — из базы web93.
- [ ] Блок 8 в `stage2.sql`, применить.
- [ ] `no-traces.sh i18n` зелёный, новых сырых имён нет, `setup untranslated` без новых.
- [ ] Коммит.

### Task 5: Установка с нуля

- [ ] `fingerprint.php` переведённой базы.
- [ ] `rebuild.sh`: восемь файлов, `stage1.sql`, `stage2.sql`, файлы обоих этапов.
- [ ] Сверка отпечатков.
- [ ] `no-traces.sh all`, `raw-constants.php`, регрессия, обход.

### Task 6: Документы

- [ ] `INSTALL.md`: `stage2.sql`, `stage2.files`, состояние этапа 2, список таблиц и страниц.
- [ ] `README.md` и `tests/README.md` — в том числе отложенные правки этапа 1: строки про формы и комментарии.
- [ ] Скан секретов, коммит.
