/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Form]{@link Form}</li>
 *     <li>[Form.Sked]{@link Form.Sked}</li>
 *     <li>[Form.AttachmentSelector]{@link Form.AttachmentSelector}</li>
 *     <li>[Form.Label]{@link Form.Label}</li>
 *     <li>[Form.RichEditor]{@link Form.RichEditor}</li>
 * </ul>
 *
 * @requires Energine
 * @requires EnergineEditor
 * @requires TabPane
 * @requires Toolbar
 * @requires Validator
 * @requires ModalBox
 * @requires Overlay
 * @requires datepicker
 *
 * @author Pavel Dubenko
 *
 * @version 1.0.1
 */

ScriptLoader.load('EnergineEditor', 'TabPane', 'Toolbar', 'Validator', 'ModalBox', 'Overlay', 'datepicker');

/**
 * Form.
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var Form = new Class(/** @lends Form# */{
    /**
     * @see Energine.request
     * @deprecated Use Energine.request instead.
     */
    request: Energine.request,

    /**
     * The overlay.
     * @type {Overlay}
     */
    overlay: null,

    /**
     * Attached toolbar.
     * @type {Toolbar}
     */
    toolbar: null,

    /**
     * Array of RichEditors.
     * @type {RichEditor[]}
     */
    richEditors: [],

    /**
     * Array of text boxes.
     * @type {Array}
     */
    textBoxes: [],

    /**
     * Array of date controls.
     * @type {Array}
     */
    dateControls: [],

    /**
     * Array of code editors.
     * @type {CodeMirror[]}
     */
    codeEditors: [],

//    smapSelectors: [],

    // constructor
    initialize: function (element) {
        Asset.css('form.css');

        this.overlay = new Overlay();

        /**
         * The component element.
         * @type {Element}
         */
        this.element = $(element);

        /**
         * Value of property 'single_template'.
         * @type {string}
         */
        this.singlePath = this.element.getProperty('single_template');

        /**
         * The main holder element.
         * @type {Element}
         */
        this.form = this.element.getParent('form').addClass('form');

        if (this.form.getElements('input[type=text]').concat(this.form.getElements('select'), this.form.getElements('textarea')).length) {
            this.form.addEvent('keypress', function (e) {
                if (e.key == 'enter') {
                    var target = $(e.target);
                    if ((target.get('tag') == 'input') && (target.getProperty('type') == 'text')) {
                        e.preventDefault();
                    }
                }
            })
        }

        /**
         * State of the form.
         * @type {string}
         */
        this.state = (this.form.getElementById('componentAction'))?this.form.getElementById('componentAction').get('value'):null;

        /**
         * Tab panels.
         * @type {TabPane}
         */
        this.tabPane = new TabPane(this.element, {
            onTabChange: this.onTabChange.bind(this)
        });

        /**
         * The Validator.
         * @type {Validator}
         */
        this.validator = new Validator(this.form, this.tabPane);

        this.form.getElements('textarea.richEditor').each(function (textarea) {
            this.richEditors.push(new Form.RichEditor(textarea, this));
        }, this);

        this.form.getElements('textarea.code').each(function (textarea) {
            this.codeEditors.push(CodeMirror.fromTextArea(textarea, {
                mode: "htmlmixed",
                tabMode: "indent",
                lineNumbers: true,
                theme: 'elegant',
                autofocus: false
            }));
        }, this);


        var showHideFunc = function (e) {
            e.stop();
            var el = $(e.target),
                field = el.getParent('.field');

            if (field) {
                if (field.hasClass('min')) {
                    field.swapClass('min', 'max');
                } else if (el.hasClass('icon_min_max') && field.hasClass('max')) {
                    field.swapClass('max', 'min');
                }
            }
        };

        this.form.getElements('.field .control.toggle').addEvent('click', showHideFunc);
        this.form.getElements('.icon_min_max').addEvent('click', showHideFunc);

        this.form.getElements('.attachment_selector').each(function (el) {
            new Form.AttachmentSelector(el, this);
        }, this);

        var cps;
        if(cps = this.element.getElements('input.inp_color')){
            cps.each(function(colorElement){
                new ColorPicker(colorElement, {'changeOnHover': true});
            }, this);
        }


        (this.element.getElements('.inp_date') || []).append(this.element.getElements('.inp_datetime') || []).each(function (dateControl) {
            var isNullable = !dateControl.getParent('.field').hasClass('required');
            this.dateControls.push(
                (dateControl.hasClass('inp_datetime') ? Energine.createDateTimePicker(dateControl, isNullable)
                    : Energine.createDatePicker(dateControl, isNullable))
            );
        }, this);

        this.element.getElements('.pane').setStyles({
            'border': '1px dotted #777',
            'overflow': 'auto'
        });

        /*Checking if opened in modalbox*/
        var mb = window.parent.ModalBox;
        if (mb && mb.initialized && mb.getCurrent()) {
            $(document.body).addEvent('keypress', function (evt) {
                if (evt.key == 'esc') {
                    mb.close();
                }
            });
        }

        /**
         * Controls, that appended with additional controls, like buttons.
         * @type {Element[]}
         */
        this.appendedControls = this.form.getElements('.with_append');
        this.appendedControls.each(function (el) {
            Object.append(el, {
                isOnFocus: false,
                controlEl: el
            });
  /*          el.addEvents({
                mouseenter: this.glow.bind(this),
                mouseleave: this.glow.bind(this)
            });*/
        }, this);
        this.appendedControls.getElements('input,select').each(function (el, id) {
            el.each(function (el) {
                el.controlEl = this.appendedControls[id];
            }.bind(this));

/*            el.addEvents({
                focus: this.glow.bind(this),
                blur: this.glow.bind(this)
            });*/
        }, this);
    },

    /**
     * Create required IFrame by tab changing.
     */
    onTabChange: function () {
        var currentTab = this.tabPane.currentTab;

        if (currentTab.getProperty('data-src') && !currentTab.loaded) {
            currentTab.pane.empty();
            currentTab.pane.grab(new Element('iframe', {
                src: Energine['base'] + currentTab.getProperty('data-src'),
                frameBorder: 0,
                scrolling: 'no',
                styles: {
                    width: '99%',
                    height: '99%'
                }
            }));
            currentTab.loaded = true;
        }
        else {
            this.codeEditors.each(function(ce){
                ce.refresh();
            });
        }
    },

    /**
     * Apply or remove glow effect to the appended buttons near the input fields.
     * @param {Object} ev Event. By default this function is connected to 'onFocus', 'onBlur', 'onMouseover' and 'onMouseout' events.
     */
    glow: function (ev) {
        switch (ev.type) {
            case 'focus':
                ev.target.controlEl.isOnFocus = true;
            case 'mouseenter':
                ev.target.controlEl.addClass('focus_block');
               // ev.stopPropagation();
                break;

            case 'blur':
                ev.target.controlEl.isOnFocus = false;
            case 'mouseleave':
                if (!ev.target.controlEl.isOnFocus) {
                    ev.target.controlEl.removeClass('focus_block');
                 //   ev.stopPropagation();
                }
                break;
        }
    },

    /**
     * Attach the toolbar.
     *
     * @function
     * @public
     * @param {Toolbar} toolbar Toolbar that will be attached.
     */
    attachToolbar: function (toolbar) {
        this.toolbar = toolbar;
        var toolbarContainer = this.element.getElement('.e-pane-b-toolbar'),
            afterSaveActionSelect = this.toolbar.getControlById('after_save_action');

        if (toolbarContainer) {
            toolbarContainer.adopt(this.toolbar.getElement());
        } else {
            this.element.adopt(this.toolbar.getElement());
        }

        if (afterSaveActionSelect) {
            var savedActionState = Cookie.read('after_add_default_action');
            if (savedActionState) {
                afterSaveActionSelect.setSelected(savedActionState);
            }
        }
        toolbar.bindTo(this);
    },

    /**
     * Build the URL for saving.
     *
     * @function
     * @public
     * @return {string}
     */
    buildSaveURL: function () {
        return this.singlePath + 'save';
    },

    /**
     * Save all in the form.
     * @function
     * @public
     */
    save: function () {
        this.richEditors.each(function (editor) {
            editor.onSaveForm();
        });
        this.codeEditors.each(function (editor) {
            editor.save();
        });

        if (!this.validator.validate()) {
            return;
        }

        this.overlay.show();

        Energine.request(
            this.buildSaveURL(),
            this.form.toQueryString(),
            this.processServerResponse.bind(this),
            this.processServerError.bind(this),
            this.processServerError.bind(this)
        );
    },

    /**
     * Callback function by successful server response.
     *
     * @function
     * @public
     * @param {Object} response Result data from the server.
     */
    processServerResponse: function (response) {
        var nextActionSelector;
        if (response && (nextActionSelector = this.toolbar.getControlById('after_save_action'))) {
            Cookie.write('after_add_default_action', nextActionSelector.getValue(), {
                path: new URI(Energine.base).get('directory'),
                duration: 1
            });
            response.afterClose = nextActionSelector.getValue();
        }
        ModalBox.setReturnValue(response);
        this.overlay.hide();
        this.close();
    },

    /**
     * Callback function by server error.
     *
     * @function
     * @public
     * @param {Object} response Result data from the server.
     */
    processServerError: function (response) {
        this.overlay.hide();
    },

    /**
     * Close the form.
     * @function
     * @public
     */
    close: function () {
        ModalBox.close();
    },

    /**
     * Clear the file field.
     *
     * @function
     * @public
     * @param {string|number} fieldId
     * @param {} lnk
     */
    clearFileField: function (fieldId, lnk) {
        var preview;
        this.form.getElementById(fieldId).set('value', '');
        if (preview = this.form.getElementById(fieldId + '_preview')) {
            preview.removeProperty('href').hide();
        }
        lnk.hide();
    },

    /**
     * Process file result.
     *
     * @function
     * @public
     * @param {Object} result
     * @param {Element|string} button Button element.
     */
    processFileResult: function (result, button) {
        var image;

        if (!result) {
            return;
        }

        button = $(button);
        $(button.getProperty('link')).value = result['upl_path'];

        image = ($(button.getProperty('preview')).get('tag') == 'img')
            ? $(button.getProperty('preview'))
            : $(button.getProperty('preview')).getElement('img');

        if (image) {
            var src;
            switch (result['upl_internal_type']) {
                case 'image':
                    src = Energine.media + result['upl_path'];
                    break;
                default:
                    src = Energine['static'] + 'images/icons/icon_undefined.gif';
            }

            image.setProperty('src', src);
            $(button.getProperty('preview')).setProperty('href', Energine.media + result['upl_path']).show();
        }

        if (button.getNext('.lnk_clear')) {
            button.getNext('.lnk_clear').show('inline');
        }
    },

    /**
     * Open the file library.
     *
     * @function
     * @public
     * @param {Element|string} button Button element.
     */
    openFileLib: function (button) {
        var path = $($(button).getProperty('link')).get('value');
        if (path == '') {
            path = null;
        }
        ModalBox.open({
            url: this.singlePath + 'file-library/',
            extraData: path,
            onClose: function (result) {
                this.processFileResult(result, button);
            }.bind(this)
        });
    },

    /**
     * Open th equick upload window.
     *
     * @function
     * @public
     * @param {Element|string} button Button element.
     */
    openQuickUpload: function (button) {
        var path = $($(button).getProperty('link')).get('value');
        if (path == '') {
            path = null;
        }
        var quick_upload_path = $(button).getProperty('quick_upload_path');
        var quick_upload_pid = $(button).getProperty('quick_upload_pid');
        var quick_upload_enabled = $(button).getProperty('quick_upload_enabled');
        var overlay = this.overlay;
        var processResult = this.processFileResult;

        if (!quick_upload_enabled) return;

        ModalBox.open({
            url: this.singlePath + 'file-library/' + quick_upload_pid + '/add',
            extraData: path,
            onClose: function (result) {
                if (result && result.data) {
                    var upl_id = result.data;

                    if (upl_id) {
                        overlay.show();
                        new Request.JSON({
                            'url': this.singlePath + 'file-library/' + quick_upload_pid + '/get-data/',
                            'method': 'post',
                            'data': {
                                json: 1,
                                filter: JSON.encode({
                                    'children': [{
                                        'field': '[share_uploads][upl_id]',
                                        'type': 'string',
                                        condition: '=',
                                        'value': upl_id
                                    }]
                                })
                            },
                            'evalResponse': true,
                            'onComplete': function (data) {
                                if (data && data.data && data.data.length == 2) {
                                    overlay.hide();
                                    processResult(data.data[1], button);
                                }
                            }.bind(this),
                            'onFailure': function (e) {
                                overlay.hide();
                            }
                        }).send();
                    }
                }
            }.bind(this)
        });
    }
});

