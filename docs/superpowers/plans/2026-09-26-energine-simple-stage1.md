# Energine Simple — этап 1: отрезать модули. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Из форка и из базы simple.energine.org полностью уходят модули `shop`, `blog`,
`comments`, `calendar`, `forms`, `ads` и рассылки модуля `mail`. Отправка писем и шаблоны
писем переезжают в ядро `share`. Всё, что остаётся, работает как раньше.

**Architecture:** Код модулей удаляется из репозитория вместе со ссылками на них в ядре,
`apps`, теме и шаблонах. Изменения базы оформлены переходным скриптом `sql/cut/stage1.sql`,
который применяется после восьми файлов установки полной системы. Он же переводит
работающую базу этапа 0. Файлы демо-контента, которые больше ни к чему не привязаны,
перечислены в `sql/cut/stage1.files`. Сведение установочного SQL в один файл — этап 5.
Результат проверяют два теста:
- `tests/no-traces.sh` — в коде и базе не осталось имён вырезанного;
- `tests/raw-constants.php` — ни одна подпись интерфейса не потерялась при чистке переводов.

**Tech Stack:** PHP 8.5, MariaDB 10.11, XSLT, bash, Playwright для обхода.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — разделы 3
«Что вырезаем», 4 «Почта в ядре», 5 «База данных», 8 «Проверка», 9 (этап 1).

## Global Constraints

- Конфиги веб-сервера не менять.
- Всё в `/var/www/clients/client1/web97` принадлежит `web97:client1`: git от root, после него `chown -R web97:client1`.
- Команды приложения — от `web97` (`runuser -u web97 -- …`), PHP — `php8.5`.
- Пароли не попадают ни в git, ни в вывод команд. База читается через `tests/env.php` в подоболочке.
- Тестовые письма наружу не уходят — только `web97@loki.kweb.biz`.
- `web93` только читается.
- Пространства имён и названия оставшихся модулей не меняются.
- Остаются 4 шаблона писем: `user_registration`, `user_restore_password`, `feedback_form`, `feedback_form_admin`.
- Модули `apps` (кроме календаря новостей и комментариев к ним), теги, виджеты, мультисайт — не этот этап.

## Review Focus

1. **Удалена подпись, которую ещё использует оставшийся код.** Константа, которая строится динамически (`FIELD_<колонка>`), пропала из справочника, и в админке снова видно системное имя. Ожидание: набор сырых констант на страницах и в гридах после чистки не шире, чем до неё. Тест — задача 5.
2. **Каскадное удаление страниц задело живое.** Сегмент `admin`, `blogs` или `features` совпал на другом уровне дерева, например `features/admin`. Ожидание: удаляются только перечисленные разделы. Тест — задача 3, список страниц до и после.
3. **Файл демо-контента удалён, а новость или галерея на него ещё ссылаются.** Ожидание: удаляются только записи файлового репозитория без ссылок из оставшихся таблиц. Тест — задача 3, картинки новостей и галереи отдаются с кодом 200.
4. **Установка с нуля расходится с переведённой базой.** Ожидание: восемь файлов плюс `stage1.sql` дают ту же базу, что и перевод работающей, с точностью до журнала, сессий, доменов и хэша пароля. Тест — задача 6.
5. **Письма регистрации, восстановления пароля и обратной связи сломались после переезда `Mail` в ядро.** Ожидание: все три доходят до локального ящика, значения экранированы. Тест — `smoke-mail.php` в задачах 2–6.

---

### Task 1: Тест «нет следов» и снимок базы

**Files:**
- Create: `tests/no-traces.sh`
- Create: `/var/www/clients/client1/web97/private/backup/db-stage1-before-<время>.sql.gz` (вне репозитория, 600)

**Interfaces:**
- Produces: `bash tests/no-traces.sh [code|db|all] [модуль...]`. Модули: `mail`, `calendar`, `comments`, `forms`, `ads`, `blog`, `shop`, а также `mail-core` (класс `Mail` живёт в `share`, ссылок на `Energine\mail\gears\Mail*` нет). Выход 0 — следов нет, 1 — печатает найденное.

- [ ] **Step 1: Снимок базы до этапа**

