/**
 * @file Contain the description of the next objects:
 * <ul>
 *     <li>[Energine]{@link Energine}</li>
 *     <li>[ScriptLoader]{@link ScriptLoader}</li>
 *     <li>[ScrollBarWidth]{@link ScrollBarWidth}</li>
 * </ul>
 *
 * @requires GridManager
 *
 * @author Pavel Dubenko
 * @author Valerii Zinchenko
 *
 * @version 1.1.1
 */

/**
 * Загружает указанные скрипты из директории scripts.
 */
/**
 * Array.from у MooTools 1.5 не понимает итерируемые объекты — Set, Map, итераторы заворачивает в массив
 * из одного элемента — и не принимает функцию-отображение. Современные библиотеки (Jodit) рассчитывают
 * на стандартное поведение: для них оно такое, для остальных вызовов (код на MooTools) — прежнее.
 */
(function () {
    var mooFrom = Array.from;
    Array.from = function (item, mapFn, thisArg) {
        var result, i, it, step;
        if (item != null && typeof item !== 'string' && typeof item.length !== 'number'
            && typeof item[Symbol.iterator] === 'function') {
            result = [];
            for (it = item[Symbol.iterator](), step = it.next(); !step.done; step = it.next()) {
                result.push(step.value);
            }
        } else if (typeof mapFn === 'function' && item != null && typeof item !== 'function'
            && typeof item.length === 'number') {
            result = [];
            for (i = 0; i < item.length; i++) {
                result.push(item[i]);
            }
        } else {
            result = mooFrom(item);
        }
        return (typeof mapFn === 'function') ? result.map(mapFn, thisArg) : result;
    };
})();

var ScriptLoader = {
    load: function () {
    }
};

/**
 * @namespace
 */
var Energine = /** @lends Energine */{
    /**
     * Debug flag.
     * @type {boolean}
     */
    debug: false,

    //todo: Append to all URLs ending 'URL'
    //---------
    /**
     * Base URL.
     * @type {string}
     */
    base: '',

    /**
     * Static URL.
     * @type {string}
     */
    'static': '',

    /**
     * Resizer URL.
     * @type {string}
     */
    resizer: '',

    /**
     * Media URL.
     * @type {string}
     */
    media: '',

    /**
     * Root URL.
     * @type {string}
     */
    root: '',
    //---------

    /**
     * Language ID.
     * @type {string}
     */
    lang: '',

    /**
     * Translations.
     * @type {Object}
     *
     * @property {Function} [get] Get the translation.
     * @param {string} get.constant Translation ID.
     * @property {Function} [set] Set the translation.
     * @param {string} set.constant Translation ID.
     * @param {Object} set.translation Translations.
     * @property {Function} [extend] Extend the translation.
     * @param {Object} obj New translation.
     */
    translations: {
        'get': function (constant) {
            return (Energine.translations[constant] || null);
        },
        'set': function (constant, translation) {
            Energine.translations[constant] = translation;
        },
        'extend': function (obj) {
            Object.append(Energine.translations, obj);
        }
    },

    /**
     * Force ths using of JSON.
     * @type {boolean}
     */
    forceJSON: false,

    /**
     * Support content editing.
     * @type {boolean}
     */
    supportContentEdit: true,

    /**
     * Send the request.
     *
     * @function
     * @static
     * @param {string} uri URI
     * @param {string} data Request.
     * @param {function} onSuccess Callback function that will be called by successful response.
     * @param {function} [onUserError] Callback function that will be called by user error.
     * @param {function} [onServerError] Callback function that will be called by server error.
     * @param {string} [method = 'post'] Request method: 'get', 'post'.
     */
    request: function (uri, data, onSuccess, onUserError, onServerError, method) {
        onServerError = onServerError || function (responseText) {
        };
        method = method || 'post';

        // ошибки из ответа сервера: текст для администратора
        var showErrors = function (response) {
            var msg = (typeof response.title != 'undefined')
                ? response.title
                : 'Произошла ошибка:\n';
            (response.errors || []).each(function (error) {
                if (typeof error.field != 'undefined') {
                    msg += error.field + " :\t";
                }
                if (typeof error.message != 'undefined') {
                    msg += error.message + "\n";
                } else {
                    msg += error + "\n";
                }
            });

            alert(msg);

            if (onUserError) {
                onUserError(response);
            }
        };

        new Request.JSON({
            'url': uri + ((Energine.forceJSON) ? '?json' : ''),
            'method': method,
            'data': data,
            // 'noCache': true,
            'evalResponse': false,
            'onComplete': function (response, responseText) {
                // ответ с кодом ошибки разбирает onFailure
                if (this.status >= 400) {
                    return;
                }
                if (!response) {
                    onServerError(responseText);
                    return;
                }

                if (response.result) {
                    onSuccess(response);
                } else {
                    showErrors(response);
                }
            },
            'onFailure': function (xhr) {
                // отказ с объяснением в JSON (например, устаревшая форма — код 422) показывается как ошибка формы
                var response = null;
                try {
                    response = JSON.parse(xhr.responseText);
                } catch (e) {
                }
                if (response && response.errors) {
                    showErrors(response);
                } else {
                    onServerError(xhr.responseText);
                    console.error(arguments);
                }
            }
        }).send();
    },

    /**
     * Create the DatePicker object without time selecting.
     *
     * @function
     * @static
     * @param {Element} datePickerObj Element for DatePicker.
     * @param {boolean} [nullable] Defines whether the an empty field for the date is allowed.
     * @returns {DatePicker}
     */
    createDatePicker: function (datePickerObj, nullable) {
        var props = {
            format: '%Y-%m-%d',
            allowEmpty: nullable,
            useFadeInOut: false
        };
        return Energine._createDatePickerObject($(datePickerObj), props);
    },

    /**
     * Create the DatePicker object with time selecting.
     *
     * @function
     * @static
     * @param {Element} datePickerObj Element for DatePicker.
     * @param {boolean} [nullable] Defines whether the an empty field for the date is allowed.
     * @returns {DatePicker}
     */
    createDateTimePicker: function (datePickerObj, nullable) {
        //DateTime
        var props = {
            timePicker: true,
            format: '%Y-%m-%d %H:%M',
            allowEmpty: nullable,
            useFadeInOut: false
        };

        return Energine._createDatePickerObject($(datePickerObj), props);
    },

    //fixme: bug
    /**
     * Create the DatePicker object.
     *
     * @function
     * @static
     * @param {Element} datePickerObj Element for DatePicker.
     * @param {Object} props Properties for the DatePicker.
     * @returns {DatePicker}
     */
    _createDatePickerObject: function (datePickerObj, props) {
        Asset.css('datepicker.css');

        var dp = new DatePicker(datePickerObj, Object.append({
                //debug:true
            },
            props
        ));

        try {
            if (!props.allowEmpty && dp.inputs[0].get('value') == '') {
                var currentDate = new Date(),
                    dateString = [
                        currentDate.getFullYear(),
                        currentDate.getMonth() + 1,
                        currentDate.getDate()
                    ].join('-');

                if (props.timePicker) {
                    dateString += ' ' + [currentDate.getHours(), currentDate.getMinutes()].join(':');
                }
                dp.inputs[0].set('value', dateString);
            }
        } catch (e) {
            if (Energine.debug && Browser.chrome && instanceOf(e, TypeError)) {
                console.warn(e.stack);
            } else {
                console.error(e);
            }
        }

        return dp;
    },

    /**
     * Resize an requested image. The attribute <tt>src</tt> of the img-tag will be build as follow:
     * <tt>Energine.resizer + r + 'w' + w + '-h' + h + '/' + src</tt>
     *
     * @function
     * @public
     * @param {HTMLImageElement} img Image, that will be resized.
     * @param {string} src Source of the original image.
     * @param {number} w Width of the new image.
     * @param {number} h Height of the new image.
     * @param {string} [r = ''] Special attribute. For example, if additional shrinking must be applied, in order to not cross requested width and height, <tt>r</tt> must be 'r'.
     *
     * @example
     * Energine.resizer = 'http://www.site.ua/resizer/';
     * Energine.resize($$('img')[0], 'images/img01.png', 100, 50);
     * $$('img')[0].getProperty('src') == 'http://www.site.ua/resizer/w100-h50/images/img01.png'
     */
    resize: function (img, src, w, h, r) {
        if (r === undefined)
            r = '';
        img.setAttribute('src', Energine.resizer + r + 'w' + w + '-h' + h + '/' + src);
    }
};

