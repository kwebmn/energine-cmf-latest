ScriptLoader.load('ValidForm', 'ckeditor/ckeditor');

/**
 * Post form on the blogs page: validation and a simple visual editor.
 * The file repository plugins of the admin editor are left out, post authors are site users.
 */
var BlogForm = new Class({
    Extends: ValidForm,

    initialize: function (element) {
        this.parent(element);
        this.editors = [];
        if (!this.form) {
            return;
        }
        this.form.getElements('textarea.richEditor').each(function (textarea) {
            var editor = CKEDITOR.replace(textarea.get('id'), {
                language: Energine.lang,
                removePlugins: 'energineimage,energinevideo,energinefile',
                toolbar: [
                    {name: 'basicstyles', items: ['Bold', 'Italic', 'Underline', 'Strike', '-', 'RemoveFormat']},
                    {name: 'paragraph', items: ['NumberedList', 'BulletedList', 'Blockquote']},
                    {name: 'links', items: ['Link', 'Unlink']},
                    {name: 'insert', items: ['Image', 'Table']},
                    {name: 'document', items: ['Source']}
                ]
            });
            // the validator checks the textarea on submit before the editor copies its text there
            editor.on('change', function () {
                editor.updateElement();
            });
            this.editors.push(editor);
        }, this);
    },

    validateForm: function (event) {
        this.editors.each(function (editor) {
            editor.updateElement();
        });
        return this.parent(event);
    }
});
