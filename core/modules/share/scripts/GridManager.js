/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Grid]{@link Grid}</li>
 *     <li>[GridManager]{@link GridManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires TabPane
 * @requires PageList
 * @requires Toolbar
 * @requires Overlay
 * @requires ModalBox
 * @requires Filters
 *
 * @author Pavel Dubenko
 * @author Valerii Zinchenko
 * @author Oleg Marichev
 *
 * @version 1.2.0
 */

// todo: Strange to use scrolling and changing pages to see more data fields.

ScriptLoader.load('TabPane', 'PageList', 'Toolbar', 'Overlay', 'ModalBox', 'Filters');

/**
 * Таблица грида: строки записей, выбор (Ctrl — ещё строка, Shift — диапазон), сортировка по заголовку, ширины колонок
 * и высота под панель и окно.
 *
 * @constructor
 * @param {Element} element Элемент .grid.
 * @param {Object} [options] Обработчики onSelect(строка), onSortChange(), onDoubleClick().
 */
var Grid = class Grid {
    constructor(element, options) {
        Energine.loadCSS('grid.css');
        this.element = element;
        this.options = Object.assign({}, options);
        /**
         * Data of the grid.
         * @type {Object[]}
         */
        this.data = null;
        /**
         * Metadata of the grid.
         * @type {Object}
         */
        this.metadata = null;
        /**
         * Selected rows.
         * @type {Element[]}
         */
        this.selectedItem = [];
        /**
         * Sort parameters.
         * @type {{field: string, order: string}}
         */
        this.sort = {field: null, order: null};

        // TODO: I think this.headOff can be removed, because it is always hidden.
        this.headOff = this.element.querySelector('.gridContainer thead');
        this.headOff.style.display = 'none';
        this.tbody = this.element.querySelector('.gridContainer tbody');
        this.headers = Array.from(this.element.querySelectorAll('.gridHeadContainer table.gridTable th'));
        this.headers.forEach((header) => header.addEventListener('click', (event) => this.onChangeSort(event)));

        // добавляем к контейнеру класс, который указывает, что в нем есть грид
        this.element.closest('.e-pane').classList.add('e-grid-pane');

        // вешаем пересчет размеров гридовой формы на ресайз окна
        if (document.querySelector('.e-singlemode-layout')) {
            window.addEventListener('resize', () => this.fitGridSize());
        } else {
            window.addEventListener('resize', () => this.fitGridFormSize());
        }
    }

    /**
     * Обработчик из параметров: 'select' → onSelect и т. д.
     *
     * @param {string} type
     * @param {...*} args
     */
    emit(type, ...args) {
        const handler = this.options['on' + type.charAt(0).toUpperCase() + type.slice(1)];
        if (handler) {
            handler(...args);
        }
    }

    /**
     * Set the metadata; the key field is the one marked key.
     *
     * @param {Object} metadata
     */
    setMetadata(metadata) {
        for (const fieldName in metadata) {
            if (metadata[fieldName].key) {
                /**
                 * Key field name.
                 * @type {string}
                 */
                this.keyFieldName = fieldName;
            }
        }
        this.metadata = metadata;
    }

    getMetadata() {
        return this.metadata;
    }

    /**
     * Set the data (metadata first).
     *
     * @param {Object[]} data
     * @returns {boolean}
     */
    setData(data) {
        if (!this.metadata) {
            alert('Cannot set data without specified metadata.');
            return false;
        }
        this.data = data;
        return true;
    }

    // кнопки с классом nomultiselect выключены, пока выбрано несколько строк
    disableControlByMultiselect() {
        this.multiselectControls().forEach((control) => control.DisableAndSetProperty('DisabledByMultiselect'));
    }

    enableControlByMultiselect() {
        this.multiselectControls().forEach((control) => control.EnableByProperty('DisabledByMultiselect'));
    }

    multiselectControls() {
        const manager = this.element.closest('.e-pane').GridManager;
        if (!manager || !manager.toolbar) {
            return [];
        }
        return manager.toolbar.controls.filter((control) => control.element.classList.contains('nomultiselect'));
    }

    /**
     * Выбрать строку: без multiple — только её; multiple — добавить к выбранным; rangeselect — ещё и строки между ней
     * и последней выбранной.
     *
     * @param {Element} item
     * @param {boolean} [multiple]
     * @param {boolean} [rangeselect]
     */
    selectItem(item, multiple, rangeselect) {
        if (!multiple) {
            this.deselectItem();
            this.enableControlByMultiselect();
        }
        if (item) {
            item.classList.add('selected');
            if (multiple) {
                this.disableControlByMultiselect();
                if (rangeselect && this.selectedItem.length > 0) {
                    const el = this.selectedItem[this.selectedItem.length - 1];
                    let findup = el, finddown = el;
                    while (findup.previousSibling || finddown.nextSibling) {
                        if (findup.previousSibling) {
                            findup = findup.previousSibling;
                        }
                        if (finddown.nextSibling) {
                            finddown = finddown.nextSibling;
                        }
                        if (findup === item) {
                            finddown = false;
                            break;
                        } else if (finddown === item) {
                            findup = false;
                            break;
                        }
                    }
                    if (finddown === false || findup === false) {
                        let selected = (finddown === false) ? findup.nextSibling : finddown.previousSibling;
                        while (selected !== el) {
                            selected.classList.add('selected');
                            this.selectedItem.push(selected);
                            this.emit('select', selected);
                            selected = (finddown === false) ? selected.nextSibling : selected.previousSibling;
                        }
                    }
                }
                this.selectedItem.push(item);
            } else {
                this.selectedItem = [item];
            }
            this.emit('select', item);
        }
    }

    deselectItem() {
        this.selectedItem.forEach((row) => row.classList.remove('selected'));
    }

    /**
     * Выбранная строка (первая) или, с аргументом, все выбранные; null — ничего не выбрано.
     *
     * @param {boolean} [returnAsArray]
     * @returns {Element|Element[]|null}
     */
    getSelectedItem(returnAsArray) {
        if (!arguments.length) {
            return (this.selectedItem.length) ? this.selectedItem[0] : null;
        }
        return (this.selectedItem.length) ? this.selectedItem : null;
    }

    /**
     * Поля записи в порядке заголовков: скрытые и особые (custom) — первыми; заголовок без поля в записи прячется.
     *
     * @param {Object} record
     * @param {Element[]} header
     * @returns {Object}
     */
    sortRecordAsHeadersName(record, header) {
        const sorted = {};
        for (const fieldName in record) {
            if ((this.metadata[fieldName].type == 'hidden') ^ (this.metadata[fieldName].type == 'custom')) {
                sorted[fieldName] = record[fieldName];
            }
        }
        for (let i = 0; i < header.length; i++) {
            const colname = header[i].getAttribute('name');
            if (Object.prototype.hasOwnProperty.call(record, colname)) {
                sorted[colname] = record[colname];
            } else {
                header[i].style.display = 'none';
            }
        }
        return sorted;
    }

    /**
     * Build the rows: the record selected before (if it is still there) is selected and scrolled into view,
     * otherwise the first row; then the columns and the height.
     */
    build() {
        let previouslySelectedRecordKey = this.getSelectedRecordKey();
        this.selectedItem = [];
        this.gridHeadContainer = this.element.querySelector('.gridHeadContainer');
        this.gridHeadContainerTabs = Array.from(this.gridHeadContainer.querySelectorAll('th'));
        this.paneContent = this.element.closest('.e-pane-item');
        this.gridToolbar = this.element.querySelector('.grid_toolbar');
        this.gridContainer = this.element.querySelector('.gridContainer');

        if (!this.isEmpty()) {
            if (!this.dataKeyExists(previouslySelectedRecordKey)) {
                previouslySelectedRecordKey = false;
            }
            this.data.forEach((record, id) => {
                this.addRecord(this.sortRecordAsHeadersName(record, this.gridHeadContainerTabs), id, previouslySelectedRecordKey);
            });
            if (!this.selectedItem.length && !previouslySelectedRecordKey) {
                this.selectItem(this.tbody.firstElementChild);
            }
        } else {
            this.tbody.appendChild(document.createElement('tr'));
        }

        this.adjustColumns();
        // растягиваем gridContainer на высоту родительского элемента минус фильтр и голова грида
        this.fitGridSize();
        if (!this.minGridHeight) {
            const h = Grid.style(this.gridContainer, 'height');
            //Если грид запустился внутри вкладки формы
            this.minGridHeight = h ? parseInt(h, 10) : 300;
        }

        /* растягиваем всю форму до высоты видимого окна */
        if (!document.querySelector('.e-singlemode-layout')) {
            this.pane = this.element.closest('.e-pane');
            this.gridBodyContainer = this.element.querySelector('.gridBodyContainer');
            this.fitGridFormSize();
        }
    }

    /**
     * Строка записи: ячейки полей, подсветка под мышью, выбор щелчком (Ctrl — ещё строка, Shift — диапазон),
     * двойной щелчок — onDoubleClick.
     *
     * @param {Object} record
     * @param {number} id номер записи (чётность — класс строки)
     * @param {*} currentKey ключ записи, выбранной до перезагрузки
     */
    addRecord(record, id, currentKey) {
        // Проверяем соответствие записи метаданным.
        for (const fieldName in record) {
            if (!this.metadata[fieldName]) {
                alert('Grid: record doesn\'t conform to metadata.');
                return;
            }
        }
        // Создаем новую строку в таблице.
        const row = document.createElement('tr');
        row.className = (id % 2 == 0) ? 'odd' : 'even';
        row.setAttribute('unselectable', 'on');
        this.tbody.appendChild(row);
        // Сохраняем запись в объекте строки.
        row.record = record;
        for (const fieldName in record) {
            this.iterateFields(fieldName, record, row);
        }
        // Помечаем первую ячейку строки.
        row.firstElementChild.classList.add('firstColumn');

        if (currentKey == record[this.keyFieldName]) {
            this.selectItem(row);
            // выбранная прежде запись — в видимой части списка
            const container = document.body.querySelector('.gridContainer');
            container.scrollTop += row.getBoundingClientRect().top - container.getBoundingClientRect().top;
        }

        row.addEventListener('mouseover', () => {
            if (row != this.getSelectedItem()) {
                row.classList.add('highlighted');
            }
        });
        row.addEventListener('mouseout', () => row.classList.remove('highlighted'));
        row.addEventListener('click', (event) => {
            if (!(event.ctrlKey || event.shiftKey)) {
                if (row != this.getSelectedItem()) {
                    this.selectItem(row);
                }
            } else if (event.shiftKey) {
                this.selectItem(row, true, true);
            } else {
                this.selectItem(row, true);
            }
        });
        row.addEventListener('dblclick', () => this.emit('doubleClick'));
    }

    /**
     * Ячейка поля записи (невидимые поля пропускаются).
     *
     * @param {string} fieldName
     * @param {Object} record
     * @param {Element} row
     */
    iterateFields(fieldName, record, row) {
        // Пропускаем невидимые поля.
        if (!this.metadata[fieldName].visible || this.metadata[fieldName].type == 'hidden') {
            return;
        }
        const cell = document.createElement('td');
        cell.setAttribute('unselectable', 'on');
        row.appendChild(cell);
        cell.classList.add(fieldName); // добавляем имя поля в класс
        switch (this.metadata[fieldName].type) {
            case 'boolean': {
                const checkbox = document.createElement('img');
                checkbox.setAttribute('src', 'images/checkbox_' + (record[fieldName] == true ? 'on' : 'off') + '.png');
                checkbox.setAttribute('width', '13');
                checkbox.setAttribute('height', '13');
                cell.appendChild(checkbox);
                cell.style.textAlign = 'center';
                cell.style.verticalAlign = 'middle';
                break;
            }
            // значения — текстом: в данных может оказаться разметка посетителя (обратная связь, регистрация)
            case 'value':
                cell.textContent = record[fieldName]['value'];
                break;
            case 'file':
                if (record[fieldName]) {
                    const image = document.createElement('img');
                    image.setAttribute('src', Energine.resizer + 'w40-h40/' + record[fieldName]);
                    image.setAttribute('width', 40);
                    image.setAttribute('height', 40);
                    cell.appendChild(image);
                    cell.style.textAlign = 'center';
                    cell.style.verticalAlign = 'middle';
                }
                break;
            default: {
                let fieldValue = '';
                if (record[fieldName] || record[fieldName] == 0) {
                    fieldValue = Grid.clean(record[fieldName].toString());
                }
                const prevRow = row.previousElementSibling;
                if ((this.metadata[fieldName].type == 'select') && (row.firstElementChild == cell) && prevRow
                    && (prevRow.record[fieldName] == record[fieldName])) {
                    fieldValue = '';
                    prevRow.firstElementChild.style.fontWeight = 'bold';
                }
                cell.textContent = (fieldValue != '') ? fieldValue : ' ';
            }
        }
    }

    /**
     * Ширины колонок заголовка — по ячейкам первой строки; заголовок шире своей ячейки — колонка по заголовку,
     * остальные сужаются пропорционально.
     */
    adjustColumns() {
        const headers = [];
        // Adjust padding-right for '.gridHeadContainer' element.
        this.gridHeadContainer.style.paddingRight = Grid.scrollBarWidth() + 'px';
        if (!this.element.querySelector('table.gridTable').classList.contains('fixed_columns')) {
            const tds = Array.from(this.tbody.querySelector('tr').querySelectorAll('td')),
                ths = Array.from(this.gridHeadContainer.querySelectorAll('th')),
                headCols = Array.from(this.gridHeadContainer.querySelectorAll('col')),
                bodyCols = Array.from(this.element.querySelectorAll('.gridContainer col'));
            const setWidth = (n) => {
                if (headCols[n] !== undefined) {
                    headCols[n].style.width = Math.round(headers[n]) + 'px';
                }
                if (bodyCols[n] !== undefined) {
                    bodyCols[n].style.width = Math.round(headers[n]) + 'px';
                }
            };

            // Get the col width from the tbody
            for (let n = 0; n < tds.length; n++) {
                headers[n] = Grid.totalWidth(tds[n]);
            }
            // Set col width
            for (let n = 0; n < tds.length; n++) {
                setWidth(n);
            }

            const oversizeHead = [];
            for (let n = 0; n < tds.length; n++) {
                if (ths[n] !== undefined) {
                    oversizeHead[n] = Grid.totalWidth(ths[n]) > headers[n];
                }
            }
            if (oversizeHead.length > 0) {
                const newWidth = [], colWidth = [0, 0];
                for (let n = 0; n < tds.length; n++) {
                    if (oversizeHead[n]) {
                        newWidth[n] = Grid.totalWidth(ths[n]);
                        colWidth[1] += newWidth[n] - headers[n];
                    } else {
                        colWidth[0] += headers[n];
                    }
                }
                colWidth[1] += colWidth[0];
                const scaleCoef = colWidth[0] / colWidth[1];
                for (let n = 0; n < tds.length; n++) {
                    headers[n] = (oversizeHead[n]) ? newWidth[n] : Math.floor(headers[n] * scaleCoef);
                    // Reset col width
                    setWidth(n);
                }
            }
        } else {
            this.tbody.parentElement.style.tableLayout = 'fixed';
        }
        this.tbody.parentElement.style.wordWrap = 'break-word';
    }

    /**
     * Высота списка — высота панели минус голова грида, фильтр, отступ и нижняя панель окна.
     */
    fitGridSize() {
        if (this.paneContent) {
            const margin = Grid.style(this.element, 'marginTop'),
                eBToolbar = document.body.querySelector('.e-pane-b-toolbar'),
                gridHeight = this.paneContent.offsetHeight
                    - this.gridHeadContainer.offsetHeight
                    - ((this.gridToolbar) ? this.gridToolbar.offsetHeight : 0)
                    - ((margin) ? parseInt(margin, 10) : 0)
                    - ((eBToolbar) ? eBToolbar.offsetHeight : 0);
            if (gridHeight > 0) {
                this.gridContainer.style.height = (gridHeight - 9) + 'px';
            }
        }
    }

    /**
     * Панель грида на странице — по содержимому, но не выше видимой части окна; затем высота списка.
     */
    fitGridFormSize() {
        if (this.pane) {
            const toolbarH = (this.gridToolbar) ? this.gridToolbar.offsetHeight : 0,
                gridHeadH = Grid.totalHeight(this.gridHeadContainer),
                paneToolbarT = this.pane.querySelector('.e-pane-t-toolbar'),
                paneToolbarTH = (paneToolbarT) ? paneToolbarT.offsetHeight : 0,
                paneToolbarB = this.pane.querySelector('.e-pane-b-toolbar'),
                paneToolbarBH = (paneToolbarB) ? paneToolbarB.offsetHeight : 0,
                paneH = this.pane.offsetHeight,
                margin = Grid.style(this.element, 'marginTop'),
                gridBodyContainer = this.element.querySelector('.gridBodyContainer');
            let gridBodyHeight = gridBodyContainer.offsetHeight
                + parseInt(Grid.style(this.gridContainer, 'borderTopWidth'), 10)
                + parseInt(Grid.style(this.gridContainer, 'borderBottomWidth'), 10);

            if (gridBodyHeight < this.minGridHeight) {
                gridBodyHeight = this.minGridHeight;
            }

            /*
             * +3 at the end is:
             *   +2 from e-pane-content border
             *   +1 from somewhere, I do not why this should be
             */
            const totalH = toolbarH + gridHeadH + gridBodyHeight + paneToolbarTH + paneToolbarBH
                + ((margin) ? parseInt(margin, 10) : 0) + 3;

            /*
             * -81 at the end is:
             *   -31 from e-topframe height
             *   -50 from footer
             * they are not visible from grid
             */
            const windowHeight = document.documentElement.clientHeight;
            let freespace = windowHeight;

            if (document.body.scrollHeight - Grid.scrollBarWidth() < windowHeight) {
                freespace -= Grid.pageY(this.pane) + Grid.scrollBarWidth();
            }

            if (totalH > paneH) {
                this.pane.style.height = Math.round((totalH > freespace) ? freespace : totalH) + 'px';
                const leftCol = document.querySelectorAll('div[column=left]');//ugly

                if (this.pane.parentNode.parentNode.parentNode.classList.contains('fitGridHeightToLeftCol') && leftCol.length) {
                    const fitGridHeightToLeftCol = leftCol.clientHeight - (toolbarH + gridHeadH - 30);//ugly

                    this.pane.style.height = Math.round(fitGridHeightToLeftCol) + 'px';
                }
            }

            this.fitGridSize();
        }
    }

    isEmpty() {
        return !this.data.length;
    }

    /**
     * Record of the selected row or false.
     * @returns {Object|boolean}
     */
    getSelectedRecord() {
        if (!this.getSelectedItem()) {
            return false;
        }
        return this.getSelectedItem().record;
    }

    /**
     * Selected rows or false.
     * @returns {Element[]|boolean}
     */
    getSelectedRecords() {
        if (!this.getSelectedItem(true)) {
            return false;
        }
        return this.getSelectedItem(true);
    }

    /**
     * Ключ выбранной записи; с аргументом и несколькими выбранными — ключи через запятую; false — ничего не выбрано.
     *
     * @param {boolean} [multiple]
     * @returns {*}
     */
    getSelectedRecordKey(multiple) {
        if (arguments.length < 1 || this.selectedItem.length < 2) {
            if (!this.keyFieldName || !this.getSelectedRecord()) {
                return false;
            }
            return this.getSelectedRecord()[this.keyFieldName];
        }
        if (!this.keyFieldName || !this.getSelectedRecords()) {
            return false;
        }
        return this.getSelectedRecords().map((row) => row.record[this.keyFieldName]).join(',');
    }

    /**
     * Есть ли запись с этим ключом.
     *
     * @param {*} key
     * @returns {boolean}
     */
    dataKeyExists(key) {
        if (!this.data || !this.keyFieldName) {
            return false;
        }
        return this.data.some((item) => item[this.keyFieldName] == key);
    }

    clear() {
        this.deselectItem();
        this.tbody.replaceChildren();
    }

    /**
     * Щелчок по заголовку сортируемой колонки: порядок по кругу «нет → по возрастанию → по убыванию».
     *
     * @param {Object} event
     */
    onChangeSort(event) {
        const sortDirectionOrder = ['', 'asc', 'desc'],
            next = (current) => {
                const index = sortDirectionOrder.indexOf(current || '');
                return (index != -1 && index + 1 < sortDirectionOrder.length) ? sortDirectionOrder[index + 1] : sortDirectionOrder[0];
            };
        const header = event.target,
            sortFieldName = header.getAttribute('name'),
            sortDirection = header.getAttribute('class');

        //проверяем есть ли колонка сортировки в списке колонок
        if (this.metadata[sortFieldName] && this.metadata[sortFieldName].sort == 1) {
            this.sort.field = sortFieldName;
            this.sort.order = next(sortDirection);
            header.className = this.sort.order;
            this.emit('sortChange');
        }
    }

    /**
     * Строка без лишних пробелов (clean MooTools).
     *
     * @param {string} text
     * @returns {string}
     */
    static clean(text) {
        return String(text).replace(/\s+/g, ' ').trim();
    }

    /**
     * Стиль элемента: заданный в атрибуте style, иначе вычисленный (getStyle MooTools).
     *
     * @param {Element} element
     * @param {string} property
     * @returns {string}
     */
    static style(element, property) {
        return element.style[property] || getComputedStyle(element)[property];
    }

    /**
     * Ширина с полями и рамками целыми пикселями (getComputedSize MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static totalWidth(element) {
        const px = (property) => parseInt(Grid.style(element, property), 10) || 0,
            width = Grid.style(element, 'width');
        return ((width === 'auto') ? element.offsetWidth : (parseInt(width, 10) || 0))
            + px('paddingLeft') + px('paddingRight') + px('borderLeftWidth') + px('borderRightWidth');
    }

    /**
     * Высота с полями и рамками целыми пикселями (getComputedSize MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static totalHeight(element) {
        const px = (property) => parseInt(Grid.style(element, property), 10) || 0,
            height = Grid.style(element, 'height');
        return ((height === 'auto') ? element.offsetHeight : (parseInt(height, 10) || 0))
            + px('paddingTop') + px('paddingBottom') + px('borderTopWidth') + px('borderBottomWidth');
    }

    /**
     * Верх элемента от начала документа (getPosition MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static pageY(element) {
        const html = document.documentElement;
        return parseInt(element.getBoundingClientRect().top, 10) + (window.pageYOffset || html.scrollTop) - html.clientTop;
    }

    /**
     * Ширина полосы прокрутки: у верхнего окна, если оно её уже измерило, иначе — измеряется здесь, один раз.
     *
     * @returns {number}
     */
    static scrollBarWidth() {
        if (typeof window.ScrollBarWidth !== 'number') {
            let width = null;
            try {
                width = window.top.ScrollBarWidth;
            } catch (e) {
            }
            if (!width || typeof width !== 'number') {
                const outer = document.createElement('div'),
                    inner = document.createElement('div');
                outer.style.cssText = 'height: 1px; overflow: scroll; visibility: hidden';
                inner.style.height = '2px';
                outer.appendChild(inner);
                document.body.appendChild(outer);
                width = outer.offsetWidth - inner.offsetWidth;
                outer.remove();
            }
            window.ScrollBarWidth = width;
        }
        return window.ScrollBarWidth;
    }
};

/**
 * Грид с панелью, листалкой, фильтром и вкладками языков: загрузка страниц записей, действия кнопок панели, окна
 * правки (ответ окна — processAfterCloseAction).
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id).
 */
var GridManager = class GridManager {
    constructor(element) {
        /**
         * Id of the record that is moved (state /move/).
         * @type {number|string}
         */
        this.mvElementId = null;
        /**
         * Language ID.
         * @type {number}
         */
        this.langId = 0;
        this.toolbar = null;
        this.initialized = false;
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        this.element.GridManager = this;

        // документ родительского окна — без методов MooTools: её может не быть там (страница сайта у администратора)
        if (window.parent.document.querySelector('form.e-grid-form')) {
            this.element.classList.add('inside-form');
        }

        this.delConfirmCounter = 0;
        this.filter = new Filters(this);
        this.pageList = new PageList({onPageSelect: (pageNum) => this.loadPage(pageNum)});
        this.grid = this.createGrid(this.element.querySelector('.grid'), {
            onSelect: (item) => this.onSelect(item),
            onSortChange: () => this.onSortChange(),
            onDoubleClick: () => this.onDoubleClick()
        });
        this.tabPane = new TabPane(this.element, {onTabChange: (data) => this.onTabChange(data)});

        const toolbarContainer = this.tabPane.element.querySelector('.e-pane-b-toolbar');
        if (toolbarContainer) {
            toolbarContainer.appendChild(this.pageList.element);
            this.tabPane.element.classList.remove('e-pane-has-b-toolbar1');
            this.tabPane.element.classList.add('e-pane-has-b-toolbar2');
        } else {
            this.tabPane.element.appendChild(this.pageList.element);
        }

        this.overlay = new Overlay(this.element);
        this.singlePath = this.element.getAttribute('single_template');

        // инициализация id записи, которую будем двигать в стейте /move/
        const moveFromId = this.element.getAttribute('move_from_id');
        if (moveFromId) {
            this.setMvElementId(moveFromId);
        }

        this.reload();
    }

    /**
     * Таблица грида; наследник может подставить свою (файловый репозиторий).
     *
     * @param {Element} element .grid
     * @param {Object} options обработчики
     * @returns {Grid}
     */
    createGrid(element, options) {
        return new Grid(element, options);
    }

    setMvElementId(id) {
        this.mvElementId = id;
    }

    getMvElementId() {
        return this.mvElementId;
    }

    clearMvElementId() {
        this.mvElementId = null;
    }

    /**
     * Панель — над гридом (в .e-pane-t-toolbar), кнопки выключены до загрузки записей.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        this.toolbar = toolbar;
        const toolbarContainer = this.tabPane.element.querySelector('.e-pane-t-toolbar');
        (toolbarContainer || this.tabPane.element).prepend(this.toolbar.element);
        this.toolbar.disableControls();
        toolbar.bindTo(this);
    }

    /**
     * Другая вкладка языка: фильтр сбрасывается, записи — на её языке.
     *
     * @param {Object} data {lang}
     */
    onTabChange(data) {
        this.langId = data.lang;
        // Загружаем первую страницу только если панель инструментов уже прикреплена.
        if (this.filter.element) {
            this.filter.remove();
        }
        this.reload();
    }

    onSelect() {
    }

    /**
     * Двойной щелчок: правка, если можно, иначе первое действие панели.
     */
    onDoubleClick() {
        let c;
        if ((c = this.toolbar.getControlById('edit')) && !c.disabled()) {
            this.edit();
        } else if (this.toolbar.controls.length) {
            const action = this.toolbar.controls[0].properties.action;
            if (this[action] && !this.toolbar.controls[0].disabled()) {
                this[action]();
            }
        }
    }

    onSortChange() {
        this.loadPage(1);
    }

    reload() {
        this.loadPage(1);
    }

    /**
     * Загрузить страницу записей: листалка и кнопки выключены, грид затемнён и пуст до ответа.
     *
     * @param {number} pageNum
     */
    loadPage(pageNum) {
        this.pageList.disable();
        // todo: The toolbar is attached later as this function calls.
        if (this.toolbar) {
            this.toolbar.disableControls();
        }
        this.overlay.show();
        this.grid.clear();

        // запрос — после текущего обработчика, как прежде: в Firefox 26 панель иначе мерилась до перерисовки
        setTimeout(() => {
            Energine.request(
                this.buildRequestURL(pageNum),
                this.buildRequestPostBody(),
                (result) => this.processServerResponse(result),
                null,
                (responseText) => this.processServerError(responseText)
            );
        }, 0);
    }

    /**
     * Адрес страницы записей (с сортировкой, если она выбрана).
     *
     * @param {number|string} pageNum
     * @returns {string}
     */
    buildRequestURL(pageNum) {
        if (this.grid.sort.order) {
            return this.singlePath + 'get-data/' + this.grid.sort.field + '-' + this.grid.sort.order + '/page-' + pageNum;
        }
        return this.singlePath + 'get-data/page-' + pageNum;
    }

    /**
     * Тело запроса: язык вкладки и фильтр.
     *
     * @returns {string}
     */
    buildRequestPostBody() {
        let postBody = '';
        if (this.langId) {
            postBody += 'languageID=' + this.langId + '&';
        }
        if (this.filter) {
            postBody += this.filter.getValue();
        }
        return postBody;
    }

    /**
     * Ответ со страницей записей: метаданные (один раз), записи, листалка, кнопки; грид строится заново.
     *
     * @param {Object} result
     */
    processServerResponse(result) {
        let control = false;
        if (this.toolbar) {
            control = this.toolbar.getControlById('add');
        }
        if (!this.initialized) {
            this.grid.setMetadata(result.meta);
            this.initialized = true;
        }
        this.grid.setData(result.data || []);
        if (result.pager) {
            this.pageList.build(result.pager.count, result.pager.current);
        }
        if (!this.grid.isEmpty()) {
            if (this.toolbar) {
                this.toolbar.enableControls();
            }
            this.pageList.enable();
        }
        if (control) {
            control.enable();
        }
        this.grid.build();
        this.overlay.hide();
    }

    /**
     * Ошибка сервера: текст — администратору, затемнение снимается.
     *
     * @param {string} responseText
     */
    processServerError(responseText) {
        alert(responseText);
        this.overlay.hide();
    }

    /**
     * Ответ окна правки: действие, названное в ответе (afterClose), иначе — та же страница заново.
     *
     * @param {Object} returnValue
     */
    processAfterCloseAction(returnValue) {
        if (returnValue) {
            if (returnValue.afterClose && this[returnValue.afterClose]) {
                try {
                    this[returnValue.afterClose]();
                } catch (e) {
                    console.error(e);
                }
            } else {
                this.loadPage(this.pageList.currentPage);
            }
        }
    }

    // Actions:
    view() {
        ModalBox.open({url: this.singlePath + this.grid.getSelectedRecordKey()});
    }

    add() {
        ModalBox.open({
            url: this.singlePath + 'add/',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    edit(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        ModalBox.open({
            url: this.singlePath + id + '/edit',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    move(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.setMvElementId(id);
        ModalBox.open({
            url: this.singlePath + 'move/' + id,
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    moveFirst() {
        this.moveTo('first', this.grid.getSelectedRecordKey());
    }

    moveLast() {
        this.moveTo('last', this.grid.getSelectedRecordKey());
    }

    moveAbove(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.moveTo('above', this.getMvElementId(), id);
    }

    moveBelow(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.moveTo('below', this.getMvElementId(), id);
    }

    /**
     * Передвинуть запись; ответ окну — перезагрузить грид.
     *
     * @param {string} dir first, last, above, below
     * @param {number|string} fromId
     * @param {number|string} [toId]
     */
    moveTo(dir, fromId, toId) {
        toId = toId || '';
        this.overlay.show();
        Energine.request(this.singlePath + 'move/' + fromId + '/' + dir + '/' + toId + '/',
            null,
            () => {
                this.overlay.hide();
                ModalBox.setReturnValue(true); // reload
                this.reload();
            },
            () => this.overlay.hide(),
            (responseText) => {
                alert(responseText);
                this.overlay.hide();
            }
        );
    }

    editPrev() {
        let prevRow;
        if (this.grid.getSelectedItem() && (prevRow = this.grid.getSelectedItem().previousElementSibling)) {
            this.grid.selectItem(prevRow);
            this.edit();
        }
    }

    editNext() {
        let nextRow;
        if (this.grid.getSelectedItem() && (nextRow = this.grid.getSelectedItem().nextElementSibling)) {
            this.grid.selectItem(nextRow);
            this.edit();
        }
    }

    /**
     * Удалить выбранные записи (несколько — одним запросом «1,2,3/delete/»); после двух подтверждений подряд больше
     * не спрашивает, как прежде.
     */
    del() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete selected record?';
        if ((this.delConfirmCounter > 1) || confirm(MSG_CONFIRM_DELETE)) {
            this.delConfirmCounter++;
            this.overlay.show();
            let delstr = this.grid.getSelectedRecordKey(true);
            if (delstr === false) {
                this.overlay.hide();
                this.delConfirmCounter = 0;
                return;
            }
            delstr += '/delete/';
            Energine.request(this.singlePath + delstr, null,
                () => {
                    this.overlay.hide();
                    this.loadPage(this.pageList.currentPage);
                },
                () => this.overlay.hide(),
                (responseText) => {
                    alert(responseText);
                    this.overlay.hide();
                }
            );
        } else {
            this.delConfirmCounter = 0;
        }
    }

    use() {
        ModalBox.setReturnValue(this.grid.getSelectedRecord());
        ModalBox.close();
    }

    close() {
        ModalBox.close();
    }

    up() {
        const page = this.pageList.currentPage;
        Energine.request(this.singlePath + this.grid.getSelectedRecordKey() + '/up/',
            (this.filter) ? this.filter.getValue() : null, () => this.loadPage(page));
    }

    down() {
        const page = this.pageList.currentPage;
        Energine.request(this.singlePath + this.grid.getSelectedRecordKey() + '/down/',
            (this.filter) ? this.filter.getValue() : null, () => this.loadPage(page));
    }

    print() {
        window.open(this.element.getAttribute('single_template') + 'print/');
    }

    csv() {
        document.location.href = this.element.getAttribute('single_template') + 'csv/';
    }
};
