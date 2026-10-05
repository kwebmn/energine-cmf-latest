<?php
// Чистота шаблонов XSLT (UI-подпроект 4):
//  1. нет классов Bootstrap без стилей (form-group, form-control, btn btn-*, col-sm-*);
//  2. поле ввода <input class="…"> с FORM_ELEMENT_ATTRIBUTES пишется один раз — в шаблоне field-input (fields.xslt),
//     шаблоны полей его вызывают, а не повторяют.
require __DIR__ . '/testlib.php';

$files = array_merge(glob(ROOT . '/core/modules/*/transformers/*.xslt'), glob(ROOT . '/site/modules/*/transformers/*.xslt'));
$boot = [];
foreach ($files as $f) {
    foreach (file($f) as $i => $l) {
        if (preg_match('~\b(form-group|form-control|btn btn-|col-sm-\d)~', $l)) $boot[] = str_replace(ROOT . '/', '', $f) . ':' . ($i + 1);
    }
}
check('нет классов Bootstrap', !$boot, implode(' ', $boot));

$fields = file_get_contents(ROOT . '/core/modules/share/transformers/fields.xslt');
$n = preg_match_all('~<input class="[^"]*">\s*<xsl:call-template name="FORM_ELEMENT_ATTRIBUTES"/>~', $fields);
check('поле ввода с FORM_ELEMENT_ATTRIBUTES написано один раз (шаблон field-input)', $n === 1 && str_contains($fields, '<xsl:template name="field-input">'),
    "повторов: $n");
done('xslt-lint');