/**
 * Compatibility fix.
 * @type {Function}
 *
 * @deprecated Use Energine.request.
 */
Energine.request.request = Energine.request;

/**
 * Токен против подделки запросов (Csrf на сервере): каждый запрос MooTools несёт его в заголовке.
 * Energine.csrf задаёт страница (document.xslt).
 */
(function () {
    var send = Request.prototype.send;
    Request.prototype.send = function () {
        if (Energine.csrf) {
            this.setHeader('X-CSRF-Token', Energine.csrf);
        }
        return send.apply(this, arguments);
    };
})();

/**
 * Скрытое поле токена для форм, которые создаёт JS (формы из XSLT получают его в шаблоне).
 *
 * @returns {Element}
 */
Energine.csrfInput = function () {
    return new Element('input', {'type': 'hidden', 'name': 'csrf_token', 'value': Energine.csrf || ''});
};

/**
 * Local placeholder for an image of the given size: a grey SVG in a data: URL.
 * It replaced an external placeholder service (dead, and a third party saw every address).
 *
 * @param {number|string} width
 * @param {number|string} height
 * @returns {string}
 */
Energine.placeholder = function (width, height) {
    return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='" + width + "' height='" + height
        + "'%3E%3Crect width='100%25' height='100%25' fill='%23e5e5e5'/%3E%3C/svg%3E";
};

$(window).addEvent('domready', function () {
    if (Energine.debug)
        document.getElements('img').each(function (el) {
            el.onerror = function (e) {
                var image= $(e.target);
                var matches;
                if (
                    (matches = /\/resizer\/w(\d*)-h(\d*)/.exec(image.getProperty('src')))
                &&
                    (matches.length >2)
                ) {
                     image.setProperty('src', Energine.placeholder(matches[1], matches[2]));
                }
            };
        });
});