/**
 * AttachmentSelector.
 *
 * @constructor
 * @param {string|Element} selector The element id.
 * @param {Form} form The form.
 */
Form.AttachmentSelector = new Class(/** @lends Form.AttachmentSelector# */{
    // constructor
    initialize: function (selector, form) {
        selector = $(selector);
        this.form = form;
        this.field = selector.getProperty('data-field');
        /**
         * Upload name.
         * @type {string}
         */
        this.uplName = $(selector.getProperty('data-name'));
        /**
         * Upload ID.
         * @type {string|number}
         */
        this.uplId = $(selector.getProperty('data-id'));
        this.uplPreview = $(selector.getProperty('data-preview'));

        if(this.form.form.getElementById('componentAction').get('value') == 'add'){
            this.showSelector.apply(this);
        }

        selector.addEvent('click', function (e) {
            e.stop();
            this.showSelector.apply(this);
        }.bind(this));
    },

    /**
     * Show the selector.
     * @function
     * @public
     */
    showSelector: function () {
        ModalBox.open({
            url: this.form.element.getProperty('single_template') + 'file-library/',
            onClose: this.setName.bind(this)
        });
    },

    /**
     * Set the name and ID of the smap.
     *
     * @function
     * @public
     * @param {} result
     */
    setName: function (result) {
        if (result) {
            this.uplName.set('value', result.upl_path);
            this.uplId.set('value', result.upl_id);
            if (result.upl_internal_type == 'image') {
                this.uplPreview.removeClass('hidden');
                this.uplPreview.getElement('img').setProperty('src', result.upl_path);
            }
        }
    }
});

