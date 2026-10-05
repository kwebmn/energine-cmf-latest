/**
 * @file Окно истории текстового блока (грид версий): «Посмотреть» — версия целиком в окне поверх, «Вернуть» —
 * версия становится текущей, окно закрывается и отдаёт текст редактору на странице ({text}).
 *
 * @requires Energine
 * @requires GridManager
 * @requires ModalBox
 */

import {Energine} from 'Energine';
import {GridManager} from 'GridManager';
import {ModalBox} from 'ModalBox';

export class TextBlockHistory extends GridManager {
    showVersion() {
        const key = this.grid.getSelectedRecordKey();
        if (key) {
            ModalBox.open({url: this.singlePath + 'show/' + key + '/'});
        }
    }

    restore() {
        const key = this.grid.getSelectedRecordKey();
        if (!key) {
            return;
        }
        this.overlay.show();
        Energine.request(this.singlePath + 'restore/' + key + '/', '', (response) => {
            this.overlay.hide();
            ModalBox.setReturnValue({text: response.data});
            ModalBox.close();
        }, () => this.overlay.hide(), (responseText) => {
            this.overlay.hide();
            this.processServerError(responseText);
        });
    }
}
