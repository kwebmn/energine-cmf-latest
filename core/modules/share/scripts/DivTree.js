/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivTree]{@link DivTree}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {DivManager} from 'DivManager';

/**
 * Окно выбора раздела (родитель раздела): раздел формы, из которой окно открыто, и его потомков выбрать нельзя.
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} el The main holder element.
 */
export class DivTree extends DivManager {
    constructor(el) {
        super(el);
        /**
         * Id раздела формы (поле #smap_id в одном из окон страницы) или 0.
         * @type {number}
         */
        this.currentID = 0;
        const srcWindows = [window.top];
        Array.from(window.top.document.getElementsByTagName('iframe')).forEach((iframe) => {
            if (iframe.contentWindow) {
                srcWindows.push(iframe.contentWindow);
            }
        });
        for (let i = 0; i < srcWindows.length; i++) {
            try {
                const result = srcWindows[i].document.getElementById('smap_id');
                if (result) {
                    this.currentID = parseInt(result.value, 10);
                    break;
                }
            } catch (e) {
            }
        }
    }

    // двойной щелчок в окне выбора ничего не делает: переход увёл бы страницу с несохранённой формой
    go() {
    }

    /**
     * «Выбрать» выключена у раздела формы и у его потомков.
     *
     * @param {TreeView.Node} node
     */
    onSelectNode(node) {
        super.onSelectNode(node);
        const btnSelect = this.toolbar.getControlById('select');
        if (this.currentID) {
            if (this.currentID == node.id) {
                if (btnSelect) {
                    btnSelect.disable();
                }
            } else {
                const parents = node.getParents();
                for (let i = 0; i < parents.length; i++) {
                    if (parents[i].id == this.currentID) {
                        if (btnSelect) {
                            btnSelect.disable();
                        }
                        break;
                    }
                }
            }
        } else if (btnSelect) {
            btnSelect.enable();
        }
    }
};
