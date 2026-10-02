/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[GroupForm]{@link GroupForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form');

/**
 * Форма роли: переключатель в строке «Все разделы» отмечает весь свой столбец прав.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var GroupForm = class GroupForm extends Form {
    constructor(element) {
        super(element);
        this.element.querySelectorAll('.groupRadio').forEach((radio) => {
            radio.addEventListener('click', (event) => this.checkAllRadioInColumn(event));
        });
    }

    /**
     * Event handler. Check radio button.
     *
     * @param {Object} event Event.
     */
    checkAllRadioInColumn(event) {
        const radio = event.target;
        radio.closest('tbody')
            .querySelectorAll('td.' + radio.closest('td').getAttribute('class') + ' input[type=radio]')
            .forEach((input) => {
                input.checked = true;
            });
    }
};
