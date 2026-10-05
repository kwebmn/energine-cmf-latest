# Energine Simple — надёжность, этап 3: владельцу. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Владелец не боится править сайт: любой текст можно вернуть, каждое сохранение видно в журнале и в дате
страницы; язык можно готовить незаметно для посетителей; ссылка на свою страницу ставится выбором из дерева;
у владельца есть памятка, у разработчика — `setup check` перед сдачей.

**Разведка (2026-10-06):** тексты — `share_textblocks` (`tb_id`, `smap_id`, `tb_num`) + `_translation`
(`tb_content`, без даты и автора); `TextBlock::save` (POST `data`, `ID`, `num`) пишет перевод текущего языка;
правка на странице — `PageEditor.BlockEditor` (встроенный Jodit, кнопки из `EnergineEditor.make`, сохранение на
`single_template + 'save-text?json'`). Журнал — `share_action_log`, пишет `ActionLog::write(type, data)` класса из
`site.action_log` (Grid и DivisionEditor), показывает `/admin/action-log/` (ActionList, `al_classname` через
`translate()` — нужна константа `CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK`). `share_sitemap.smap_last_mod` меняется
только при правке самого раздела; `LastMod` карты сайта (`GoogleSitemap`) берётся из него. Языки — `Language`
(читает все строки `share_languages`, `isValidLangAbbr` решает, язык ли первый сегмент адреса), `LangSwitcher` уже
пропускает `lang_is_active = 0`, колонки нет. Дерево разделов для выбора — `DivisionEditor`, состояние `selector`
(`/list/`), окно возвращает `node.getData()` (`smap_id`, `smap_name`, `smap_segment` = полный адрес из
`getURLByID`); библиотеку файлов редактор встраивает состоянием `DataSet::fileLibrary` (`createComponent` +
`shiftPath(1)`). `setup` — методы `<действие>Action` в `setup/Setup.php` (`checklinksAction`, `untranslatedAction`
с `getUntranslated`); демо-пользователи `anna|petro|olena@example.com`; статический `web/robots.txt` перекрывает
страницу robots (известно).

**Architecture:**
- **История текста** (`sql/cut/stage16.sql`): таблица `share_textblocks_history` (`tbh_id`, `tb_id` →
  `share_textblocks` ON DELETE CASCADE, `lang_id`, `tbh_date`, `u_id`, `tbh_content`). `TextBlock::save` перед
  записью кладёт прежний текст языка в историю (если он был и отличается), после — не больше 20 версий на
  (`tb_id`, `lang_id`); так же при очистке блока. Состояния TextBlock: `history` (`/history/`) — окно с гридом версий
  текущего языка (компонент `TextBlockHistory extends Grid`: дата, автор, начало текста; кнопки «Посмотреть»,
  «Вернуть», «Закрыть»); `view` (`/view/[int]/`) — старый текст целиком; `restore` (`/restore/[int]/`) — POST,
  текущий текст уходит в историю, версия становится текущей, ответ JSON `{result, data}`; окно возвращает текст,
  `PageEditor.BlockEditor` показывает его в редакторе и считает сохранённым. Кнопка «История» — в панели
  встроенного редактора (`PageEditor` передаёт её в `EnergineEditor.make` через `options.jodit.extraButtons`),
  выключена у блока, который ещё не сохраняли.
- **Сохранение как событие:** `TextBlock::save` и `restore` пишут в журнал (`site.action_log`): `UPDATE`,
  `al_objectname` = адрес страницы и номер блока, `al_data` — `smap_id`, `num`, `lang_id`, длина текста, у отката —
  `tbh_id`; и ставят `share_sitemap.smap_last_mod = NOW()` страницы блока (глобальный блок — без даты).
- **Язык «в подготовке»:** колонка `share_languages.lang_is_active` (по умолчанию 1). `Language` знает, редактор ли
  зритель (`isEditor()`: вошедший, чья группа имеет полные права на корень `share_sitemap`; один запрос, кэш);
  для прочих `getLanguages`, `getIDByAbbr`, `isValidLangAbbr` не видят выключенные языки — адрес `/ua/…` для гостя
  даёт 404, в переключателе языка нет. `LanguageEditor`: флажок `lang_is_active` (грид, добавление, правка),
  язык по умолчанию выключить нельзя (`ERR_LANG_DEFAULT_INACTIVE`). `LangSwitcher` помечает выключенный язык
  атрибутом `inactive` (видит его только редактор), подпись `TXT_LANG_INACTIVE`.
