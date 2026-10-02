/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Form]{@link Form}</li>
 *     <li>[Form.Label]{@link Form.Label}</li>
 *     <li>[Form.RichEditor]{@link Form.RichEditor}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires EnergineEditor
 * @requires TabPane
 * @requires Toolbar
 * @requires Validator
 * @requires ModalBox
 * @requires Overlay
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('EnergineEditor', 'TabPane', 'Toolbar', 'Validator', 'ModalBox', 'Overlay');

/**
 * Форма админки: вкладки, проверка полей, визуальные поля, поля файлов. «Сохранить» отправляет поля формы и
 * отдаёт ответ окну, из которого форму открыли.
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id) внутри формы.
 */
var Form = class Form {
    constructor(element) {
        Energine.loadCSS('form.css');

        /**
         * The overlay.
         * @type {Overlay}
         */
        this.overlay = new Overlay();
        /**
         * Attached toolbar.
         * @type {Toolbar}
         */
        this.toolbar = null;
        /**
         * Визуальные поля.
         * @type {Form.RichEditor[]}
         */
        this.richEditors = [];
        this.element = Form.element(element);
        this.singlePath = this.element.getAttribute('single_template');
        this.form = this.element.closest('form');
        this.form.classList.add('form');

        // Enter в текстовом поле не отправляет форму
        if (this.form.querySelector('input[type=text], select, textarea')) {
            this.form.addEventListener('keypress', (event) => {
                if (event.key === 'Enter' && event.target.tagName === 'INPUT' && event.target.type === 'text') {
                    event.preventDefault();
                }
            });
        }

        const action = this.form.querySelector('#componentAction');
        /**
         * State of the form.
         * @type {string}
         */
        this.state = action ? action.value : null;
        this.tabPane = new TabPane(this.element, {onTabChange: () => this.onTabChange()});
        this.validator = new Validator(this.form, this.tabPane);
        this.form.querySelectorAll('textarea.richEditor').forEach((textarea) => {
            this.richEditors.push(new Form.RichEditor(textarea, this));
        });

        // пустое текстовое поле свёрнуто (min): щелчок по полю разворачивает его, щелчок по значку — сворачивает
        const showHide = (event) => {
            event.preventDefault();
            event.stopPropagation();
            const el = event.target,
                field = el.closest('.field');
            if (field) {
                if (field.classList.contains('min')) {
                    field.classList.replace('min', 'max');
                } else if (el.classList.contains('icon_min_max') && field.classList.contains('max')) {
                    field.classList.replace('max', 'min');
                }
            }
        };
        this.form.querySelectorAll('.field .control.toggle, .icon_min_max').forEach((el) => el.addEventListener('click', showHide));

        // поля даты — встроенные поля браузера; обязательное пустое поле сразу получает сегодняшнюю дату (поле
        // даты и времени — и текущее время), как раньше при открытии формы
        this.element.querySelectorAll('input.inp_date, input.inp_datetime').forEach((dateControl) => {
            const field = dateControl.closest('.field');
            if (dateControl.value === '' && field && field.classList.contains('required')) {
                const now = new Date(),
                    pad = (n) => (n < 10 ? '0' : '') + n,
                    day = now.getFullYear() + '-' + pad(now.getMonth() + 1) + '-' + pad(now.getDate());
                dateControl.value = dateControl.classList.contains('inp_datetime')
                    ? day + 'T' + pad(now.getHours()) + ':' + pad(now.getMinutes()) : day;
            }
        });

        this.element.querySelectorAll('.pane').forEach((pane) => {
            pane.style.border = '1px dotted #777';
            pane.style.overflow = 'auto';
        });
    }

    /**
     * Вкладка со своей страницей (data-src): при первом показе — iframe с этой страницей.
     */
    onTabChange() {
        const currentTab = this.tabPane.currentTab;
        if (currentTab.getAttribute('data-src') && !currentTab.loaded) {
            const iframe = document.createElement('iframe');
            iframe.src = Energine['base'] + currentTab.getAttribute('data-src');
            iframe.frameBorder = 0;
            iframe.scrolling = 'no';
            iframe.style.width = '99%';
            iframe.style.height = '99%';
            currentTab.pane.replaceChildren(iframe);
            currentTab.loaded = true;
        }
    }

    /**
     * Привязать панель: она встаёт в нижнюю панель окна (или в конец формы); список «после сохранения» показывает
     * выбор, запомненный в cookie.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        this.toolbar = toolbar;
        const toolbarContainer = this.element.querySelector('.e-pane-b-toolbar'),
            afterSaveActionSelect = this.toolbar.getControlById('after_save_action');
        (toolbarContainer || this.element).appendChild(this.toolbar.element);
        if (afterSaveActionSelect) {
            const savedActionState = Energine.readCookie('after_add_default_action');
            if (savedActionState) {
                afterSaveActionSelect.setSelected(savedActionState);
            }
        }
        toolbar.bindTo(this);
    }

    /**
     * Build the URL for saving.
     * @returns {string}
     */
    buildSaveURL() {
        return this.singlePath + 'save';
    }

    /**
     * Сохранить: визуальные поля — в textarea, проверка полей, затемнение, запрос с полями формы.
     */
    save() {
        this.richEditors.forEach((editor) => editor.onSaveForm());
        if (!this.validator.validate()) {
            return;
        }
        this.overlay.show();
        Energine.request(
            this.buildSaveURL(),
            Form.toQueryString(this.form),
            (response) => this.processServerResponse(response),
            (response) => this.processServerError(response),
            (response) => this.processServerError(response)
        );
    }

    /**
     * Ответ на сохранение: выбор «после сохранения» запоминается в cookie на сутки и уходит в ответе (afterClose);
     * ответ получает окно, из которого форму открыли; окно закрывается.
     *
     * @param {Object} response
     */
    processServerResponse(response) {
        const nextActionSelector = response && this.toolbar.getControlById('after_save_action');
        if (nextActionSelector) {
            Energine.writeCookie('after_add_default_action', nextActionSelector.getValue(),
                {path: Energine.sitePath(), days: 1});
            response.afterClose = nextActionSelector.getValue();
        }
        ModalBox.setReturnValue(response);
        this.overlay.hide();
        this.close();
    }

    /**
     * Отказ сервера: затемнение снимается, форма остаётся открытой.
     *
     * @param {Object} response
     */
    processServerError(response) {
        this.overlay.hide();
    }

    /**
     * Close the form.
     */
    close() {
        ModalBox.close();
    }

    /**
     * «Очистить» у поля файла: путь пуст, превью и сама ссылка скрыты.
     *
     * @param {string} fieldId id поля пути
     * @param {Element} lnk ссылка «очистить»
     */
    clearFileField(fieldId, lnk) {
        this.form.querySelector('#' + CSS.escape(fieldId)).value = '';
        const preview = this.form.querySelector('#' + CSS.escape(fieldId + '_preview'));
        if (preview) {
            preview.removeAttribute('href');
            preview.style.display = 'none';
        }
        lnk.style.display = 'none';
    }

    /**
     * Выбранный файл — в поле: путь, превью (картинка или значок файла), ссылка «очистить».
     *
     * @param {Object} result файл репозитория (upl_path, upl_internal_type)
     * @param {Element|string} button кнопка поля (атрибуты link и preview — id поля пути и превью)
     */
    processFileResult(result, button) {
        if (!result) {
            return;
        }
        button = Form.element(button);
        document.getElementById(button.getAttribute('link')).value = result['upl_path'];
        const preview = document.getElementById(button.getAttribute('preview')),
            image = (preview.tagName === 'IMG') ? preview : preview.querySelector('img');
        if (image) {
            image.setAttribute('src', (result['upl_internal_type'] === 'image')
                ? Energine.media + result['upl_path']
                : Energine['static'] + 'images/icons/icon_undefined.gif');
            preview.setAttribute('href', Energine.media + result['upl_path']);
            preview.style.display = 'block';
        }
        // ссылка «очистить» — рядом с полем, уровнем выше кнопки
        const append = button.closest('.with_append'),
            clear = append && append.querySelector('.lnk_clear');
        if (clear) {
            clear.style.display = 'inline';
        }
    }

    /**
     * «…» у поля файла: библиотека файлов; выбранный файл — в поле.
     *
     * @param {Element|string} button Button element.
     */
    openFileLib(button) {
        button = Form.element(button);
        let path = document.getElementById(button.getAttribute('link')).value;
        if (path === '') {
            path = null;
        }
        ModalBox.open({
            url: this.singlePath + 'file-library/',
            extraData: path,
            onClose: (result) => this.processFileResult(result, button)
        });
    }

    /**
     * «Быстрая загрузка»: окно добавления файла в папку быстрой загрузки; загруженный файл находится по id и
     * подставляется в поле, как выбранный в библиотеке.
     *
     * @param {Element|string} button Button element.
     */
    openQuickUpload(button) {
        button = Form.element(button);
        let path = document.getElementById(button.getAttribute('link')).value;
        if (path === '') {
            path = null;
        }
        const pid = button.getAttribute('quick_upload_pid');
        if (!button.getAttribute('quick_upload_enabled')) {
            return;
        }
        ModalBox.open({
            url: this.singlePath + 'file-library/' + pid + '/add',
            extraData: path,
            onClose: (result) => {
                if (!(result && result.data)) {
                    return;
                }
                this.overlay.show();
                const filter = {children: [{field: '[share_uploads][upl_id]', type: 'string', condition: '=', value: result.data}]};
                Energine.send(this.singlePath + 'file-library/' + pid + '/get-data/',
                    'json=1&filter=' + encodeURIComponent(JSON.stringify(filter)))
                    .then((response) => {
                        // затемнение снимается при любом ответе
                        this.overlay.hide();
                        const data = response.json && response.json.data;
                        if (data && data.length == 2) {
                            this.processFileResult(data[1], button);
                        }
                    });
            }
        });
    }

    /**
     * Поля формы строкой запроса — как прежде (toQueryString MooTools): input, select, textarea с именем, кроме
     * выключенных и submit, reset, file, image; флажки и переключатели — только отмеченные; у списка — выбранные
     * варианты. FormData не годится: textarea в нём отдаёт переводы строк \r\n.
     *
     * @param {Element} form
     * @returns {string}
     */
    static toQueryString(form) {
        const query = [];
        form.querySelectorAll('input, select, textarea').forEach((el) => {
            const type = el.type;
            if (!el.name || el.disabled || ['submit', 'reset', 'file', 'image'].includes(type)) {
                return;
            }
            let values = [el.value];
            if (el.tagName === 'SELECT') {
                values = Array.from(el.options).filter((option) => option.selected).map((option) => option.value);
            } else if ((type === 'radio' || type === 'checkbox') && !el.checked) {
                values = [];
            }
            values.forEach((value) => query.push(encodeURIComponent(el.name) + '=' + encodeURIComponent(value)));
        });
        return query.join('&');
    }

    /**
     * Элемент по id или сам элемент.
     *
     * @param {Element|string} element
     * @returns {Element}
     */
    static element(element) {
        return (typeof element === 'string') ? document.getElementById(element) : element;
    }
};