```bash
B=/var/www/clients/client1/web97/private/backup; mkdir -p $B
( cd /var/www/clients/client1/web97/private/energine && envsh=$(php8.5 tests/env.php --shell) && eval "$envsh" \
  && mysqldump --single-transaction --routines -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" ) | gzip > $B/db-stage1-before-$(date +%Y%m%d-%H%M%S).sql.gz
chmod 600 $B/*.gz; chown -R web97:client1 $B; ls -la $B
```
Expected: файл больше 100 КБ.

- [ ] **Step 2: `tests/no-traces.sh`**

Для каждого модуля есть пара выражений:
- по коду: `grep -rnIE` по `core`, `site`, `htdocs`, `configs`, `cli`, `setup`, `tests`, кроме самого теста;
- по базе:
  - таблицы (`information_schema.TABLES`);
  - колонки оставшихся таблиц;
  - страницы: шаблоны `smap_content`/`smap_layout` и XML `smap_content_xml`/`smap_layout_xml`;
  - виджеты;
  - шаблоны писем.

Шаблоны вырезаемых модулей берутся списком имён файлов из их каталогов `templates` на web93. Точные выражения подбираются на красном прогоне шага 3: ни одно не должно цеплять оставшийся код.

- [ ] **Step 3: Красный прогон**

Run: `bash tests/no-traces.sh all`
Expected: `FAIL` по каждому из семи модулей и по `mail-core`, exit 1.

- [ ] **Step 4: Коммит**

```bash
git add tests/no-traces.sh && git commit -F - <<'EOF'
tests: проверка, что от вырезанных модулей не осталось следов

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014VfkKLsoZXLNEkkw2511kd
EOF
```

---

### Task 2: Почта в ядре и тесты целевого состава

**Files:**
- Move (`git mv`):
  - `core/modules/mail/gears/{Mail,MailTemplate}.php` → `core/modules/share/gears/`;
  - `core/modules/mail/components/MailTemplateEditor.php` → `core/modules/share/components/`;
  - `core/modules/mail/config/MailTemplateEditor.component.xml` → `core/modules/share/config/`;
  - `core/modules/mail/templates/content/mail_templates_editor.content.xml` → `core/modules/share/templates/content/`.
- Modify: пространства имён в перенесённых файлах; `use` в `user/components/{Register,RestorePassword}.php` и `apps/components/FeedbackForm.php`; класс компонента в `mail_templates_editor.content.xml`.
- Modify tests:
  - `regression.sh` — без наборов `ads`, `blog`, `shop`, `forms`, `comments` и `cleanup-shop`; переключается только получатель обратной связи;
  - `smoke-mail.php` — регистрация, восстановление пароля, обратная связь, редактор шаблонов;
  - `cleanup-mail.php` — только тестовый пользователь, обратная связь, ящик;
  - `paths-guest.txt`, `paths-all.txt`, `audit/crawl-*.txt` — без разделов вырезаемых модулей;
  - `smoke.sh`, `smoke-final.sh`, `smoke-roundtrip.php` — без формы конструктора форм.
- Delete tests: `smoke-shop.php`, `smoke-blog.php`, `smoke-ads.php`, `smoke-forms.php`, `smoke-comments.php`, `cleanup-shop.php`, `del-form.php`.

**Interfaces:**
- Produces: `Energine\share\gears\Mail`, `Energine\share\gears\MailTemplate`, `Energine\share\components\MailTemplateEditor`.
- Consumes: `tests/no-traces.sh code mail-core` из задачи 1.

- [ ] **Step 1: Красный** — `bash tests/no-traces.sh code mail-core` → FAIL.
- [ ] **Step 2: Перенос и правка ссылок** (git mv, namespace, `use`, класс в шаблоне), `php8.5 -l` по изменённым файлам.
- [ ] **Step 3: Зелёный** — `bash tests/no-traces.sh code mail-core` → ok.
- [ ] **Step 4: Тесты целевого состава.** Правки по списку Files. Страницы вырезаемых разделов удаляются из списков выражением:
  ```
  ^(admin/)?(blogs|cart|catalog|form-example|subscribe|subscriptions|my-orders|search|wishlist|banners)(/|\?|$)
  ^features/(blogs|shop|forms|comments|mail|ads)/
  ^admin/(ads-items|ads-types|comments-editor|form-builder|mail-crm|mail-subscribers|mail-subscriptions|shop)(/|$)
  ```
