/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Validator]{@link Validator}</li>
 * </ul>
 * Чистый JavaScript, без MooTools: проверяет и формы сайта, и формы админки.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Validator: правило поля — атрибуты nrgn:pattern (выражение /…/флаги) и nrgn:message (текст ошибки).
 *
 * @constructor
 * @param {Element|string} form Form element.
 * @param {TabPane} [tabPane] Вкладки формы админки: поле с ошибкой на закрытой вкладке её открывает.
 */
export class Validator {
    constructor(form, tabPane) {
        this.form = (typeof form === 'string') ? document.getElementById(form) : form;
        this.tabPane = tabPane || null;
        this.prepareFloatFields();
    }

    // поля дробных чисел (класс float): запятая заменяется точкой
    prepareFloatFields() {
        this.form.querySelectorAll('.float').forEach((element) => {
            element.removeEventListener('change', Validator.commaToPoint);
            element.addEventListener('change', Validator.commaToPoint);
        });
    }

    static commaToPoint(event) {
        event.target.value = event.target.value.replace(/,/, '.');
    }

    removeError(field) {
        if (!field.classList.contains('invalid')) {
            return;
        }
        field.classList.remove('invalid');
        const box = field.closest('.field');
        const error = box && box.querySelector('div.error');
        if (error) {
            error.remove();
        }
    }

    clearErrors() {
        this.form.querySelectorAll('.invalid').forEach((field) => this.removeError(field));
    }

    // текст ошибки — текстом, не разметкой: в переводах, которые сюда попадают, разметки нет
    showError(field, message) {
        this.removeError(field);
        field.classList.add('invalid');
        const error = document.createElement('div');
        error.className = 'error';
        error.textContent = (message === null || message === undefined) ? '' : String(message);
        error.addEventListener('click', () => this.removeError(field));
        field.parentNode.after(error);
    }

    scrollToElement(field) {
        field.scrollIntoView({behavior: 'smooth', block: 'center'});
        try {
            field.focus({preventScroll: true});
        } catch (e) {
            console.warn(e);
        }
    }

    validateElement(field) {
        const pattern = field.getAttribute('nrgn:pattern');
        const message = field.getAttribute('nrgn:message');
        if (!pattern || !message || field.disabled || field.classList.contains('novalidation')) {
            return true;
        }
        const parts = pattern.split('/');
        if (new RegExp(parts[1], parts[2]).test(field.value)) {
            this.removeError(field);
            return true;
        }
        this.showError(field, message);
        // после первой ошибки поле проверяется при уходе с него, а ввод убирает ошибку — и с клавиатуры, и вставкой
        // или автозаполнением (они клавиш не нажимают, и без этого кнопка уезжала бы из-под щелчка)
        if (!field.getAttribute('check')) {
            field.addEventListener('blur', () => this.validateElement(field));
            field.addEventListener('keydown', () => this.removeError(field));
            field.addEventListener('input', () => this.removeError(field));
            field.setAttribute('check', 'check');
        }
        return false;
    }

    validate() {
        let first = null;
        for (const field of [...this.form.elements]) {
            if (!this.validateElement(field) && !first) {
                first = field;
            }
        }
        if (first) {
            if (this.tabPane) {
                this.tabPane.show(this.tabPane.whereIs(first));
            }
            this.scrollToElement(first);
        }
        return !first;
    }
};
