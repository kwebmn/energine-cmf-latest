/**
 * @file Журнал действий: «Очистить». Чистый JavaScript, без MooTools.
 *
 * @requires GridManager
 */

import {Energine} from 'Energine';
import {GridManager} from 'GridManager';

/**
 * Журнал действий.
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
export class ActionLogManager extends GridManager {
    /**
     * Очистить журнал — после подтверждения; грид — та же страница заново.
     */
    clear() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete selected record?';
        if (confirm(MSG_CONFIRM_DELETE)) {
            this.overlay.show();
            Energine.request(this.singlePath + '/clear/', null,
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
        }
    }
};
