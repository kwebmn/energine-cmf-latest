/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ModalBox]{@link ModalBox}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 *
 * @author Pavel Dubenko
 *
 * @version 1.2.0
 */

import {Energine} from 'Energine';

/** @typedef {{url?: string, onClose?: Function, extraData?: *, post?: string, code?: Element}} ModalBoxOptions */
/**
 * Окно: элемент <dialog> с настройками, iframe и результатом. Результат — в своём свойстве result: у <dialog> есть
 * строковое returnValue, объект в нём стал бы строкой «[object Object]».
 * @typedef {HTMLDialogElement & {options?: ModalBoxOptions, iframe?: HTMLIFrameElement, result?: *, closing?: boolean}} ModalBoxElement
 */

/**
 * Окна админки: страница в iframe поверх текущей, в элементе <dialog> (надёжность, этап 5). Окно открывается
 * showModal(): оно в верхнем слое браузера (без z-index), страница под ним недоступна мыши и клавиатуре, затемнение —
 * ::backdrop (у вложенных окон прозрачное: затемнение одно, admin.tailwind.css). Объект общий для вложенных окон:
 * внутри окна работает объект верхнего окна (window.top.ModalBox), и окна открываются друг над другом в одном
 * документе. Щелчок по затемнению и Esc окно не закрывают — клиент просил не закрывать окно случайно.
 *
 * @namespace
 */
export const ModalBox = window.top.ModalBox || /** @lends ModalBox */{
    /**
     * Открытые окна, последнее — верхнее.
     * @type {ModalBoxElement[]}
     */
    boxes: [],

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
        var box = /** @type {ModalBoxElement} */ (document.createElement('dialog'));
        // по высоте 90% экрана, по ширине — от 95% на узком экране до 64rem на широком; по центру — сам <dialog>
        box.className = 'e-modalbox a:m-auto a:h-[90%] a:max-h-none a:w-[95%] a:max-w-none a:overflow-hidden a:rounded-lg'
            + ' a:border-0 a:bg-white a:p-0 a:shadow-2xl a:min-[900px]:w-[90%] a:min-[1200px]:w-[80%] a:min-[1400px]:w-[64rem]';
        box.options = Object.assign({url: null, onClose: function () {}, extraData: null, post: null}, options);
        // Esc окно не закрывает: клавиша гасится, отмена (cancel) — тоже; если браузер всё же закрыл окно (повторный Esc
        // без действия пользователя отмену не спрашивает), оно открывается снова — закрывает его только close()
        box.addEventListener('keydown', function (event) {
            if (event.key === 'Escape') {
                event.preventDefault();
            }
        });
        box.addEventListener('cancel', function (event) {
            event.preventDefault();
        });
        box.addEventListener('close', function () {
            if (!box.closing && box.isConnected) {
                box.showModal();
            }
        });
        document.body.appendChild(box);

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
            iframe.className = 'e-modalbox-frame a:block a:size-full a:border-0';
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
        box.showModal();
    },

    /**
     * @returns {ModalBoxElement|null} Верхнее окно.
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
            box.result = value;
        }
    },

    close: function () {
        if (!this.boxes.length) {
            return;
        }
        var box = this.boxes.pop();
        box.options.onClose(box.result);
        // окно убирается после обработчика: он ещё может читать страницу окна; фокус браузер вернёт сам
        setTimeout(function () {
            box.closing = true;
            if (box.iframe) {
                box.iframe.src = 'about:blank';
                box.iframe.remove();
            }
            box.close();
            box.remove();
        }, 1);
    }
};

// окна страницы ищут общую очередь окон в window.top.ModalBox
window.ModalBox = ModalBox;