// Предназначен для последующей имплементации
// Содержит метод setLabel использующийся для привязки кнопки выбора разделов
/**
 * Contain the methods that will be implemented in other classes.
 *
 * @namespace
 */
Form.Label = /** @lends Form.Label */{
    /**
     * Set the label.
     *
     * @function
     * @static
     * @param {} result The server result.
     */
    setLabel: function (result) {
        var id = name = segment = segmentObject = '';

        if (typeOf(result) != 'null') {
            if (result) {
                id = result.smap_id;
                name = result.smap_name;
                segment = result.smap_segment;
            }

            $(this.obj.getProperty('hidden_field')).value = id;
            $(this.obj.getProperty('span_field')).innerHTML = name;

            if (segmentObject = $('smap_pid_segment')) {
                segmentObject.innerHTML = segment;
            }

            Cookie.write(
                'last_selected_smap',
                JSON.encode({'id': id, 'name': name, 'segment': segment}),
                {path: new URI(Energine.base).get('directory'), duration: 1}
            );
        }
    },

    /**
     * Prepare the label.
     *
     * @function
     * @static
     * @param {string} treeURL The URL of the tree.
     * @param {boolean|*} restore
     */
    prepareLabel: function (treeURL, restore) {
        if (!arguments[1]) {
            restore = false;
        }

        /**
         * Sitemap selector element.
         * @type {Element}
         */
        this.obj = $('sitemap_selector');
        if (this.obj) {
            this.obj.addEvent('click', this.showTree.pass(treeURL, this));
            if (restore) {
                this.restoreLabel();
            }
        }
    },

    /**
     * Show the tree.
     *
     * @function
     * @static
     * @param {string} url The URL.
     */
    showTree: function (url) {
        ModalBox.open({
            url: this.singlePath + url,
            onClose: this.setLabel.bind(this)
        });
    },

    /**
     * Restore the label.
     * @function
     * @static
     */
    restoreLabel: function () {
        var savedData = Cookie.read('last_selected_smap');
        if (this.obj && savedData) {
            savedData = JSON.decode(savedData, false);

            $(this.obj.getProperty('hidden_field')).value = savedData.id;
            $(this.obj.getProperty('span_field')).innerHTML = savedData.name;

            var segmentObject = $('smap_pid_segment');
            if (segmentObject) {
                segmentObject.innerHTML = savedData.segment;
            }
        }
    }
};
/**
 * Визуальный редактор поля формы (Jodit, общая настройка — EnergineEditor).
 *
 * @constructor
 * @param {Element|string} textarea
 * @param {Form} form
 */
Form.RichEditor = new Class(/** @lends Form.RichEditor# */{

    /**
     * Editor.
     * @type {Jodit}
     */
    editor: null,

    // constructor
    initialize: function (textarea, form) {
        /**
         * The text area element.
         * @type {Element}
         */
        this.textarea = $(textarea);

        /**
         * The main form.
         * @type {Form}
         */
        this.form = form;

        /**
         * Текст поля, как он пришёл с сервера, и значение редактора сразу после открытия:
         * если администратор текст не менял, сохраняется исходный текст, а не его прочтение редактором.
         * @type {string}
         */
        this.original = this.textarea.value;
        this.editor = EnergineEditor.make(this.textarea, {singlePath: this.form.singlePath});
        this.opened = this.editor.value;
    },

    /**
     * Перед отправкой формы текст редактора переносится в textarea — только если его меняли.
     * @function
     * @public
     */
    onSaveForm: function () {
        this.textarea.value = (this.editor.value === this.opened) ? this.original : this.editor.value;
    }
});