- [ ] **Step 5: Регрессия** — строгая обёртка (как `check-task4.sh` этапа 0, см. ledger) над `tests/regression.sh`.
  Expected: все наборы `failures: 0`, журнал PHP пуст, получатели восстановлены, письма только локально.
- [ ] **Step 6: Коммит** — «share: отправка писем и шаблоны писем переехали в ядро» (перенос) и «tests: состав наборов после этапа 1» (тесты), двумя коммитами.

---

### Task 3: База — `sql/cut/stage1.sql`

**Files:**
- Create: `sql/cut/stage1.sql`, `sql/cut/stage1.files`

**Interfaces:**
- Produces: скрипт, идемпотентный и безопасный на базе этапа 0 и на свежей установке. Порядок блоков:
  1. Колонки магазина в оставшихся таблицах: `share_sites.currency_id`, `share_sites.country_id`, `share_sitemap.smap_features_multi` вместе с внешними ключами.
  2. Таблицы. `DROP` по списку из `information_schema` через `PREPARE`, при `FOREIGN_KEY_CHECKS=0` только на время удаления:
     - `shop_%`, `blog_%`, `ads_%`, `frm_%`, `form_<число>%`;
     - `mail_%`, кроме `mail_templates%`;
     - `site_address`, `site_country%`, `share_sitemap_comment`, `apps_news_comment`, `share_sites_uploads`;
     - представление `shop_goods_view`.
  3. Страницы — разделы из списков Task 2 Step 4. Родитель определяется через корень (`smap_pid IS NULL`), поэтому `features/admin` не задевается. Удаление каскадом.
  4. Виджеты с классами `Energine\ads\…`.
  5. `<container name="leftAdBlock"/>` в `smap_content_xml`/`smap_layout_xml`.
  6. Шаблоны писем `mail_news`, `mail_news_item`, `mail_crm`, `mail_crm_item`.
  7. Записи `share_uploads` из `uploads/public/demo/`, на которые не ссылается ни одна оставшаяся таблица.
  8. Переводы — дописывает задача 5.
- Produces: `stage1.files` — пути относительно `web/`: 10 файлов демо-контента без ссылок и 4 баннера (`banner-*.jpg`).

- [ ] **Step 1: Красный** — `bash tests/no-traces.sh db` → FAIL по всем модулям.
- [ ] **Step 2: Снимок «до»** — список страниц `id seg name`, пути картинок новостей и галереи.
- [ ] **Step 3: Написать `stage1.sql` и `stage1.files`.**
- [ ] **Step 4: Применить к `c1senergine`**, затем удалить файлы:
  `(cd web && xargs -a …/stage1.files rm -f)`.
- [ ] **Step 5: Проверки**
  - `bash tests/no-traces.sh db` — ok для всех модулей;
  - разница списков страниц — ровно перечисленные разделы и их поддеревья;
  - картинки новостей и галереи отвечают 200;
  - повторный прогон `stage1.sql` не даёт ошибок и изменений (сравнение `CHECKSUM TABLE`).
- [ ] **Step 6:** в `smoke-mail.php` проверка «в гриде 4 шаблона»: сначала красная на 8, после скрипта зелёная. Затем регрессия.
- [ ] **Step 7: Коммит** «sql: переход базы на этап 1».

---

### Task 4: Код — модули и ссылки на них

**Files:**
- Delete: `core/modules/{shop,blog,comments,calendar,forms,ads,mail}`, `cli/mail_sender.php`, `core/modules/apps/components/NewsCalendar.php`, `core/modules/share/gears/GridExtender.php`
- Modify:
  - `apps/components/NewsFeed.php` — без `hasCalendar`, `createCalendar()` и `$calendar`;
  - `apps/transformers/feed.xslt` — без вывода календаря;
  - `apps/templates/content/news.content.xml` — без `commentsForm`;
  - `share/templates/layout/default.layout.xml` — без `topBanner`;
  - `site/.../energine.xslt` — без блока `top_adblock`;
  - `site/.../main.xslt` — без `include` семи модулей;
  - `site/.../main.css`, `print.css` — без `top_adblock`, `left_adblock`, стилей блогов и `ads_item`;
  - `<container name="leftAdBlock"/>` во всех шаблонах `content`;
  - `share/gears/Site.php` — без фавиконки магазина;
  - `share/gears/Document.php` и `document.xslt` — без атрибута `favicon`;
  - `share/gears/Response.php` — без `redirectToReferer()`;
  - `configs/system.config.default.php` и конфиг площадки — модули `share`, `user`, `apps`, `seo`, без `mail.subscriptions`.

