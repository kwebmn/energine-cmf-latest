/**
 * @file Общая настройка визуального редактора Jodit для форм админки (Form.RichEditor) и правки
 * прямо на странице (PageEditor): язык, панель инструментов, кнопки «Картинка из репозитория»
 * и «Файл из репозитория». Встроенные загрузчик и файловый браузер Jodit выключены — файлы
 * приходят только из репозитория Energine.
 * Чистый JavaScript, без MooTools.
 *
 * @requires jodit/jodit.min
 * @requires ModalBox
 */

import 'jodit/jodit.min';
import {Energine} from 'Energine';
import {ModalBox} from 'ModalBox';

export const EnergineEditor = {
    /**
     * Подписи своих кнопок (те же, что были у прежних кнопок вставки из медиа-библиотеки).
     */
    labels: {
        ru: {image: 'Вставка изображения из медиа-библиотеки', file: 'Вставка файла из медиа-библиотеки',
            link: 'Ссылка на страницу сайта',
            history: 'История', historyTip: 'История текста: прежние версии и возврат любой из них'},
        ua: {image: 'Додати зображення з медіа-бібліотеки', file: 'Додати файл з медіа-бібліотеки',
            link: 'Посилання на сторінку сайту',
            history: 'Історія', historyTip: 'Історія тексту: попередні версії та повернення будь-якої з них'},
        en: {image: 'Insert an image from the media library', file: 'Insert a file from the media library',
            link: 'Link to a page of this site',
            history: 'History', historyTip: 'Text history: previous versions and restoring any of them'}
    },

    /**
     * Подпись кнопки на языке страницы.
     * @param {string} name
     * @returns {string}
     */
    label: function (name) {
        return (EnergineEditor.labels[Energine.lang] || EnergineEditor.labels.en)[name] || EnergineEditor.labels.en[name] || name;
    },

    /**
     * Встроенные модули Jodit, которые не нужны: свои загрузка и выбор файлов, видео, печать и т. п.
     * wrap-nodes при открытии оборачивает текст вне абзаца в <p> — сохранённый текст менялся без правки.
     */
    disabledPlugins: ['about', 'ai-assistant', 'drag-and-drop', 'drag-and-drop-element', 'file', 'image',
        'image-processor', 'image-properties', 'media', 'powered-by-jodit', 'print', 'speech-recognize', 'video',
        'wrap-nodes'],

    /**
     * Существующая разметка остаётся как есть, как у прежнего редактора (allowedContent: true):
     * карты во iframe, скрипты виджетов, пустые значки <i class="fa …">, <b>, ссылки target="_blank".
     * Обработчики событий в атрибутах и ссылки javascript: Jodit по-прежнему убирает.
     */
    cleanHTML: {
        denyTags: false,
        removeEmptyElements: false,
        replaceOldTags: false,
        fillEmptyParagraph: false,
        safeLinksTarget: false,
        sandboxIframesInContent: false
    },

    /**
     * Создать редактор.
     *
     * @param {Element|string} element textarea формы или элемент для правки на странице
     * @param {Object} options singlePath — адрес компонента для окон репозитория; jodit — дополнительные
     *                         настройки Jodit (например, inline для правки на странице); extraButtons — свои кнопки
     *                         в конец панели (например, «История» у правки на странице)
     * @returns {Jodit}
     */
    make: function (element, options) {
        options = options || {};
        Energine.loadCSS('../scripts/jodit/jodit.min.css');
        var labels = EnergineEditor.labels[Energine.lang] || EnergineEditor.labels.en,
            singlePath = options.singlePath || '';
        var config = Object.assign({
            language: Energine.lang,
            toolbarAdaptive: false,
            showCharsCounter: false,
            showWordsCounter: false,
            showXPathInStatusbar: false,
            askBeforePasteHTML: false,
            askBeforePasteFromWord: false,
            disablePlugins: EnergineEditor.disabledPlugins,
            cleanHTML: EnergineEditor.cleanHTML,
            uploader: {insertImageAsBase64URI: false},
            // режим исходника — простое поле, без Ace и js-beautify с внешнего CDN
            sourceEditor: 'area',
            beautifyHTML: false,
            buttons: [
                'source', '|',
                'bold', 'italic', 'underline', 'strikethrough', 'eraser', '|',
                'ul', 'ol', 'outdent', 'indent', 'align', '|',
                'paragraph', '|',
                'link', 'table',
                {
                    name: 'energineImage', icon: 'image', tooltip: labels.image,
                    exec: function (editor) { EnergineEditor.insertImage(editor, singlePath); }
                },
                {
                    name: 'energineFile', icon: 'file', tooltip: labels.file,
                    exec: function (editor) { EnergineEditor.insertFile(editor, singlePath); }
                },
                {
                    name: 'energineLink', icon: 'link', tooltip: labels.link,
                    exec: function (editor) { EnergineEditor.insertPageLink(editor, singlePath); }
                },
                '|', 'undo', 'redo'
            ].concat(options.extraButtons || [])
        }, options.jodit || {});
        return Jodit.make(/** @type {HTMLElement|string} */ (element), config);
    },

    /**
     * Значение для атрибута и текста HTML.
     * @param {string} value
     * @returns {string}
     */
    /**
     * Значение для сохранения: пустой текст (Jodit оставляет от стёртого текста абзац <p><br></p>) — пустая строка.
     * Картинки, вставки и таблицы — не пусто, даже без текста.
     * @param {string} value
     * @returns {string}
     */
    clean: function (value) {
        // разбор — в отдельном документе (DOMParser): разметка текста (onerror картинки) в админке не исполняется
        const box = new DOMParser().parseFromString('<body>' + String(value || '') + '</body>', 'text/html').body;
        return (box.textContent.replace(/[\s\u00a0\u200b]+/g, '') === ''
            && !box.querySelector('img, iframe, video, audio, object, embed, table, hr, input, svg')) ? '' : String(value);
    },

    escape: function (value) {
        return String(value === undefined || value === null ? '' : value)
            .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    },

    /**
     * Адрес файла репозитория: относительный путь — от медиа-сервера.
     * @param {string} path
     * @returns {string}
     */
    mediaUrl: function (path) {
        return /^https?:\/\//i.test(path) ? path : Energine.media + path;
    },

    /**
     * Картинка из репозитория: библиотека файлов, затем менеджер картинок (размер, выравнивание,
     * отступы, alt), затем вставка <img>.
     */
    insertImage: function (editor, singlePath) {
        var selection = editor.s.save();
        ModalBox.open({
            url: singlePath + 'file-library/',
            onClose: function (imageData) {
                if (!imageData) {
                    return;
                }
                ModalBox.open({
                    url: singlePath + 'imagemanager/',
                    extraData: imageData,
                    onClose: function (image) {
                        if (!image) {
                            return;
                        }
                        var style = '';
                        ['margin-left', 'margin-right', 'margin-top', 'margin-bottom'].forEach(function (prop) {
                            if (image[prop] && image[prop] != 0) {
                                style += prop + ':' + parseInt(image[prop], 10) + 'px;';
                            }
                        });
                        var html = '<img src="' + EnergineEditor.escape(EnergineEditor.mediaUrl(image.filename)) + '"'
                            + ' width="' + EnergineEditor.escape(image.width) + '"'
                            + ' height="' + EnergineEditor.escape(image.height) + '"'
                            + (image.align ? ' align="' + EnergineEditor.escape(image.align) + '"' : '')
                            + ' alt="' + EnergineEditor.escape(image.alt) + '"'
                            + (style ? ' style="' + style + '"' : '') + '/>';
                        editor.s.restore(selection);
                        editor.s.insertHTML(html);
                    }
                });
            }
        });
    },

    /**
     * Файл из репозитория: ссылка на выделенное (с его оформлением) или, если выделения нет, ссылка с названием файла.
     */
    /**
     * Ссылка на страницу сайта: окно дерева разделов (page-tree/list/); адрес — Energine.root (с языком) и путь
     * страницы, текст — выделение (без блочной разметки) или название страницы. Окно без выбора ничего не вставляет.
     *
     * @param {Jodit} editor
     * @param {string} singlePath
     */
    insertPageLink: function (editor, singlePath) {
        var html = EnergineEditor.selectionText(editor),
            selection = editor.s.save();
        ModalBox.open({
            url: singlePath + 'page-tree/list/',
            onClose: function (page) {
                if (!page || typeof page.smap_segment !== 'string') {
                    return;
                }
                editor.s.restore(selection);
                editor.s.insertHTML('<a href="' + EnergineEditor.escape(Energine.root + page.smap_segment) + '">'
                    + (html || EnergineEditor.escape(page.smap_name || page.smap_segment)) + '</a>');
            }
        });
    },

    /**
     * Выделение как текст будущей ссылки: с оформлением (жирный, курсив) — разметка берётся до сохранения
     * выделения маркерами; абзацы, списки и ссылки внутри <a> недопустимы — тогда только текст выделения.
     *
     * @param {Jodit} editor
     * @returns {string} HTML или пустая строка, если ничего не выделено
     */
    selectionText: function (editor) {
        var range = editor.s.range, html = '';
        if (range && !range.collapsed) {
            var box = document.createElement('div');
            box.appendChild(range.cloneContents());
            html = box.querySelector('p, div, ul, ol, li, table, h1, h2, h3, h4, h5, h6, blockquote, pre, a')
                ? EnergineEditor.escape(range.toString()) : box.innerHTML;
        }
        return html;
    },

    insertFile: function (editor, singlePath) {
        var html = EnergineEditor.selectionText(editor),
            selection = editor.s.save();
        ModalBox.open({
            url: singlePath + 'file-library/',
            onClose: function (data) {
                if (!data) {
                    return;
                }
                editor.s.restore(selection);
                editor.s.insertHTML('<a href="' + EnergineEditor.escape(EnergineEditor.mediaUrl(data['upl_path'])) + '">'
                    + (html || EnergineEditor.escape(data['upl_title'])) + '</a>');
            }
        });
    }
};
