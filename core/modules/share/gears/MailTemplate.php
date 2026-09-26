<?php

namespace Energine\share\gears;

class MailTemplate {

    use DBWorker;

    protected $name;
    protected $lang_id;
    protected $data = [];
    protected $template = [];
    /**
     * Macros whose values are HTML already: they go into the HTML body as they are.
     * @var string[]
     */
    protected $htmlKeys = [];

    public function __construct($name, $data = [], $lang_id = null) {
        $this->name = $name;
        $this->lang_id = ($lang_id) ? $lang_id : E()->getLanguage()->getCurrent();
        $this->loadTemplate();
        $this->data = $data;
    }

    protected function loadTemplate() {

        $res = $this->dbh->select(
            'select tt.template_subject, tt.template_body, tt.template_body_rtf
            from mail_templates t
            left join mail_templates_translation tt on t.template_id = tt.template_id and tt.lang_id = %s
            where t.template_sysname = %s and t.template_is_active = 1',
            $this->lang_id,
            $this->name
        );

        if (empty($res)) {
            throw new SystemException('ERR_NO_MAIL_TEMPLATE', SystemException::ERR_CRITICAL, $this->name);
        }

        $this->template = ($res) ? ($res[0]) : array();
    }

    /**
     * Values of these macros are inserted into the HTML body without escaping.
     *
     * @param string[] $keys Macro names without brackets, e.g. ['items'].
     * @return MailTemplate
     */
    public function setHTMLKeys(array $keys) {
        $this->htmlKeys = $keys;
        return $this;
    }

    /**
     * Replace the macros [key] with their values.
     * One pass: a value (it may come from a visitor) is never searched for other macros.
     * In HTML a value is plain text: it is escaped and keeps its line breaks.
     *
     * @param string $string Template text.
     * @param bool $html The text is the HTML body.
     * @return string
     */
    protected function parse($string, $html = false) {
        $replacements = [];
        foreach ($this->data as $key => $value) {
            $value = is_array($value) ? implode(', ', array_filter($value, 'is_scalar')) : (string)$value;
            if ($html && !in_array($key, $this->htmlKeys, true)) {
                $value = nl2br(htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'), false);
            }
            $replacements['[' . $key . ']'] = $value;
        }
        return strtr($string, $replacements);
    }

    public function getSubject() {
        return (!empty($this->template['template_subject'])) ? $this->parse($this->template['template_subject']) : '';
    }

    public function getBody() {
        return (!empty($this->template['template_body'])) ? $this->parse($this->template['template_body']) : '';
    }

    public function getHTMLBody() {
        return (!empty($this->template['template_body_rtf'])) ? $this->parse($this->template['template_body_rtf'], true) : '';
    }
}
