/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FileRepoForm]{@link FileRepoForm}</li>
 * </ul>
 *
 * @requires Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.0.0
 */

ScriptLoader.load('MooCompat', 'Form');

/**
 * FileRepoForm
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var FileRepoForm = new Class(/** @lends FileRepoForm# */{
    Extends:Form,

    // constructor
    initialize:function (el) {
        this.parent(el);

        var uploader = this.element.getElementById('uploader');
        if (uploader) {
            uploader.addEvent('change', this.showPreview.bind(this))
        }

        /**
         * Thumbnails.
         * @type {Elements}
         */
        this.thumbs = this.element.getElements('img.thumb');
        if (this.thumbs) {
            this.element.getElements('input.thumb').addEvent('change', this.showThumbPreview.bind(this));

            var altPreview = this.element.getElements('input.preview');
            if (altPreview) {
                altPreview.addEvent('change', this.showAltPreview.bind(this));
            }
        }

        var data = this.element.getElementById('data');
        if(data && !(data.get('value'))) {
            this.tabPane.disableTab(1);
        }
    },

    /**
     * Event handler. Show alternative preview.
     *
     * @function
     * @public
     * @param {Object} evt Event.
     */
    showAltPreview:function (evt) {
       this.showThumbPreview(evt);
    },

    /**
     * Event handler. Show thumbnail.
     *
     * @function
     * @public
     * @param {Object} evt Event.
     */
    showThumbPreview:function (evt) {
        var el = $(evt.target);
        var files = Array.from(el.files || []);

        for (var i = 0; i < files.length; i++) {
            if (files[i].type.match('image.*')) {
                this.xhrFileUpload(
                    el.getProperty('id'),
                    files,
                    function (response) {
                        var previewElement = $(el.getProperty('preview')),
                            dataElement = $(el.getProperty('data'));
                        if (previewElement) {
                            previewElement.removeClass('hidden')
                                .setProperty('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                        }
                        if (dataElement) {
                            dataElement.set('value', response.tmp_name);
                        }
                    }
                );
            }
        }
    },

    /**
     * Generate previews.
     *
     * @function
     * @public
     * @param {string} tmpFileName File name.
     */
    generatePreviews:function (tmpFileName) {
        if (this.thumbs)
            this.thumbs.each(function (el) {
                el.removeClass('hidden');
                el.setProperty('src', Energine.base +'resizer/'+ 'w' + el.getProperty('width') + '-h' + el.getProperty('height') + '/' + tmpFileName);
            });
    },

    /**
     * XMLHttpRequest for uploading the file.
     *
     * @param {string} field_name Field name.
     * @param {} files
     * @param {} response_callback
     * @returns {*|XMLHttpRequestEventTarget}
     */
    xhrFileUpload: function (field_name, files, response_callback) {
        var body = new FormData(),
            field = this.element.getElementById(field_name);
        body.append('csrf_token', Energine.csrf || '');
        body.append('key', field_name);
        body.append('pid', $('upl_pid').get('value'));
        body.append(field_name, files[0]);

        this.validator.removeError(field);
        // токен ещё и в заголовке: тело больше post_max_size PHP отбрасывает целиком, и отказ должен
        // объяснить размер, а не «устаревшую форму»
        return fetch(this.singlePath + 'upload-temp/?json', {method: 'POST', body: body, credentials: 'same-origin',
            headers: {'X-CSRF-Token': Energine.csrf || ''}})
            .then(function (response) {
                return response.text().then(function (text) {
                    var result = null;
                    try {
                        result = JSON.parse(text);
                    } catch (e) {
                    }
                    if (result && !result.error && result.tmp_name) {
                        response_callback(result);
                        return;
                    }
                    // отказ сервера (запрещённый тип файла, размер, нет прав, устаревшая форма) или ответ
                    // не сервера сайта (страница прокси) — причина у поля
                    this.uploadFailed(field, (result && (result.error_message
                        || (result.errors && result.errors[0] && result.errors[0].message)))
                        || this.uploadFailedText(response.status));
                }.bind(this));
            }.bind(this))
            .catch(function () {
                this.uploadFailed(field, this.uploadFailedText(0));
            }.bind(this));
    },

    /**
     * Общий текст неудачной загрузки.
     * @param {number} status код ответа (0 — ответа нет)
     * @returns {string}
     */
    uploadFailedText: function (status) {
        return (Energine.translations.get('ERR_UPLOAD_FAILED') || 'Upload failed') + (status ? ' (HTTP ' + status + ')' : '');
    },

    /**
     * Загрузка не состоялась: причина у поля (Validator выводит её текстом), а форма забывает файл:
     * превью и путь прошлой загрузки сбрасываются, тот же файл можно выбрать снова.
     *
     * @param {Element} field поле файла
     * @param {string} message
     */
    uploadFailed: function (field, message) {
        this.validator.showError(field, String(message));
        var isMain = (field.get('id') == 'uploader'),
            preview = isMain ? $('preview') : $(field.getProperty('preview')),
            data = isMain ? $('data') : $(field.getProperty('data'));
        if (preview) {
            preview.removeProperty('src').addClass('hidden');
        }
        if (data) {
            data.set('value', '');
        }
        field.value = '';
    },

    /**
     * Event handler. Show preview.
     * @param {Object} evt Event.
     */
    showPreview:function (evt) {
        var previewElement = document.getElementById('preview');
        previewElement.removeProperty('src');

        if (this.thumbs) {
            this.thumbs.removeProperty('src').addClass('hidden');
        }
        previewElement.setProperty('src', Energine.base + 'images/loading.gif');

        var files = Array.from($(evt.target).files || []);
        var enableTab = this.tabPane.enableTab.pass(1, this.tabPane);
        var generatePreviews = this.generatePreviews.bind(this);
        for (var i = 0; i < files.length; i++) {
            this.xhrFileUpload('uploader', files, function (response) {
                document.getElementById('upl_name').set('value', response.name);
                document.getElementById('upl_filename').set('value', response.name);
                //document.getElementById('file_type').set('value', theFile.type);
                document.getElementById('data').set('value', response.tmp_name);
                document.getElementById('upl_title').set('value', response.name.split('.')[0]);

                if (response.type.match('image.*')) {
                    previewElement.removeProperty('src').addClass('hidden');
                    previewElement.setProperty('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                    generatePreviews(response.tmp_name);
                    enableTab();
                } else {
                    previewElement.setProperty('src', Energine['static'] + 'images/icons/icon_undefined.gif');
                }
                previewElement.removeClass('hidden');
            });
        }
    },

    /**
     * Overridden parent [save]{@link Form#buildSaveURL} action.
     *
     * @function
     * @public
     * @return {string}
     */
    buildSaveURL: function() {
        return Energine.base + this.form.getProperty('action');
    }
});
