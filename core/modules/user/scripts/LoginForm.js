/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[LoginForm]{@link LoginForm}</li>
 * </ul>
 *
 * @requires share/Energine
 * @requires share/Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.0.0
 */
ScriptLoader.load('ValidForm');

/**
 * Login form.
 *
 * @constructor
 * @param {Element} element Login form element.
 */
var LoginForm = new Class({
    Extends: ValidForm,
    // constructor
    initialize:function(element) {
        this.parent(element);
    }
});
