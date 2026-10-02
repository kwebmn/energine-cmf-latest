/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ModalBox]{@link ModalBox}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires Overlay
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {Overlay} from 'Overlay';

/**
 * Окна админки: страница в iframe поверх текущей. Объект общий для вложенных окон: внутри окна работает объект
 * верхнего окна (window.top.ModalBox), и окна открываются друг над другом в одном документе. Щелчок по затемнению и
 * Esc окно не закрывают — клиент просил не закрывать окно случайно.
 *
 * @namespace
 */
export const ModalBox = window.top.ModalBox || /** @lends ModalBox */{
    /**
     * Открытые окна, последнее — верхнее.
     * @type {Element[]}
     */
    boxes: [],

    /**
     * @type {boolean}
     */
    initialized: false,

    // стили окон и общее затемнение (без знака загрузки)
    init: function () {
        Energine.loadCSS('modalbox.css');
        this.overlay = new Overlay(null, {indicator: false});
        this.initialized = true;
    },

    /**
     * Открыть окно.
     *
     * @param {Object} options
     * @param {string} [options.url] Адрес страницы окна.
     * @param {string} [options.post] Данные, которые уходят в окно формой (поле modalBoxData, с токеном).
     * @param {Element} [options.code] Элемент вместо страницы.
     * @param {function} [options.onClose] Вызывается при закрытии со значением из setReturnValue.
     * @param {*} [options.extraData] Данные для страницы окна (getExtraData).
     */
    open: function (options) {
        var box = document.createElement('div');
        box.className = 'e-modalbox';
        document.body.appendChild(box);
        box.options = Object.assign({url: null, onClose: function () {}, extraData: null, post: null}, options);

        if (box.options.url) {
            var name = 'modalBoxIframe' + this.boxes.length,
                src = box.options.url,
                form = null;
            if (box.options.post) {
                form = document.createElement('form');
                form.target = name;
                form.action = src;
                form.method = 'post';
                var data = document.createElement('input');
                data.type = 'hidden';
                data.name = 'modalBoxData';
                data.value = box.options.post;
                form.appendChild(data);
                form.appendChild(Energine.csrfInput());
                src = 'about:blank';
            }
            var iframe = document.createElement('iframe');
            iframe.name = name;
            iframe.src = src;
            iframe.frameBorder = '0';
            iframe.scrolling = 'no';
            iframe.className = 'e-modalbox-frame';
            box.iframe = iframe;
            box.appendChild(iframe);
            if (form) {
                box.appendChild(form);
                form.submit();
                form.remove();
            }
        } else if (box.options.code) {
            box.appendChild(box.options.code);
        }

        this.boxes.push(box);
        if (this.boxes.length === 1) {
            this.overlay.show();
        }
    },

    /**
     * @returns {Element|null} Верхнее окно.
     */
    getCurrent: function () {
        return this.boxes.length ? this.boxes[this.boxes.length - 1] : null;
    },

    getExtraData: function () {
        var box = this.getCurrent();
        return box ? box.options.extraData : null;
    },

    // значение, которое получит onClose верхнего окна
    setReturnValue: function (value) {
        var box = this.getCurrent();
        if (box) {
            box.returnValue = value;
        }
    },

    close: function () {
        if (!this.boxes.length) {
            return;
        }
        var box = this.boxes.pop();
        box.options.onClose(box.returnValue);
        // окно убирается после обработчика: он ещё может читать страницу окна
        setTimeout(function () {
            if (box.iframe) {
                box.iframe.src = 'about:blank';
                box.iframe.remove();
            }
            box.remove();
        }, 1);
        if (!this.boxes.length) {
            this.overlay.hide();
        }
    }
};

if (!ModalBox.initialized) {
    document.addEventListener('DOMContentLoaded', function () {
        ModalBox.init();
    });
}

// окна страницы ищут общую очередь окон в window.top.ModalBox
window.ModalBox = ModalBox;
