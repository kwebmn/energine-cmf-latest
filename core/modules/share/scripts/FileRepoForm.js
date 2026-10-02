/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FileRepoForm]{@link FileRepoForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {Form} from 'Form';

/**
 * Форма файла репозитория: файл уходит во временный файл (upload-temp) сразу при выборе, превью и маленькие
 * изображения строятся по нему; вкладка «Маленькое изображение» включается после загрузки картинки.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} el The main holder element.
 */
export class FileRepoForm extends Form {
    constructor(el) {
        super(el);

        const uploader = this.element.querySelector('#uploader');
        if (uploader) {
            uploader.addEventListener('change', (evt) => this.showPreview(evt));
        }

        /**
         * Thumbnails.
         * @type {Element[]}
         */
        this.thumbs = Array.from(this.element.querySelectorAll('img.thumb'));
        this.element.querySelectorAll('input.thumb').forEach((input) => {
            input.addEventListener('change', (evt) => this.showThumbPreview(evt));
        });
        this.element.querySelectorAll('input.preview').forEach((input) => {
            input.addEventListener('change', (evt) => this.showAltPreview(evt));
        });

        const data = this.element.querySelector('#data');
        if (data && !data.value) {
            this.tabPane.disableTab(1);
        }
    }

    /**
     * Show alternative preview.
     *
     * @param {Object} evt Event.
     */
    showAltPreview(evt) {
        this.showThumbPreview(evt);
    }

    /**
     * Маленькое изображение: картинка уходит во временный файл, превью — по нему.
     *
     * @param {Object} evt Event.
     */
    showThumbPreview(evt) {
        const el = evt.target,
            files = Array.from(el.files || []);

        for (let i = 0; i < files.length; i++) {
            if (files[i].type.match('image.*')) {
                this.xhrFileUpload(el.id, files, (response) => {
                    const previewElement = document.getElementById(el.getAttribute('preview')),
                        dataElement = document.getElementById(el.getAttribute('data'));
                    if (previewElement) {
                        previewElement.classList.remove('hidden');
                        previewElement.setAttribute('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                    }
                    if (dataElement) {
                        dataElement.value = response.tmp_name;
                    }
                });
            }
        }
    }

    /**
     * Generate previews.
     *
     * @param {string} tmpFileName
     */
    generatePreviews(tmpFileName) {
        this.thumbs.forEach((el) => {
            el.classList.remove('hidden');
            el.setAttribute('src', Energine.base + 'resizer/' + 'w' + el.getAttribute('width') + '-h'
                + el.getAttribute('height') + '/' + tmpFileName);
        });
    }

    /**
     * Загрузка файла во временный: fetch с токеном; отказ сервера или чужой ответ — причина у поля.
     *
     * @param {string} field_name id поля файла
     * @param {File[]} files
     * @param {function} response_callback вызывается с ответом сервера, если файл принят
     * @returns {Promise}
     */
    xhrFileUpload(field_name, files, response_callback) {
        const body = new FormData(),
            field = this.element.querySelector('#' + CSS.escape(field_name));
        body.append('csrf_token', Energine.csrf || '');
        body.append('key', field_name);
        body.append('pid', document.getElementById('upl_pid').value);
        body.append(field_name, files[0]);

        this.validator.removeError(field);
        // токен ещё и в заголовке: тело больше post_max_size PHP отбрасывает целиком, и отказ должен
        // объяснить размер, а не «устаревшую форму»
        return fetch(this.singlePath + 'upload-temp/?json', {method: 'POST', body: body, credentials: 'same-origin',
            headers: {'X-CSRF-Token': Energine.csrf || ''}})
            .then((response) => response.text().then((text) => {
                let result = null;
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
            }))
            .catch(() => this.uploadFailed(field, this.uploadFailedText(0)));
    }

    /**
     * Текст неудачной загрузки с кодом ответа.
     *
     * @param {number} status
     * @returns {string}
     */
    uploadFailedText(status) {
        return (Energine.translations.get('ERR_UPLOAD_FAILED') || 'Upload failed') + (status ? ' (HTTP ' + status + ')' : '');
    }

    /**
     * Загрузка не удалась: причина у поля, превью и путь временного файла убраны, поле файла пусто.
     *
     * @param {Element} field
     * @param {string} message
     */
    uploadFailed(field, message) {
        this.validator.showError(field, String(message));
        const isMain = (field.id == 'uploader'),
            preview = isMain ? document.getElementById('preview') : document.getElementById(field.getAttribute('preview')),
            data = isMain ? document.getElementById('data') : document.getElementById(field.getAttribute('data'));
        if (preview) {
            preview.removeAttribute('src');
            preview.classList.add('hidden');
        }
        if (data) {
            data.value = '';
        }
        field.value = '';
    }

    /**
     * Show preview.
     *
     * @param {Object} evt Event.
     */
    showPreview(evt) {
        const previewElement = document.getElementById('preview');
        previewElement.removeAttribute('src');
        this.thumbs.forEach((thumb) => {
            thumb.removeAttribute('src');
            thumb.classList.add('hidden');
        });
        previewElement.setAttribute('src', Energine.base + 'images/loading.gif');

        const files = Array.from(evt.target.files || []);
        for (let i = 0; i < files.length; i++) {
            this.xhrFileUpload('uploader', files, (response) => {
                document.getElementById('upl_name').value = response.name;
                document.getElementById('upl_filename').value = response.name;
                document.getElementById('data').value = response.tmp_name;
                document.getElementById('upl_title').value = response.name.split('.')[0];

                if (response.type.match('image.*')) {
                    previewElement.removeAttribute('src');
                    previewElement.classList.add('hidden');
                    previewElement.setAttribute('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                    this.generatePreviews(response.tmp_name);
                    this.tabPane.enableTab(1);
                } else {
                    previewElement.setAttribute('src', Energine['static'] + 'images/icons/icon_undefined.gif');
                }
                previewElement.classList.remove('hidden');
            });
        }
    }

    /**
     * Overridden parent [buildSaveURL]{@link Form#buildSaveURL} method.
     *
     * @returns {string}
     */
    buildSaveURL() {
        return Energine.base + this.form.getAttribute('action');
    }
};
