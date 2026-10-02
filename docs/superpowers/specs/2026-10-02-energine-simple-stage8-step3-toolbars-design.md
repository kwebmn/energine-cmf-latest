# Energine Simple, этап 8, шаг 3 — панели админки без MooTools: Toolbar и PageToolbar

Дата: 2026-10-02. Продолжение шага 2 (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md`,
выложен и проверен на площадке 2026-10-02).

## 1. Цель

Панели кнопок есть на каждой странице админки: у гридов и форм (их создают встроенные скрипты `toolbar.xslt` и
`file.xslt`, привязывают `GridManager`, `Form`, `DivManager`, `DivSidebar`) и у администратора на страницах сайта —
панель страницы (`PageToolbar`, её создаёт запуск поведений `document.xslt`). Шаг 3 переводит их на чистый JavaScript:

| Файл | Строк | Что внутри |
|---|---|---|
| `Toolbar.js` | 1197 | `Toolbar` и кнопки: `Control`, `Button`, `File`, `Switcher`, `Separator`, `Select` (и неиспользуемые `Text`, `CustomSelect`) |
| `PageToolbar.js` | 246 | панель страницы: наследует `Toolbar`, верхняя рамка, боковая панель, действия кнопок |

`PageToolbar` переходит вместе с `Toolbar`: класс MooTools не может наследовать класс JavaScript. Видимый итог шага —
**администратор на страницах сайта больше не получает MooTools** (кроме режима правки текста): панель страницы была
там единственным скриптом на MooTools. В админке интерфейс панелей прежний, администратор разницы не заметит.

## 2. Дорожная карта этапа 8

В шаге 2 шаг 3 был намечен как `Toolbar`, `Filters`, `TreeView`. С `PageToolbar` он вырос до 2 700 строк; чтобы каждый
шаг проверялся и выкладывался отдельно, `Filters` и `TreeView` переходят в шаг 4:
- шаг 3 (этот) — `Toolbar`, `PageToolbar`;
- шаг 4 — `Filters` (фильтры гридов) и `TreeView` (дерево разделов);
- шаг 5 — семейство `Form` (`Form`, `FileRepoForm`, `DivForm`, `ImageManager`, `GroupForm`) с `EnergineEditor`,
  `PageEditor`;
- шаг 6 — семейство `GridManager` (`FileRepository`, `UserManager`, `ActionLogManager`) и встроенные скрипты панелей
  гридов в `toolbar.xslt`, `file.xslt`;
- шаг 7 — семейство `DivManager` (`DivSidebar`, `DivTree`, `getDirsTree`); затем `MooCompat.js` и `mootools.min.js`
  уходят, скрипты переходят на ES-модули.

## 3. Что меняется

### 3.1. `Toolbar` — интерфейс прежний

Классы — `var Toolbar = class Toolbar …`, кнопки — `Toolbar.Button = class extends Toolbar.Control …` и т. д.; без
объявления `MooCompat`; файлы входят в `VANILLA_JS` (`tests/no-traces.sh`).
- **`new Toolbar(имя, свойства)`** — `ul.toolbar.clearfix.<имя>`; `properties`, `controls`, `getElement()`,
  `bindTo(объект)`, `appendControl(…кнопки)` (кнопка или описание `{type, id, onclick, …}` — по нему создаётся
  `Toolbar[Тип]`, как у панели страницы), `getControlById(id)`, `disableControls(…id)` (без id — все, кроме `close`),
  `enableControls(…id)`, `callAction(действие, данные)` (вызывает `привязанный[действие](данные)`), `dock()`.
- **Кнопки**: `Control` (свойства `id`, `icon`, `title`, `tooltip`, `action`, `disabled`, `class`; `build()`,
  `disable()`, `enable(force)`, `disabled()`), `Button` (класс `<id>_btn`, подсветка при наведении, щелчок — действие,
  нажатие мыши не уводит фокус из поля формы, `DisableAndSetProperty`, `EnableByProperty`), `File` (кнопка открывает
  выбор файла, действие получает прочитанный файл), `Switcher` (`state`, `aicon`, `getState()`; действие срабатывает
  до смены состояния — как сейчас), `Separator`, `Select` (подпись, список, смена — действие с самим списком;
  `getValue()`, `setSelected(id)`, `disable()`, `enable()`).
- Разметка и классы прежние: `li`, `icon unselectable`, `disabled` с прозрачностью 0,25, `highlighted`, `pressed`,
  `separator`, `select` и `span.label`; значок — `background-image` из `Energine.base + icon`; стили — `toolbar.css`
  через `Energine.loadCSS`.
- Действие кнопки получает событие браузера (прежний код — обёртку MooTools); аргумент никто из потребителей не
  использует — проверено.

### 3.2. `PageToolbar`

`new PageToolbar(путь, id страницы, имя, кнопки, свойства)`, как сейчас: панель прикреплена (`docked_toolbar`) в
`.e-topframe` сверху страницы, содержимое страницы переносится в `.e-mainframe`, у `html` — класс `e-has-topframe1`;
значок `img.pagetb_logo` (в режиме отладки — свой); боковая панель `.e-sideframe` с `iframe` (`путь + 'show/'`), если
не задано `noSideFrame`; щелчок по значку открывает и закрывает её (`html.e-has-sideframe`) и запоминает это в cookie
`sidebar` (домен, путь и срок 30 дней — как сейчас); действия — режим правки (кнопка-переключатель: вход — формой с
`editMode=1` и токеном, выход — перезагрузкой), окна `add`, `edit`, `showTmplEditor`, `showTransEditor`,
`showUserEditor`, `showRoleEditor`, `showLangEditor`, `showFileRepository`, `showSiteSettings`.
Стили — `pagetoolbar.css` через `Energine.loadCSS`.

### 3.3. Неиспользуемое уходит

Нет вызовов: `Toolbar.Text`, `Toolbar.CustomSelect` (около 290 строк), загрузка панели из XML (`load` у `Toolbar`,
`Control`, `Switcher`), `removeControl`, `undock`, `allButtonsUp`, `down`, `up`, `isDown`, `initially_disabled`,
`setAction`, `PageToolbar.Logo`.

### 3.4. Что не входит

`Filters`, `TreeView` (шаг 4) и остальные скрипты админки. Встроенные скрипты панелей гридов (`toolbar.xslt`,
`file.xslt`) создают панели прежними вызовами, а их строки на MooTools (`document.id`, `getElement`) остаются до шага 6:
на страницах гридов MooTools грузится для `GridManager`.

## 4. Проверки

Пишутся до переделки и проходят на нынешнем коде, кроме отмеченной:
- **Панель страницы** (администратор на главной): верхняя рамка с панелью, страница — в основной рамке, значок,
  боковая панель с `iframe`; щелчок по значку открывает боковую панель и запоминает это в cookie, второй — закрывает;
  «Режим правки» включает режим правки, где переключатель нажат, повторный щелчок его выключает; стили панелей — по
  разу. **MooTools не запрашивается и не определена у администратора на главной вне режима правки** — красная до
  переделки.
- **Панель грида** (пользователи): выключенная кнопка ничего не делает (`disableControls('add')` — щелчок по «Добавить»
  окна не открывает), включённая — открывает окно добавления.
- **Панель формы** (шаблон письма): список «после сохранения» показывает значение из cookie
  `after_add_default_action`, `getValue()` его возвращает; нажатие мыши на кнопку панели не уводит фокус из поля.
- `no-traces.sh`, категория `mootools`: `Toolbar.js` и `PageToolbar.js` — в `VANILLA_JS`.
- Регрессия, аудиты `public`, `grids`, `editors`, `theme`, `crawl` (обходит админку и страницы сайта
  администратором), `install-check`, `fresh-check` — на стенде.

## 5. Порядок работ

1. Проверки из раздела 4.
2. `Toolbar` и кнопки.
3. `PageToolbar`.
4. Документы, итоговая проверка, ревью ветки.
5. Выкладка — по «да» владельца: код в живое дерево, `setup linker`, `setup scriptMap`; регрессия и аудиты на
   площадке. База не меняется.

## 6. Риски

- Панели есть на каждой странице админки: ошибка в `Toolbar` ломает всю админку. Защита — `crawl` (все страницы и
  формы админки без ошибок JS), `grids`, `editors` (кнопки гридов, форм, окон, режима правки).
- Скрипты на MooTools вызывают методы MooTools у элементов панели (`controls[i].element.hasClass`,
  `grab(toolbar.getElement())`) — работает, пока MooTools загружена на их страницах; сами файлы панелей на MooTools не
  опираются.
- На страницах сайта панель страницы работает без MooTools: любой оставшийся вызов MooTools там стал бы ошибкой JS —
  `crawl` проходит страницы сайта администратором.

## 7. Результат

Панели админки (около 1 440 строк, из них около 400 неиспользуемых) — на чистом JavaScript; администратор на
страницах сайта без режима правки работает без MooTools; MooTools остаётся у 17 скриптов админки.
