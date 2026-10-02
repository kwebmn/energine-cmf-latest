/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivForm]{@link DivForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 * @requires ModalBox
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form', 'ModalBox');

/**
 * Форма раздела: выбор родителя (Form.Label), шаблон содержимого задаёт сегмент и макет, сброс изменённого шаблона,
 * имя раздела на каждом включённом языке обязательно.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var DivForm = class DivForm extends Form {
    constructor(element) {
        super(element);
        this.prepareLabel('list/');

        const contentSelector = this.element.querySelector('#smap_content'),
            layoutSelector = this.element.querySelector('#smap_layout'),
            segmentInput = this.element.querySelector('#smap_segment');

        // шаблон со своим сегментом закрепляет сегмент, со своим макетом — выбирает макет; XML раздела сбрасывается
        contentSelector.addEventListener('change', () => {
            const option = contentSelector.selectedOptions[0];
            let segment, layout;
            if (segmentInput) {
                if ((segment = option.getAttribute('data-segment'))) {
                    segmentInput.readOnly = true;
                    segmentInput.value = segment;
                } else {
                    segmentInput.readOnly = false;
                }
            }
            if ((layout = option.getAttribute('data-layout')) && (layout != '*')) {
                layoutSelector.value = layout;
            }
            this.clearContentXML();
        });
    }

    /**
     * Reset the page content template.
     */
    resetPageContentTemplate() {
        Energine.request(
            this.singlePath + 'reset-templates/' + this.element.querySelector('#smap_id').value + '/',
            null,
            (response) => {
                if (response.result) {
                    const select = this.element.querySelector('#smap_content'),
                        option = select.children[select.selectedIndex],
                        optionText = option.textContent;
                    option.textContent = optionText.substring(0, optionText.lastIndexOf('-'));
                    this.clearContentXML();
                }
            }
        );
    }

    /**
     * Clear XML content.
     */
    clearContentXML() {
        // поле типа «код» на форме раздела одно — XML раздела
        const code = this.form.querySelector('textarea.code');
        if (code) {
            code.value = '';
            code.closest('div.field').classList.add('hidden');
        }
    }

    /**
     * Overridden parent [save]{@link Form#save} action: имя раздела на вкладке языка (раздел на нём не выключен)
     * обязательно.
     */
    save() {
        this.richEditors.forEach((editor) => editor.onSaveForm());
        if (!this.validator.validate()) {
            return false;
        }

        let valid = true;
        this.tabPane.getTabs().forEach((tab) => {
            if (tab.data.lang) {
                const checkbox = tab.pane.querySelector('input[type="checkbox"]');
                if (checkbox) {
                    const disabled = /share_sitemap_translation\[\d+\]\[smap_is_disabled\]/.test(checkbox.name) ? checkbox.checked : false;
                    if (!disabled && tab.pane.querySelector('input[type="text"]').value.trim().length == 0) {
                        valid = false;
                    }
                }
            }
        });

        if (!valid) {
            alert(Energine.translations.get('ERR_NO_DIV_NAME'));
            return false;
        }
        Energine.request(
            this.singlePath + 'save',
            Form.toQueryString(this.form),
            (response) => this.processServerResponse(response)
        );
    }
};
Object.assign(DivForm.prototype, Form.Label);
