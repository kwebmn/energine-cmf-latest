/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ImageManager]{@link ImageManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 * @requires ModalBox
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

import {Energine} from 'Energine';
import {Form} from 'Form';
import {ModalBox} from 'ModalBox';

/**
 * Окно картинки при вставке в текст: данные картинки — из окна-родителя, размеры (по пропорции), выравнивание,
 * отступы, подпись; «Вставить» возвращает картинку.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
export class ImageManager extends Form {
    constructor(element) {
        super(element);
        /**
         * Image data.
         * @type {Object}
         */
        this.image = {};
        /**
         * Defines whether the ratio will be saved.
         * @type {boolean}
         */
        this.saveRatio = false;
        /**
         * Image margins.
         * @type {string[]}
         */
        this.imageMargins = ['margin-left', 'margin-right', 'margin-top', 'margin-bottom'];

        this.field('filename').disabled = true;
        const imageData = ModalBox.getExtraData();
        if (imageData != null) {
            this.image = imageData;
            this.updateForm();
        }

        this.field('width').addEventListener('change', (event) => this.checkRatio(event));
        this.field('height').addEventListener('change', (event) => this.checkRatio(event));
    }

    /**
     * Поле окна по id.
     *
     * @param {string} id
     * @returns {Element}
     */
    field(id) {
        return document.getElementById(id);
    }

    /**
     * Ширина меняет высоту по пропорции (и наоборот); путь — через resizer, превью следом.
     *
     * @param {Object} event
     */
    checkRatio(event) {
        const target = event.target.id,
            oldWidth = this.image.upl_width,
            oldHeight = this.image.upl_height;
        let width = parseInt(this.field('width').value, 10),
            height = parseInt(this.field('height').value, 10),
            src;

        if (oldWidth != width || oldHeight != height) {
            if (target == 'width') {
                height = Math.round((oldHeight * width) / oldWidth);
            } else {
                width = Math.round((oldWidth * height) / oldHeight);
            }
            this.field('width').value = width;
            this.field('height').value = height;
            this.field('filename').value = src = Energine.resizer + 'w' + width + '-h' + height + '/' + this.image['upl_path'];
            this.field('thumbnail').setAttribute('src', src);
        }
    }

    /**
     * Open the image library.
     */
    openImageLib() {
        ModalBox.open({
            url: this.singlePath + 'file-library/',
            'post': JSON.stringify(this.image),
            onClose: (result) => {
                if (result) {
                    this.image = result;
                    this.updateForm();
                }
                window.focus();
            }
        });
    }

    /**
     * Update the form.
     */
    updateForm() {
        this.field('filename').value = this.image['upl_path'];
        this.field('thumbnail').src = Energine.media + this.image['upl_path'];
        this.field('width').value = this.image['upl_width'] || 0;
        this.field('height').value = this.image['upl_height'] || 0;
        this.field('align').value = this.image.align || '';

        this.imageMargins.forEach((propertyName) => {
            this.field(propertyName).value = this.field(propertyName).value || this.image[propertyName] || '0';
        });

        const alt = this.field('alt');
        if (!alt.value) {
            alt.value = this.image['upl_title'] || '';
        }
    }

    /**
     * Insert the image.
     */
    insertImage() {
        if (this.field('filename').value) {
            this.image.filename = this.field('filename').value;
            this.image.width = parseInt(this.field('width').value) || '';
            this.image.height = parseInt(this.field('height').value) || '';
            this.image.align = this.field('align').value || '';
            this.imageMargins.forEach((propertyName) => {
                this.image[propertyName] = parseInt(this.field(propertyName).value) || 0;
            });
            this.image.alt = this.field('alt').value;
            this.image.thumbnail = this.field('thumbnail').src;
            ModalBox.setReturnValue(this.image);
        }
        this.close();
    }
};
