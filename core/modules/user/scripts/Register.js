/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Register]{@link Register}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/ValidForm
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('ValidForm');

/**
 * Регистрация: логин (e-mail) проверяется на занятость, когда посетитель уходит с поля; пока логин неверен или
 * занят, кнопка регистрации выключена.
 *
 * @constructor
 * @param {Element|string} element
 */
var Register = class Register extends ValidForm {
    constructor(element) {
        super(element);
        if (!this.form) {
            return;
        }
        this.registerButton = this.form.querySelector('button[name=register]');
        this.loginField = this.form.querySelector('#u_name');
        if (!this.loginField) {
            return;
        }
        this.loginField.addEventListener('blur', (event) => {
            if (!event.target.value) {
                return;
            }
            if (this.validator.validateElement(event.target)) {
                this.checkLogin(this.loginField.value);
            } else {
                this.disableRegistration();
            }
        });
    }

    disableRegistration() {
        if (this.registerButton) {
            this.registerButton.disabled = true;
        }
    }

    // логин уходит закодированным: «+» и «&» доходят до сервера как есть
    checkLogin(login) {
        Energine.send(this.singlePath + 'check/', 'login=' + encodeURIComponent(login)).then((r) => {
            if (r.status < 200 || r.status >= 300 || !r.json) {
                return;
            }
            if (!r.json.result) {
                this.validator.showError(this.loginField, r.json.message || '');
                this.disableRegistration();
            } else if (this.registerButton) {
                this.registerButton.disabled = false;
            }
        });
    }
};
