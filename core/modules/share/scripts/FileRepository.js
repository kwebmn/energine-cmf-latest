/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FileRepository]{@link FileRepository}</li>
 *     <li>[FileRepository.Grid]{@link FileRepository.Grid}</li>
 *     <li>[PathList]{@link PathList}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires GridManager
 *
 * @author Pavel Dubenko
 */

import {Energine} from 'Energine';
import {Grid, GridManager} from 'GridManager';
import {ModalBox} from 'ModalBox';

/**
 * Cookie с папкой, открытой последней.
 * @type {string}
 */
const FILE_COOKIE_NAME = 'NRGNFRPID';

/**
 * Файловый репозиторий: двойной щелчок по папке открывает её, по файлу — выбор (в окне выбора) или правка; хлебные
 * крошки ведут в папки пути; папка запоминается в cookie.
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
export class FileRepository extends GridManager {
    constructor(element) {
        super(element);
        document.FileRepository = this;
        /**
         * Path (bread crumbs).
         * @type {PathList}
         */
        this.pathBreadCrumbs = new PathList(this.element.querySelector('#breadcrumbs'));
        document.querySelectorAll('.e-pane-toolbar.e-tabs.clearfix .current').forEach((tab) => {
            tab.style.padding = '0px';
            tab.style.width = '100%';
            tab.appendChild(this.element.querySelector('#breadcrumbs'));
        });
        /**
         * Current folder.
         * @type {number|string}
         */
        this.currentPID = '';
    }

    /**
     * Файловый грид вместо обычного.
     *
     * @param {Element} element
     * @param {Object} options
     * @returns {FileRepository.Grid}
     */
    createGrid(element, options) {
        return new FileRepository.Grid(element, options);
    }

    onDoubleClick() {
        this.open();
    }

    /**
     * Кнопки по типу выбранной строки и правам папки (upl_allows_*).
     */
    onSelect() {
        this.toolbar.enableControls();
        const r = this.grid.getSelectedRecord(),
            openBtn = this.toolbar.getControlById('open');
        switch (r.upl_internal_type) {
            case 'folder':
                if (openBtn) {
                    openBtn.enable();
                }
                break;
            case 'folderup':
                this.toolbar.disableControls();
                if (openBtn) {
                    openBtn.enable();
                }
                if (this.toolbar.getControlById('addDir')) {
                    this.toolbar.getControlById('addDir').enable();
                }
                if (this.toolbar.getControlById('add')) {
                    this.toolbar.getControlById('add').enable();
                }
                break;
            case 'repo':
                this.toolbar.disableControls();
                if (openBtn) {
                    openBtn.enable();
                }
                break;
            default:
                break;
        }

        const btn_map = {
            'addDir': 'upl_allows_create_dir',
            'add': 'upl_allows_upload_file',
            'edit': (r.upl_internal_type == 'folder') ? 'upl_allows_edit_dir' : 'upl_allows_edit_file',
            'delete': (r.upl_internal_type == 'folder') ? 'upl_allows_delete_dir' : 'upl_allows_delete_file'
        };
        for (const btn in btn_map) {
            const control = this.toolbar.getControlById(btn);
            if (r[btn_map[btn]] && control && !control.disabled()) {
                control.enable();
            } else if (control) {
                control.disable();
            }
        }
    }

    /**
     * Ответ со страницей папки: папка — в cookie на сутки, крошки пути, грид.
     *
     * @param {Object} result
     */
    processServerResponse(result) {
        // todo: It is better to set this width as fixed over CSS.
        this.grid.headOff.querySelector('th').style.width = '100px';
        if (!this.initialized) {
            this.grid.setMetadata(result.meta);
            this.initialized = true;
        }
        if (!result.data) {
            result.data = [];
        }
        if (this.currentPID) {
            Energine.writeCookie(FILE_COOKIE_NAME, this.currentPID, {path: Energine.sitePath(), days: 1});
        }
        this.grid.setData(result.data);
        if (result.pager) {
            this.pageList.build(result.pager.count, result.pager.current);
        }
        if (!this.grid.isEmpty()) {
            this.toolbar.enableControls();
            this.pageList.enable();
        }
        this.pathBreadCrumbs.load(result.breadcrumbs, (upl_id) => {
            this.currentPID = upl_id;
            if (this.filter) {
                this.filter.remove();
            }
            this.loadPage(1);
        });
        this.grid.build();
        this.overlay.hide();
    }

    /**
     * Открыть выбранное: хранилище и папку — их файлы; файл — выбор (если есть кнопка «Выбрать») или правка.
     */
    open() {
        const r = this.grid.getSelectedRecord();
        switch (r.upl_internal_type) {
            case 'repo':
            case 'folder':
                this.currentPID = r.upl_id;
                if (this.filter) {
                    this.filter.remove();
                }
                this.loadPage(1);
                break;
            case 'folderup':
                this.currentPID = r.upl_id;
                this.loadPage(1);
                break;
            default:
                if (this.toolbar.getControlById('open')) {
                    if (r['upl_path']) {
                        r['upl_path'] = r['upl_path'].split('?')[0];
                    }
                    ModalBox.setReturnValue(r);
                    ModalBox.close();
                } else {
                    this.edit();
                }
                break;
        }
    }

    add() {
        let pid = this.grid.getSelectedRecord().upl_pid;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'add/',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    addDir() {
        let pid = this.grid.getSelectedRecord().upl_pid;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'add-dir/',
            onClose: (response) => {
                if (response && response.result) {
                    this.currentPID = response.data;
                    this.processAfterCloseAction(response);
                }
            }
        });
    }

    moveToDir() {
        let pid = this.grid.getSelectedRecord().upl_id;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'moveToDir/',
            onClose: () => this.reload()
        });
    }

    copy() {
        let pid = this.grid.getSelectedRecord().upl_id;
        if (pid) {
            pid += '/';
        }
        Energine.request(this.singlePath + pid + 'copy/', '', () => document.FileRepository.reload());
    }

    /**
     * Загрузка zip-архива (кнопка-файл панели).
     *
     * @param {Object} data прочитанный файл
     */
    uploadZip(data) {
        Energine.request(this.singlePath + 'upload-zip', 'PID=' + this.grid.getSelectedRecord().upl_pid + '&data='
            + encodeURIComponent(data.result), (response) => console.log(response));
    }

    /**
     * Адрес страницы папки: текущей, иначе — запомненной в cookie.
     *
     * @param {number|string} pageNum
     * @returns {string}
     */
    buildRequestURL(pageNum) {
        let level = '';
        const cookiePID = Energine.readCookie(FILE_COOKIE_NAME);
        if (this.currentPID === 0) {
            level = '';
        } else if (this.currentPID) {
            level = this.currentPID + '/';
        } else if (cookiePID) {
            this.currentPID = cookiePID;
            level = this.currentPID + '/';
        }
        if (this.grid.sort.order) {
            return this.singlePath + level + 'get-data/' + this.grid.sort.field + '-' + this.grid.sort.order + '/page-' + pageNum + '/';
        }
        return this.singlePath + level + 'get-data/' + 'page-' + pageNum + '/';
    }

    buildRequestPostBody() {
        let postBody = '';
        if (this.filter) {
            postBody += this.filter.getValue();
        }
        return postBody;
    }
};