- [ ] **Step 1: Красный** — `bash tests/no-traces.sh code` → FAIL.
- [ ] **Step 2: Удаления и правки по списку.** `php8.5 -l` по всем изменённым PHP, `xmllint --noout` по изменённым XML и XSLT.
- [ ] **Step 3:** `setup linker`, `setup scriptMap` от `web97`, затем `tests/setup-linker.sh`. В тесте список модулей — `share user apps seo`.
- [ ] **Step 4: Зелёный** — `bash tests/no-traces.sh all` → ok.
- [ ] **Step 5: Регрессия и обход.**
- [ ] **Step 6: Коммит** «Этап 1: модули shop, blog, comments, calendar, forms, ads и рассылки вырезаны».

---

### Task 5: Переводы

**Files:**
- Create: `tests/raw-constants.php` — выводит отсортированный набор системных имён (`FIELD_…`, `TXT_…`, `BTN_…`, `MSG_…`, `ERR_…`, `TAB_…`), видимых на страницах. Страницы берутся из `paths-*.txt` и `crawl-singles.txt`: HTML гридов, JSON `get-data`, формы добавления и правки. Пароль берётся из `env.php`.
- Create: `tests/tools/cut-constants.php` — кандидаты на удаление. В список попадает константа из справочника, если:
  - она встречается в файлах вырезанных модулей (их копии на web93) или имеет вид `FIELD_<колонка вырезанной таблицы>` (колонки из `information_schema` базы web93);
  - её нет в оставшихся файлах и она не совпадает с `FIELD_<колонка оставшейся таблицы>`;
  - она не попадает под динамический префикс оставшегося кода. Префиксы находятся поиском `'[A-Z]+_' .` по оставшемуся коду.
- Modify: `sql/cut/stage1.sql` — блок 8, `DELETE FROM share_lang_tags WHERE ltag_name IN (…)`.

- [ ] **Step 1: Базовая линия** — `php8.5 tests/raw-constants.php > before.txt` и `setup untranslated > untranslated-before.txt`.
- [ ] **Step 2: Кандидаты** — `php8.5 tests/tools/cut-constants.php … > delete.txt`. Список просматривается глазами.
- [ ] **Step 3: Блок 8 в `stage1.sql`, применить.**
- [ ] **Step 4: Проверки**
  - `raw-constants.php > after.txt`: `comm -13 before.txt after.txt` пусто, новых сырых имён нет;
  - `setup untranslated`: новых непереведённых нет.
- [ ] **Step 5: Коммит** «sql: переводы вырезанных модулей».

---

### Task 6: Установка с нуля

- [ ] **Step 1:** Контрольные суммы переведённой базы: `CHECKSUM TABLE` и число строк по каждой таблице, в файл.
- [ ] **Step 2:** Снять все таблицы, представления и процедуры `c1senergine`, затем установить по `docs/INSTALL.md`:
  - восемь файлов и `sql/cut/stage1.sql`;
  - пароль администратора и `tests/local.php`;
  - `setup install`;
  - HTTPS-домен;
  - распаковка загрузок и `stage1.files`.
- [ ] **Step 3:** Сравнить с шагом 1. Отличия допустимы только в `share_action_log`, `share_session`, `share_domains`, `share_domain2site` и в `u_password` администратора.
- [ ] **Step 4:** `no-traces.sh all`, регрессия, обход, `raw-constants.php` (не шире `before.txt`).

---

### Task 7: Документы

- [ ] `docs/INSTALL.md`:
  - шаг «База» дополнен `sql/cut/stage1.sql`, шаг «Загрузки» — `stage1.files`;
  - раздел «Состояние» — этап 1;
  - раскладка без `cli/mail_sender.php`.
- [ ] `README.md` — этап 1.
- [ ] `tests/README.md` — состав наборов, `no-traces.sh`, `raw-constants.php`.
- [ ] Скан секретов по изменённым файлам, коммит «docs: этап 1».
