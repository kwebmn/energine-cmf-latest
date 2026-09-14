/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FormBehavior]{@link FormBehavior}</li>
 * </ul>
 *
 * @requires share/ValidForm
 * @requires share/datepicker
 *
 * @author Pavel Dubenko
 *
 * @version 1.0.0
 */

ScriptLoader.load('ValidForm', 'datepicker');

/**
 * FormBehavior
 *
 * @augments ValidForm
 *
 * @constructor
 * @param {Element|string} element The main element.
 */
var FormBehavior = new Class(/** @lends FormBehavior# */{
    Extends: ValidForm,

    // constructor
    initialize: function(element){
        this.parent(element);
    }
});
