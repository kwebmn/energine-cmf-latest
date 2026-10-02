/**
 * @file Contain the description of the next objects:
 * <ul>
 *     <li>[Energine]{@link Energine}</li>
 *     <li>[ScriptLoader]{@link ScriptLoader}</li>
 * </ul>
 * Чистый JavaScript, без MooTools: файл нужен и публичным страницам, где MooTools нет.
 *
 * @author Pavel Dubenko
 * @author Valerii Zinchenko
 *
 * @version 1.2.0
 */

/**
 * Объявление зависимостей скрипта: setup scriptMap читает первый вызов в файле и пишет карту system.jsmap.php,
 * по ней документ подключает скрипты в нужном порядке. В браузере вызов ничего не делает.
 */
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

    /**
     * Language ID.
     * @type {string}
     */
    lang: '',

    /**
     * Токен против подделки запросов; задаёт страница (document.xslt).
     * @type {string}
     */
    csrf: '',

    /**
     * Окно админки (режим single).
     * @type {boolean}
     */
    singleMode: false,

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
            Object.assign(Energine.translations, obj);
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
     * Запрос к серверу с теми же заголовками, что у прежнего запроса JSON на MooTools: X-Requested-With,
     * X-Request: JSON (по нему сервер отвечает JSON), Accept, у POST — тип тела, и токен X-CSRF-Token.
     *
     * @function
     * @static
     * @param {string} uri URI
     * @param {string|null} [body] Строка запроса.
     * @param {string} [method = 'post'] 'get' или 'post'.
     * @returns {Promise<{status: number, text: string, json: (Object|null)}>} сетевая ошибка — status 0
     */
    send: function (uri, body, method) {
        method = (method || 'post').toUpperCase();
        body = (body === null || body === undefined) ? '' : String(body);
        var headers = {'X-Requested-With': 'XMLHttpRequest', 'X-Request': 'JSON', 'Accept': 'application/json'};
        if (Energine.csrf) {
            headers['X-CSRF-Token'] = Energine.csrf;
        }
        var init = {method: method, headers: headers, credentials: 'same-origin'};
        if (method === 'GET') {
            if (body) {
                uri += ((uri.indexOf('?') === -1) ? '?' : '&') + body;
            }
        } else {
            headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8';
            init.body = body;
        }
        // сетевая ошибка — и до ответа, и на чтении его тела (соединение оборвалось после заголовков)
        return fetch(uri, init).then(function (response) {
            return response.text().then(function (text) {
                var json = null;
                try {
                    json = JSON.parse(text);
                } catch (e) {
                }
                return {status: response.status, text: text, json: json};
            });
        }).catch(function () {
            return {status: 0, text: '', json: null};
        });
    },

    /**
     * Send the request.
     *
     * @function
     * @static
     * @param {string} uri URI
     * @param {string|null} data Request.
     * @param {function} onSuccess Callback function that will be called by successful response.
     * @param {function} [onUserError] Callback function that will be called by user error.
     * @param {function} [onServerError] Callback function that will be called by server error.
     * @param {string} [method = 'post'] Request method: 'get', 'post'.
     */
    request: function (uri, data, onSuccess, onUserError, onServerError, method) {
        onServerError = onServerError || function (responseText) {
        };

        // ошибки из ответа сервера: текст для администратора
        var showErrors = function (response) {
            var msg = (typeof response.title != 'undefined')
                ? response.title
                : 'Произошла ошибка:\n';
            (response.errors || []).forEach(function (error) {
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

        Energine.send(uri + ((Energine.forceJSON) ? '?json' : ''), data, method).then(function (r) {
            if (r.status >= 400 || r.status === 0) {
                // отказ с объяснением в JSON (например, устаревшая форма — код 422) показывается как ошибка формы
                if (r.json && r.json.errors) {
                    showErrors(r.json);
                } else {
                    onServerError(r.text);
                    console.error('Energine.request: HTTP ' + r.status + ' ' + uri);
                }
                return;
            }
            if (!r.json) {
                onServerError(r.text);
                return;
            }
            if (r.json.result) {
                onSuccess(r.json);
            } else {
                showErrors(r.json);
            }
        });
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
     * Energine.resize(document.querySelector('img'), 'images/img01.png', 100, 50);
     * document.querySelector('img').getAttribute('src') == 'http://www.site.ua/resizer/w100-h50/images/img01.png'
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
 * Скрытое поле токена для форм, которые создаёт JS (формы из XSLT получают его в шаблоне).
 *
 * @returns {HTMLInputElement}
 */
Energine.csrfInput = function () {
    var input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'csrf_token';
    input.value = Energine.csrf || '';
    return input;
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

// в режиме отладки картинка ресайзера, которой нет, заменяется серой заглушкой того же размера
document.addEventListener('DOMContentLoaded', function () {
    if (!Energine.debug) {
        return;
    }
    document.querySelectorAll('img').forEach(function (image) {
        image.addEventListener('error', function () {
            var matches = /\/resizer\/w(\d*)-h(\d*)/.exec(image.getAttribute('src') || '');
            if (matches) {
                image.setAttribute('src', Energine.placeholder(matches[1], matches[2]));
            }
        });
    });
});