- **Ссылка на страницу:** кнопка `energineLink` в `EnergineEditor.make`: запоминает выделение, открывает окно
  `singlePath + 'page-tree/list/'`, по выбору вставляет `<a href="{Energine.base}{lang}/{segment}">выделение или
  название</a>`; окно без выбора ничего не меняет. `DataSet::pageTree` (`/page-tree/[any]/`) встраивает
  `DivisionEditor` так же, как `fileLibrary` — `FileRepository`.
- **Памятка и проверка:** `docs/OWNER.md` — памятка владельцу с заполнителями `{SITE}`, `{ADMIN_URL}`,
  `{LOGIN_URL}`, `{LANGUAGES}`; `setup manual [--out=ФАЙЛ]` печатает её с подставленными значениями из конфига
  и базы (без секретов). `setup check` — проверка перед сдачей, строки `OK/WARN/FAIL`, выход 1 при FAIL, базу не
  меняет: отладка выключена; `site.domain` задан; нет демо-пользователей; нет статического `web/robots.txt`;
  у каждой включённой публичной страницы есть название на каждом включённом языке и хотя бы один текст;
  битых ссылок нет (`LinkChecker`); непереведённых констант нет (`getUntranslated`); WARN — языки «в подготовке»,
  NOINDEX у неслужебных страниц, почта без SMTP.

