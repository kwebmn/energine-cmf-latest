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

ScriptLoader.load('EnergineEditor', 'ModalBox', 'Overlay');

/**
 * Правка текстовых блоков (и новостей ленты) прямо на странице: каждый элемент .nrgnEditor —
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
     * Сохранить блок, если он изменился.
     */
    save: function () {
        if (!this.isDirty()) {
            return;
        }
        var value = this.editor.value;
        fetch(this.singlePath + 'save-text', {method: 'POST', body: this.body(value), credentials: 'same-origin'})
            .then(function (response) {
                if (response.ok) {
                    this.saved = value;
                } else {
                    console.warn('save-text: HTTP ' + response.status);
                }
            }.bind(this))
            .catch(function (e) {
                console.warn(e);
            });
    },

    /**
     * При уходе со страницы: несохранённое отправляется маяком.
     */
    beacon: function () {
        if (this.isDirty()) {
            var value = this.editor.value;
            if (navigator.sendBeacon(this.singlePath + 'save-text', this.body(value))) {
                this.saved = value;
            }
        }
    }
});
