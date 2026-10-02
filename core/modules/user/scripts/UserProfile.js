/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[UserProfile]{@link UserProfile}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/Energine
 * @requires share/ValidForm
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('ValidForm');

/**
 * Профиль посетителя: новый пароль и повтор должны совпадать (текст ошибки — nrgn:message2 поля пароля).
 *
 * @constructor
 * @param {Element|string} element
 */
var UserProfile = class UserProfile extends ValidForm {
    validateForm(event) {
        const field = document.getElementById('u_password');
        const field2 = document.getElementById('u_password2');
        if (field && field2 && field.value !== field2.value) {
            this.validator.showError(field, field.getAttribute('nrgn:message2'));
            event.preventDefault();
            event.stopPropagation();
            return false;
        }
        return super.validateForm(event);
    }
};
