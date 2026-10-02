/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Overlay]{@link Overlay}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Затемнение («занято»): полупрозрачный слой поверх элемента, по умолчанию — поверх всей страницы верхнего окна.
 *
 * @constructor
 * @param {Element} [parentElement] Что затемняется; по умолчанию — body верхнего окна.
 * @param {Object} [options]
 * @param {number} [options.opacity = 0.5] Непрозрачность видимого затемнения.
 * @param {number} [options.duration = 500] Длительность появления и исчезновения, мс.
 * @param {boolean} [options.indicator = true] Знак загрузки (класс e-overlay-loading).
 */
export class Overlay {
    constructor(parentElement, options) {
        this.options = Object.assign({duration: 500, opacity: 0.5, indicator: true}, options);
        this.container = parentElement || window.top.document.body;
        this.element = document.createElement('div');
        this.element.className = 'e-overlay' + (this.options.indicator ? ' e-overlay-loading' : '');
        this.element.style.opacity = '0';
        this.element.style.transition = 'opacity ' + this.options.duration + 'ms ease-in-out';
        this.removal = null;
    }

    show() {
        clearTimeout(this.removal);
        this.removal = null;
        // у элемента одно затемнение: если оно уже есть, второе не добавляется
        if (![...this.container.children].some((child) => child.classList.contains('e-overlay'))) {
            this.container.appendChild(this.element);
        }
        // без расчёта начального состояния браузер не показал бы появление
        void this.element.offsetWidth;
        this.element.style.opacity = String(this.options.opacity);
    }

    // затемнение исчезает и уходит со страницы; новое show() до конца исчезновения его оставляет
    hide() {
        this.element.style.opacity = '0';
        clearTimeout(this.removal);
        this.removal = setTimeout(() => {
            this.removal = null;
            this.element.remove();
        }, this.options.duration);
    }
};