/**
 * Выбор раздела-родителя (подмешивается в DivForm): кнопка #sitemap_selector открывает окно дерева разделов;
 * выбранный раздел — в скрытом поле (атрибут hidden_field кнопки), его имя — текстом в подписи (span_field),
 * сегмент — в адресе раздела (#smap_pid_segment).
 *
 * @namespace
 */
Form.Label = {
    /**
     * Подключить кнопку выбора.
     *
     * @param {string} treeURL адрес окна дерева от адреса компонента
     */
    prepareLabel(treeURL) {
        this.obj = document.getElementById('sitemap_selector');
        if (this.obj) {
            this.obj.addEventListener('click', () => this.showTree(treeURL));
        }
    },

    /**
     * Окно дерева разделов.
     *
     * @param {string} url
     */
    showTree(url) {
        ModalBox.open({
            url: this.singlePath + url,
            onClose: (result) => this.setLabel(result)
        });
    },

    /**
     * Выбранный раздел — в поле. Окно закрыто без выбора (null, undefined) — ничего; false — выбор снят.
     *
     * @param {Object|boolean} result {smap_id, smap_name, smap_segment}
     */
    setLabel(result) {
        if (result === null || result === undefined) {
            return;
        }
        let id = '', name = '', segment = '';
        if (result) {
            id = result.smap_id;
            name = result.smap_name;
            segment = result.smap_segment;
        }
        document.getElementById(this.obj.getAttribute('hidden_field')).value = id;
        document.getElementById(this.obj.getAttribute('span_field')).textContent = name;
        const segmentObject = document.getElementById('smap_pid_segment');
        if (segmentObject) {
            segmentObject.textContent = segment;
        }
    }
};

/**
 * Визуальный редактор поля формы (Jodit, общая настройка — EnergineEditor).
 *
 * @constructor
 * @param {Element} textarea
 * @param {Form} form
 */
Form.RichEditor = class FormRichEditor {
    constructor(textarea, form) {
        /**
         * The text area element.
         * @type {Element}
         */
        this.textarea = textarea;
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
    }

    /**
     * Перед отправкой формы текст редактора переносится в textarea — только если его меняли.
     */
    onSaveForm() {
        this.textarea.value = (this.editor.value === this.opened) ? this.original : this.editor.value;
    }
};