**Tech Stack:** PHP 8.5, MariaDB, XSLT 1.0, ES-модули (Jodit 4), Playwright-аудиты.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-reliability-design.md` (этап 3).

## Global Constraints

- База меняется только `sql/cut/stage16.sql` (повторный запуск ничего не меняет), затем `tests/tools/regen-sql.sh`;
  новые строки sitemap — не нужны. Константы перевода — ru и ua.
- Поведение для гостя меняется только там, где названо (выключенный язык); для администратора — новые кнопки и окна.
  Полный прогон после каждой задачи; `unused-constants` сразу после правок констант.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе;
  письма только локально; web93 только читается; `rebuild.sh` не запускается; `setup` — от `web97`.

## Review Focus

1. **Откат не теряет текст:** перед откатом текущий текст уходит в историю; другие языки блока не трогаются; откат
   пустой версии (блок был очищен) очищает блок, а не падает.
2. **Предел истории и каскад:** 21-я версия вытесняет самую старую; удаление блока (все языки очищены) уносит и его
   историю; история не пишется, если текст не изменился.
3. **Язык «в подготовке» для гостя:** `/ua/info/quick-start/` — 404, а не страница по умолчанию с украинскими
   текстами; `sitemap.xml` и переключатель без него; редактор видит и правит; язык по умолчанию выключить нельзя.
4. **Ссылка на страницу:** адрес со всеми уровнями и языком (`/ua/info/quick-start/`), выделенный текст остаётся
   текстом ссылки, закрытие окна без выбора ничего не вставляет, окно работает и из формы (описание раздела), и с
   правки на странице.
5. **`setup check` и `setup manual`:** не меняют базу, не требуют отладки и `web97` может их запустить; в памятке
   не остаётся `{ЗАПОЛНИТЕЛЕЙ}` и нет паролей; `check` заканчивается кодом 1 ровно при строке FAIL.

Проверки: п. 1–2 — `tests/text-history.php`; п. 3 — `tests/lang-inactive.php`; п. 4 — `tests/audit/editors.js`;
п. 5 — `tests/dev-tools.php`.

---

### Task 1: История текста, откат, журнал и дата страницы

**Files:** `sql/cut/stage16.sql` (таблица, константы), `core/modules/share/components/TextBlock.php`,
`core/modules/share/components/TextBlockHistory.php` (новый), `core/modules/share/config/TextBlock.component.xml`,
`core/modules/share/config/TextBlockHistory.component.xml` (новый), `core/modules/share/scripts/PageEditor.js`,
`core/modules/share/scripts/EnergineEditor.js` (`extraButtons`), `core/modules/share/scripts/TextBlockHistory.js`
(новый: грид + «Посмотреть», «Вернуть»), `core/modules/share/transformers/text.xslt` (вывод `view`),
`tests/text-history.php` (новый, регрессия), `tests/audit/editors.js` (окно истории), `tests/audit/editors-db.php`.

- [ ] **Red** (`text-history.php`): сохранить блок трижды через `save-text` → в истории 2 версии, текущий —
  третий; `restore/<первая>/` → текущий = первый текст, в истории 3 версии (третий ушёл в историю), ua не тронут;
  журнал: строка `CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK` с `smap_id` блока; `smap_last_mod` страницы ≥ начала
  теста; 22 сохранения → в истории 20; очистка всех языков → строк блока и истории нет. FAIL (нет таблицы и состояний).
- [ ] **Реализация.** `stage16.sql` на площадку, `regen-sql.sh`; константы `BTN_HISTORY`, `BTN_RESTORE`, `BTN_VIEW`,
  `TXT_TEXT_HISTORY`, `FIELD_TBH_DATE`, `FIELD_TBH_AUTHOR`, `FIELD_TBH_EXCERPT`, `MSG_TEXT_RESTORED`,
  `CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK`, `CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCKHISTORY`,
  `HELP_TEXTBLOCKHISTORY_MAIN`.
- [ ] **Green:** `text-history.php`, `smoke-editing.php`, `textblock-langs.php`, `editors.js` (кнопка «История»
  открывает окно, «Вернуть» меняет текст в редакторе и у гостя), `unused-constants`, `fresh-check`,
  `migration-check`. Коммит.

### Task 2: Язык «в подготовке»

**Files:** `sql/cut/stage16.sql` (колонка, константы), `core/modules/share/gears/Language.php`,
`core/modules/share/components/LanguageEditor.php`, `core/modules/share/config/LanguageEditor.component.xml`,
`core/modules/share/components/LangSwitcher.php`, `site/modules/main/transformers/*.xslt` (подпись у выключенного
языка), `tests/lang-inactive.php` (новый, регрессия).

- [ ] **Red** (`lang-inactive.php`): ua выключен → гость: `/ua/info/quick-start/` 404, `/ua/` 404, на `/` в
  переключателе нет ua, `sitemap.xml` без `/ua/`; администратор: `/ua/info/quick-start/` 200, переключатель с ua и
  пометкой; сохранение языка по умолчанию с `lang_is_active = 0` — отказ `ERR_LANG_DEFAULT_INACTIVE`; флаг
  возвращается в конце (и при падении). FAIL.
- [ ] **Реализация.** Константы `FIELD_LANG_IS_ACTIVE`, `TXT_LANG_INACTIVE`, `ERR_LANG_DEFAULT_INACTIVE`;
  `HELP_LANGUAGEEDITOR_MAIN` упоминает «в подготовке».
- [ ] **Green:** `lang-inactive.php`, `smoke-final.sh`, обход, `grids.js` (грид языков), `fresh-check`,
  `migration-check`. Коммит.

### Task 3: Ссылка на страницу из дерева

**Files:** `core/modules/share/scripts/EnergineEditor.js`, `core/modules/share/components/DataSet.php` (`pageTree`),
`core/modules/share/config/*.component.xml` (состояние `pageTree` у компонентов с редактором: TextBlock, DivisionEditor,
MailTemplateEditor — по образцу `fileLibrary`), `tests/audit/editors.js`, `tests/component-states.php` (если проверяет
состояния конфигов).

- [ ] **Red** (`editors.js`): в режиме правки кнопка «Ссылка на страницу» открывает окно дерева; выбор
  `info/quick-start` вставляет `<a href="…/info/quick-start/">выделенный текст</a>`; закрытие без выбора ничего не
  вставляет; то же в форме раздела (описание). FAIL.
- [ ] **Реализация.** Подписи `EnergineEditor.labels` (ru, ua, en).
- [ ] **Green:** `editors.js`, `component-states.php`, `xslt-golden` — 0. Коммит.

### Task 4: `setup manual` и `setup check`

**Files:** `docs/OWNER.md` (новый), `setup/Setup.php` (`manualAction`, `checkAction`), `tests/dev-tools.php`.

- [ ] **Red** (`dev-tools.php`): `setup manual` печатает памятку с доменом площадки и адресом входа, без `{` `}`
  и без слов `password`/пароля из конфига; `--out=ФАЙЛ` пишет файл; `setup check` печатает строки `OK|WARN|FAIL`
  для каждого пункта и выходит с кодом 1 ровно при FAIL (на стенде отладка включена — ожидается FAIL «отладка»);
  база после `check` не изменилась (сравнение счётчиков таблиц). FAIL.
- [ ] **Реализация.**
- [ ] **Green:** `dev-tools.php`, `new-site-doc.sh`. Коммит.

### Task 5: Итог

- [ ] `docs/INSTALL.md` (сдача: `setup check`, `setup manual`; язык «в подготовке»), `docs/NEW-SITE.md` (3а: история
  текста, ссылка на страницу, памятка), `tests/README.md` (новые наборы).
- [ ] Полный прогон, финальное ревью, исправления, финиш (вариант 3).
