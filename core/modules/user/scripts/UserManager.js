/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[UserManager]{@link UserManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/GridManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {GridManager} from 'GridManager';

/**
 * Пользователи: «Активировать».
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
export class UserManager extends GridManager {
    /**
     * Активировать выбранного пользователя; грид — та же страница заново.
     */
    activate() {
        const page = this.pageList.currentPage;
        Energine.request(
            this.singlePath + this.grid.getSelectedRecordKey() + '/activate/',
            null,
            () => this.loadPage(page)
        );
    }
};
