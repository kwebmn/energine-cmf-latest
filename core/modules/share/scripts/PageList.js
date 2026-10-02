/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageList]{@link PageList}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

/**
 * Листалка страниц грида: номера около текущей, первые и последние страницы, многоточия, стрелки.
 *
 * @constructor
 * @param {Object} [options]
 * @param {function} [options.onPageSelect] Вызывается с номером выбранной страницы.
 */
var PageList = class PageList {
    constructor(options) {
        Energine.loadCSS('pagelist.css');
        this.options = Object.assign({}, options);
        this.currentPage = 1;
        this.disabled = false;
        this.element = document.createElement('ul');
        this.element.className = 'e-pane-toolbar e-pagelist';
        this.element.setAttribute('unselectable', 'on');
    }

    getElement() {
        return this.element;
    }

    // пока грид грузится, листалка полупрозрачна и не реагирует
    disable() {
        this.disabled = true;
        this.element.style.opacity = '0.25';
    }

    enable() {
        this.disabled = false;
        this.element.style.opacity = '1';
    }

    build(numPages, currentPage) {
        // номер за последней страницей (сервер его не ограничивает — так бывает после удаления единственной записи
        // последней страницы) — листалка показывает последнюю
        currentPage = Math.min(currentPage, Math.max(numPages, 1));
        this.currentPage = currentPage;
        this.element.replaceChildren();
        if (numPages <= 1) {
            this.element.style.display = 'none';
            return;
        }
        this.element.style.display = '';

        // сколько номеров видно с каждой стороны от текущего
        const VISIBLE_PAGES_COUNT = 2;
        const startPage = (currentPage > VISIBLE_PAGES_COUNT) ? currentPage - VISIBLE_PAGES_COUNT : 1;
        const endPage = Math.min(currentPage + VISIBLE_PAGES_COUNT, numPages);
        const add = (title, index) => this.element.appendChild(this.createPageLink(title, index));

        if (startPage > 1) {
            add(1, 1);
            if (startPage > 2) {
                add(2, 2);
                if (startPage > 3) {
                    add('...');
                }
            }
        }
        for (let i = startPage; i <= endPage; i++) {
            add(i, i);
        }
        if (endPage < numPages) {
            if (endPage < numPages - 1) {
                if (endPage < numPages - 2) {
                    add('...');
                }
                add(numPages - 1, numPages - 1);
            }
            add(numPages, numPages);
        }
        this.element.querySelector('li[index="' + this.currentPage + '"]').classList.add('current');

        if (currentPage != 1) {
            this.element.prepend(this.createPageLink('previous', currentPage - 1, 'images/prev_page.gif'));
        }
        if (currentPage != numPages) {
            this.element.appendChild(this.createPageLink('next', currentPage + 1, 'images/next_page.gif'));
        }
    }

    selectPage(listItem) {
        const current = this.element.querySelector('li.current');
        if (current) {
            current.classList.remove('current');
        }
        this.currentPage = parseInt(listItem.getAttribute('index'), 10);
        if (this.options.onPageSelect) {
            this.options.onPageSelect(this.currentPage);
        }
    }

    // пункт листалки: номер, многоточие (index 0 — без действий) или стрелка-картинка
    createPageLink(title, index, image) {
        index = index || 0;
        const listItem = document.createElement('li');
        if (image) {
            const img = document.createElement('img');
            img.src = image;
            img.setAttribute('border', '0');
            img.setAttribute('align', 'absmiddle');
            img.alt = title;
            img.title = title;
            img.style.width = '6px';
            img.style.height = '11px';
            listItem.appendChild(img);
        } else {
            listItem.appendChild(document.createTextNode(title));
        }
        listItem.setAttribute('index', index);

        if (index) {
            listItem.addEventListener('mouseover', () => {
                if (!this.disabled) {
                    listItem.classList.add('highlighted');
                }
            });
            listItem.addEventListener('mouseout', () => listItem.classList.remove('highlighted'));
            listItem.addEventListener('click', () => {
                if (!this.disabled && listItem.getAttribute('index') != String(this.currentPage)) {
                    this.selectPage(listItem);
                }
            });
        }
        return listItem;
    }
};
