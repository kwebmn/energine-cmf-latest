/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ValidForm]{@link ValidForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires Validator
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Validator');

/**
 * Форма сайта, которая проверяется перед отправкой.
 *
 * @constructor
 * @param {Element|string} element Форма или элемент внутри неё (id).
 */
var ValidForm = class ValidForm {
    constructor(element) {
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        if (!this.element) {
            return;
        }
        this.form = (this.element.tagName === 'FORM') ? this.element : this.element.closest('form');
        if (!this.form) {
            return;
        }
        this.singlePath = this.element.getAttribute('single_template');
        this.form.classList.add('form');
        this.form.addEventListener('submit', (event) => this.validateForm(event));
        this.validator = new Validator(this.form);
    }

    validateForm(event) {
        if (!this.validator.validate()) {
            event.preventDefault();
            return false;
        }
        return true;
    }
};
