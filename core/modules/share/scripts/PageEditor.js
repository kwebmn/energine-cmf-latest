/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageEditor]{@link PageEditor}</li>
 *     <li>[PageEditor.BlockEditor]{@link PageEditor.BlockEditor}</li>
 * </ul>
 *
 * @requires Energine
 * @requires EnergineEditor
 * @requires ModalBox
 * @requires Overlay
 *
 * @author Pavel Dubenko
 * @author Andy Karpov
 * @author Valerii Zinchenko
 *
 * @version 1.0.0
 */

ScriptLoader.load('MooCompat', 'EnergineEditor', 'ModalBox', 'Overlay');

/**
 * Правка текстовых блоков прямо на странице: каждый элемент .nrgnEditor —
 * встроенный (inline) редактор Jodit. Блок сохраняется, когда из него уходят; несохранённое при
 * уходе со страницы отправляется маяком — синхронный запрос при закрытии страницы браузеры не шлют.
 *
 * @constructor
 */
var PageEditor = new Class(/** @lends PageEditor# */{
    /**
     * Class name of the editable elements.
     * @type {string}
     */
    editorClassName: 'nrgnEditor',

    /**
     * Block editors.
     * @type {PageEditor.BlockEditor[]}
     */
    editors: [],

    // constructor
    initialize: function () {
        $(document.body).getElements('.' + this.editorClassName).each(function (element) {
            this.editors.push(new PageEditor.BlockEditor(element));
        }, this);

        window.addEventListener('pagehide', function () {
            this.editors.each(function (editor) {
                editor.beacon();
            });
        }.bind(this));
    }
});

/**
 * Редактор одного блока.
 *
 * @constructor
 * @param {Element} area Элемент .nrgnEditor с атрибутами single_template, eID, num.
 */
PageEditor.BlockEditor = new Class(/** @lends PageEditor.BlockEditor# */{
    // constructor
    initialize: function (area) {
        this.area = area;
        this.singlePath = this.area.getProperty('single_template');
        this.ID = this.area.getProperty('eID') || '';
        this.num = this.area.getProperty('num') || '';

        this.editor = EnergineEditor.make(this.area, {
            singlePath: this.singlePath,
            jodit: {inline: true, toolbarInline: true, toolbarInlineForSelection: false, showPlaceholder: false}
        });
        /**
         * Текст, который уже на сервере.
         * @type {string}
         */
        this.saved = this.editor.value;
        this.editor.events.on('blur', this.save.bind(this));
    },

    /**
     * Есть ли несохранённые изменения.
     * @returns {boolean}
     */
    isDirty: function () {
        return this.editor.value !== this.saved;
    },

    /**
     * Тело запроса save-text.
     * @returns {URLSearchParams}
     */
    body: function (value) {
        var data = new URLSearchParams();
        // токен в теле: маяк заголовков не передаёт
        data.append('csrf_token', Energine.csrf || '');
        data.append('data', value);
        if (this.ID) {
            data.append('ID', this.ID);
        }
        if (this.num) {
            data.append('num', this.num);
        }
        return data;
    },

    /**
     * Адрес сохранения: ответ JSON, в том числе при отказе (?json — маяк заголовков не передаёт).
     * @returns {string}
     */
    url: function () {
        return this.singlePath + 'save-text?json';
    },

    /**
     * Сохранить блок, если он изменился. Сохранённым считается только ответ {result: true}:
     * страница вместо ответа (нет прав, сессия закончилась) и отказ сервера оставляют блок несохранённым.
     */
    save: function () {
        if (!this.isDirty()) {
            return;
        }
        var value = this.editor.value;
        fetch(this.url(), {method: 'POST', body: this.body(value), credentials: 'same-origin'})
            .then(function (response) {
                return response.text().then(function (text) {
                    var result = null;
                    try {
                        result = JSON.parse(text);
                    } catch (e) {
                    }
                    if (response.ok && result && result.result) {
                        this.saved = value;
                        this.area.removeClass('nrgnEditorError');
                    } else {
                        this.fail(result, response.status);
                    }
                }.bind(this));
            }.bind(this))
            .catch(function () {
                this.fail(null, 0);
            }.bind(this));
    },

    /**
     * Блок не сохранён: он помечается и остаётся несохранённым (следующий уход из блока или со страницы
     * отправит его снова), администратор узнаёт причину.
     *
     * @param {Object} result ответ сервера, если это JSON
     * @param {number} status код ответа
     */
    fail: function (result, status) {
        this.area.addClass('nrgnEditorError');
        alert((result && result.errors && result.errors[0] && result.errors[0].message)
            || ((Energine.translations.get('ERR_TEXT_NOT_SAVED') || 'Error') + (status ? ' (HTTP ' + status + ')' : '')));
    },

    /**
     * При уходе со страницы: несохранённое отправляется маяком.
     */
    beacon: function () {
        if (this.isDirty()) {
            var value = this.editor.value;
            if (navigator.sendBeacon(this.url(), this.body(value))) {
                this.saved = value;
            }
        }
    }
});