/**
 * Грид файлового репозитория: значки папок и хранилищ, превью картинок (наведение — увеличенная), свойства файла и его
 * размер, название — ссылкой на файл.
 *
 * @augments Grid
 *
 * @constructor
 * @param {Element} element
 * @param {Object} [options]
 */
FileRepository.Grid = class FileRepositoryGrid extends Grid {
    /**
     * Увеличенная картинка над превью: появляется по его центру и растёт до 298×224; уходит по щелчку или уходу мыши.
     *
     * @param {string} path путь картинки
     * @param {Element} tmplElement превью
     */
    popImage(path, tmplElement) {
        const popUpImg = document.createElement('img');
        popUpImg.setAttribute('src', Energine.resizer + 'w298-h224/' + path);
        popUpImg.setAttribute('width', 60);
        popUpImg.setAttribute('height', 45);
        Object.assign(popUpImg.style, {
            border: '1px solid gray',
            borderRadius: '10px',
            zIndex: 1,
            position: 'absolute',
            transition: 'width 250ms linear, height 250ms linear'
        });
        popUpImg.addEventListener('click', () => popUpImg.remove());
        popUpImg.addEventListener('mouseleave', () => popUpImg.remove());
        document.body.appendChild(popUpImg);

        const rect = tmplElement.getBoundingClientRect();
        popUpImg.style.left = Math.round(rect.left + window.pageXOffset + (rect.width - 60) / 2) + 'px';
        popUpImg.style.top = Math.round(rect.top + window.pageYOffset + (rect.height - 45) / 2) + 'px';
        // размер меняется после первой отрисовки — так рост виден
        requestAnimationFrame(() => requestAnimationFrame(() => {
            popUpImg.style.width = '298px';
            popUpImg.style.height = '224px';
        }));
    }

    // overridden
    iterateFields(fieldName, record, row) {
        // Пропускаем невидимые поля.
        if (!this.metadata[fieldName].visible || this.metadata[fieldName].type == 'hidden') {
            return;
        }
        let fieldValue = '';
        const cell = document.createElement('td');
        row.appendChild(cell);
        switch (fieldName) {
            case 'upl_path':
                this.thumbnail(cell, record, fieldName);
                break;
            case 'upl_publication_date':
                if (record[fieldName]) {
                    fieldValue = Grid.clean(record[fieldName]);
                }
                cell.textContent = fieldValue;
                break;
            case 'upl_properties': {
                const propsTable = document.createElement('tbody'),
                    table = document.createElement('table');
                cell.classList.add('properties');
                table.appendChild(propsTable);
                cell.appendChild(table);
                if (!/folder|repo/.test(record['upl_internal_type'])) {
                    if (record['upl_mime_type']) {
                        FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_mime_type'].title + ' :', record['upl_mime_type']);
                    }
                    if (record['upl_internal_type'] == 'image') {
                        if (record['upl_width']) {
                            FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_width'].title + ' :', record['upl_width']);
                        }
                        if (record['upl_height']) {
                            FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_height'].title + ' :', record['upl_height']);
                        }
                    }
                }
                break;
            }
            case 'upl_title':
                if (record[fieldName]) {
                    fieldValue = Grid.clean(record[fieldName]);
                }
                // название — текстом: его пишет редактор, в нём может оказаться разметка
                if (!/folder|repo/.test(record['upl_internal_type'])) {
                    const link = document.createElement('a');
                    link.target = '_blank';
                    link.href = Energine.media + record['upl_path'];
                    link.textContent = fieldValue;
                    cell.appendChild(link);
                } else {
                    cell.textContent = fieldValue;
                }
                break;
            default:
                break;
        }
    }

    /**
     * Значок строки: папка, хранилище, «наверх», файл; у картинки — превью 60×45 (наведение на 0,7 с — увеличенная,
     * ошибка загрузки — заглушка без увеличения) и размер файла в свойствах (запрос HEAD).
     *
     * @param {Element} cell
     * @param {Object} record
     * @param {string} fieldName
     */
    thumbnail(cell, record, fieldName) {
        cell.style.textAlign = 'center';
        cell.style.verticalAlign = 'middle';
        const image = document.createElement('img'),
            container = document.createElement('div');
        image.setAttribute('src', 'about:blank');
        container.className = 'thumb_container';
        cell.appendChild(container);
        let dimensions = {width: 40, height: 40};

        switch (record['upl_internal_type']) {
            case 'folder':
                dimensions = {width: 50, height: 50};
                image.setAttribute('src', 'images/icons/icon_folder.png');
                break;
            case 'repo':
                image.setAttribute('src', 'images/icons/icon_repository.gif');
                if (record['upl_path'] == 'uploads/public') {
                    image.setAttribute('src', 'images/icons/public.png');
                }
                if (record['upl_path'] == 'uploads/user_files') {
                    image.setAttribute('src', 'images/icons/user_files.png');
                }
                break;
            case 'folderup':
                dimensions = {width: 80, height: 78};
                image.setAttribute('src', 'images/icons/icon_folder_up2.png');
                break;
            case 'image': {
                dimensions = {width: 60, height: 45};
                let tmt;
                const target = (event) => (event.target.tagName === 'IMG') ? event.target : event.target.querySelector('img'),
                    enter = (event) => {
                        const el = target(event);
                        el.style.border = '1px solid gray';
                        tmt = setTimeout(() => this.popImage(record[fieldName], el), 700);
                    },
                    leave = (event) => {
                        target(event).style.border = '1px solid transparent';
                        if (tmt) {
                            clearTimeout(tmt);
                        }
                    };
                image.setAttribute('src', Energine.resizer + 'w60-h45/' + record[fieldName]);
                image.addEventListener('error', () => {
                    image.setAttribute('src', Energine.placeholder(60, 45));
                    container.removeEventListener('mouseenter', enter);
                    container.removeEventListener('mouseleave', leave);
                });
                image.style.borderRadius = '5px';
                image.style.border = '1px solid transparent';
                container.addEventListener('mouseenter', enter);
                container.addEventListener('mouseleave', leave);
                this.fileSize(cell, record[fieldName]);
                break;
            }
            default:
                dimensions = {width: 39, height: 48};
                image.setAttribute('src', 'images/icons/icon_undefined.gif');
                break;
        }
        image.setAttribute('width', dimensions.width);
        image.setAttribute('height', dimensions.height);
        container.appendChild(image);
    }

    /**
     * Размер файла (заголовок Content-Length ответа на HEAD) — строкой в таблицу свойств строки.
     *
     * @param {Element} cell ячейка строки файла
     * @param {string} path путь файла
     */
    fileSize(cell, path) {
        fetch(path, {method: 'HEAD', credentials: 'same-origin'}).then((response) => {
            const length = response.headers.get('Content-Length'),
                props = cell.parentNode && cell.parentNode.getElementsByClassName('properties');
            if (response.status != 200 || length === null || !props || !props.length) {
                return;
            }
            let size = Number(length), sizeAbbr = 'B';
            if (size > 1024) {
                size = size / 1024;
                sizeAbbr = 'KiB';
                if (size > 1024) {
                    size = size / 1024;
                    sizeAbbr = 'MiB';
                    if (size > 1024) {
                        size = size / 1024;
                        sizeAbbr = 'GiB';
                    }
                }
            }
            FileRepository.Grid.propertyRow(props[0].getElementsByTagName('tbody')[0],
                Energine.translations.get('TXT_FILE_SIZE') + ':', size.toPrecision(3) + ' ' + sizeAbbr);
        }).catch(() => {
        });
    }

    /**
     * Строка таблицы свойств: подпись и значение — текстом.
     *
     * @param {Element} tbody
     * @param {string} title
     * @param {*} value
     */
    static propertyRow(tbody, title, value) {
        const tr = document.createElement('tr');
        [title, value].forEach((text) => {
            const td = document.createElement('td');
            td.textContent = text;
            tr.appendChild(td);
        });
        tbody.appendChild(tr);
    }
};

/**
 * Хлебные крошки: папки пути — ссылками.
 *
 * @constructor
 * @param {Element|string} el
 */
class PathList {
    constructor(el) {
        this.element = (typeof el === 'string') ? document.getElementById(el) : el;
    }

    /**
     * Путь: {id: название}; щелчок по папке — loader(id).
     *
     * @param {Object} data
     * @param {function} loader
     */
    load(data, loader) {
        this.element.replaceChildren();
        Object.entries(data || {}).forEach(([id, title]) => {
            const link = document.createElement('a'),
                divider = document.createElement('span');
            link.href = '#';
            link.textContent = title;
            link.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                loader(id);
            });
            divider.textContent = ' / ';
            this.element.append(link, divider);
        });
    }
};
