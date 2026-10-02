/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[TabPane]{@link TabPane}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';

/**
 * Вкладки формы или грида: ul.e-tabs (li > a[href="#панель"]) и панели div#панель. Несколько вкладок могут вести на
 * одну панель (вкладки языков грида). Данные вкладки — JSON в span.data ({"lang": N}).
 *
 * @constructor
 * @param {Element|string} element
 * @param {Object} [options]
 * @param {function} [options.onTabChange] Вызывается при смене вкладки с её данными.
 */
export class TabPane {
    constructor(element, options) {
        Energine.loadCSS('tabpane.css');
        this.options = Object.assign({}, options);
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;

        const list = this.element.querySelector('ul.e-tabs');
        list.classList.add('clearfix');
        this.tabs = [...list.querySelectorAll('li')];
        this.currentTab = this.tabs[0];
        this.element.classList.add('e-items-count-' + this.tabs.length);

        this.tabs.forEach((tab) => {
            tab.setAttribute('unselectable', 'on');
            const anchor = tab.querySelector('a');
            const href = anchor.getAttribute('href');
            anchor.addEventListener('click', (event) => event.preventDefault());

            const data = tab.querySelector('span.data');
            tab.data = data ? JSON.parse(data.textContent) : {};
            tab.pane = this.element.querySelector('div#' + CSS.escape(href.slice(href.lastIndexOf('#') + 1)));
            tab.pane.classList.add('e-pane-item');
            tab.pane.style.display = 'none';
            tab.pane.tab = tab;

            tab.addEventListener('mouseover', () => {
                if (tab !== this.currentTab) {
                    tab.classList.add('highlighted');
                }
            });
            tab.addEventListener('mouseout', () => tab.classList.remove('highlighted'));
            tab.addEventListener('click', () => {
                if (tab !== this.currentTab && !tab.classList.contains('disabled')) {
                    this.show(tab);
                }
            });
        });

        this.selectTab(this.currentTab);
    }

    show(tab) {
        this.selectTab(tab);
        if (this.options.onTabChange) {
            this.options.onTabChange(this.currentTab.data);
        }
    }

    // вкладка становится текущей, её панель — видимой; фокус — в первое текстовое поле панели
    selectTab(tab) {
        if (!tab) {
            return;
        }
        this.currentTab.classList.remove('current');
        this.currentTab.pane.style.display = 'none';
        tab.classList.add('current');
        tab.pane.style.display = '';
        this.currentTab = tab;

        const firstInput = tab.pane.querySelector('div.field div.control input[type=text]')
            || tab.pane.querySelector('div.field div.control textarea');
        if (firstInput) {
            firstInput.focus();
        }
    }

    getTabs() {
        return this.tabs;
    }

    // вкладка, на панели которой лежит элемент (null — не на вкладке)
    whereIs(element) {
        for (let el = element.parentElement; el; el = el.parentElement) {
            if (el.classList.contains('e-pane-item') && el.tab) {
                return el.tab;
            }
        }
        return null;
    }

    enableTab(tabIndex) {
        if (this.tabs[tabIndex]) {
            this.tabs[tabIndex].classList.remove('disabled');
        }
    }

    disableTab(tabIndex) {
        if (this.tabs[tabIndex]) {
            this.tabs[tabIndex].classList.add('disabled');
        }
    }
};
