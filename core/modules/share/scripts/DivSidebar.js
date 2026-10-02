/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivSidebar]{@link DivSidebar}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {DivManager} from 'DivManager';
import {TreeView} from 'TreeView';

/**
 * Дерево разделов в боковой панели администратора: без вкладок и подгонки под окно, панель сверху, у html — класс
 * e-divtree-panel.
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
export class DivSidebar extends DivManager {
    /**
     * Своя настройка вместо настройки DivManager.
     *
     * @param {Element|string} element
     */
    setup(element) {
        Energine.loadCSS('div.css');
        this.element = DivManager.element(element);
        const list = DivManager.treeList();
        this.langId = this.element.getAttribute('lang_id');
        this.tree = new TreeView(list, {dblClick: () => this.go()});
        this.singlePath = this.element.getAttribute('single_template');
        document.documentElement.classList.add('e-divtree-panel');
        this.loadTree();
    }

    /**
     * Панель — сверху, включены «Добавить» и «Выбрать».
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        if ((this.toolbar = toolbar)) {
            this.element.prepend(this.toolbar.element);
            this.toolbar.disableControls();
            const addBtn = this.toolbar.getControlById('add'),
                selectBtn = this.toolbar.getControlById('select');
            if (addBtn) {
                addBtn.enable();
            }
            if (selectBtn) {
                selectBtn.enable();
            }
            toolbar.bindTo(this);
        }
    }
};
