/**
 * @file Общая настройка визуального редактора Jodit для форм админки (Form.RichEditor) и правки
 * прямо на странице (PageEditor): язык, панель инструментов, кнопки «Картинка из репозитория»
 * и «Файл из репозитория». Встроенные загрузчик и файловый браузер Jodit выключены — файлы
 * приходят только из репозитория Energine.
 *
 * @requires jodit/jodit.min
 * @requires ModalBox
 */

ScriptLoader.load('jodit/jodit.min', 'ModalBox');

var EnergineEditor = {
    /**
     * Подписи своих кнопок (раньше — языковые файлы плагинов CKEditor energineimage и energinefile).
     */
    labels: {
        ru: {image: 'Вставка изображения из медиа-библиотеки', file: 'Вставка файла из медиа-библиотеки'},
        ua: {image: 'Додати зображення з медіа-бібліотеки', file: 'Додати файл з медіа-бібліотеки'},
        en: {image: 'Insert an image from the media library', file: 'Insert a file from the media library'}
    },

    /**
     * Встроенные модули Jodit, которые не нужны: свои загрузка и выбор файлов, видео, печать и т. п.
     */
    disabledPlugins: ['about', 'ai-assistant', 'drag-and-drop', 'drag-and-drop-element', 'file', 'image',
        'image-processor', 'image-properties', 'media', 'powered-by-jodit', 'print', 'speech-recognize', 'video'],

    cssLoaded: false,

    /**
     * Создать редактор.
     *
     * @param {Element|string} element textarea формы или элемент для правки на странице
     * @param {Object} options singlePath — адрес компонента для окон репозитория; jodit — дополнительные
     *                         настройки Jodit (например, inline для правки на странице)
     * @returns {Jodit}
     */
    make: function (element, options) {
        options = options || {};
        if (!EnergineEditor.cssLoaded) {
            Asset.css('../scripts/jodit/jodit.min.css');
            EnergineEditor.cssLoaded = true;
        }
        var labels = EnergineEditor.labels[Energine.lang] || EnergineEditor.labels.en,
            singlePath = options.singlePath || '';
        var config = Object.merge({
            language: Energine.lang,
            toolbarAdaptive: false,
            showCharsCounter: false,
            showWordsCounter: false,
            showXPathInStatusbar: false,
            askBeforePasteHTML: false,
            askBeforePasteFromWord: false,
            disablePlugins: EnergineEditor.disabledPlugins,
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
                '|', 'undo', 'redo'
            ]
        }, options.jodit || {});
        return Jodit.make(element, config);
    },

    /**
     * Значение для атрибута и текста HTML.
     * @param {string} value
     * @returns {string}
     */
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
                    url: singlePath + 'imagemanager',
                    extraData: imageData,
                    onClose: function (image) {
                        if (!image) {
                            return;
                        }
                        var style = '';
                        ['margin-left', 'margin-right', 'margin-top', 'margin-bottom'].each(function (prop) {
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
     * Файл из репозитория: ссылка на выделенный текст или, если выделения нет, ссылка с названием файла.
     */
    insertFile: function (editor, singlePath) {
        var selection = editor.s.save(),
            text = editor.s.sel ? editor.s.sel.toString() : '';
        ModalBox.open({
            url: singlePath + 'file-library/',
            onClose: function (data) {
                if (!data) {
                    return;
                }
                editor.s.restore(selection);
                editor.s.insertHTML('<a href="' + EnergineEditor.escape(EnergineEditor.mediaUrl(data['upl_path'])) + '">'
                    + EnergineEditor.escape(text || data['upl_title']) + '</a>');
            }
        });
    }
};
