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

ScriptLoader.load('Form');

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
        body.append('key', field_name);
        body.append('pid', $('upl_pid').get('value'));
        body.append(field_name, files[0]);

        this.validator.removeError(field);
        return fetch(this.singlePath + 'upload-temp/?json', {method: 'POST', body: body, credentials: 'same-origin'})
            .then(function (response) {
                return response.json();
            })
            .then(function (result) {
                if (result && !result.error) {
                    response_callback(result);
                } else {
                    // отказ сервера (запрещённый тип файла, нет прав, нет места) показывается у поля
                    this.validator.showError(field, (result && result.error_message) || 'ERR_UPLOAD');
                }
            }.bind(this))
            .catch(function (e) {
                this.validator.showError(field, e.message);
            }.bind(this));
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
