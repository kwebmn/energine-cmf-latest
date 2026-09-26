<?php
// Form builder end-to-end: create form, fields of every type, selector values, order, results, delete field, delete form.
// Usage: php8.5 smoke-forms.php [keep]  -- "keep" leaves the form for the public submit/mail test and prints its id
require __DIR__ . '/testlib.php';
$keep = ($argv[1] ?? '') === 'keep';
login();
$FS = '/admin/form-builder/single/formEditor/';

// 1. create form
[$c, $html] = http($FS . 'add/');
check('form add dialog', $c == 200 && clean($html), $html);
$data = formData($html, [
    'frm_forms[form_is_active]' => '1',
    'frm_forms[form_email_adresses]' => MAILBOX,
    'frm_forms_translation[1][form_name]' => 'Тестовая форма',
    'frm_forms_translation[2][form_name]' => 'Тестова форма',
    'frm_forms_translation[1][form_annotation_rtf]' => '<p>Проверка конструктора</p>',
    'frm_forms_translation[2][form_annotation_rtf]' => '<p>Перевірка конструктора</p>',
]);
[$c, $j, $raw] = json($FS . 'save', $data);
$formId = (int)($j['data'] ?? 0);
check("form save (id $formId)", $c == 200 && !empty($j['result']) && $formId > 0, $raw);
$table = "form_$formId";

// 2. fields of every type
$FE = $FS . "$formId/edit-form/";
[$c, $html] = http($FE . 'add/');
check('field add dialog', $c == 200 && clean($html), $html);
// FormConstructor creates the table when the field editor is opened
check("table $table created", (bool)scalar("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?", [$table]));
$types = ['string' => 0, 'email' => 0, 'phone' => 1, 'text' => 1, 'boolean' => 1, 'date' => 1, 'datetime' => 1, 'select' => 1, 'multi' => 1, 'info' => 1];
foreach ($types as $type => $nullable) {
    $post = formData($html, [
        'table_name[field_type]' => $type,
        'table_name[field_is_nullable]' => (string)$nullable,
        'share_lang_tags_translation[1][field_name]' => "Поле $type",
        'share_lang_tags_translation[2][field_name]' => "Поле $type",
    ]);
    [$c, $j, $raw] = json($FE . 'save/', $post);
    check("field $type saved", $c == 200 && is_array($j) && !empty($j['result']), $raw);
}
$cols = array_column(q("SHOW COLUMNS FROM `$table`")->fetchAll(), 'Type', 'Field');
check('columns created: ' . implode(',', array_keys($cols)), count($cols) == 2 + count($types), json_encode($cols));
$tables = q("SHOW TABLES LIKE '{$table}%'")->fetchAll(PDO::FETCH_COLUMN);
check('select/multi tables: ' . implode(',', $tables), count($tables) >= 5, implode(',', $tables));
[$c, $j, $raw] = json($FE . 'get-data/');
$fields = $j['data'] ?? [];
check('fields grid lists ' . count($fields) . ' rows', $c == 200 && count($fields) == 2 + count($types), $raw);
$indexByType = [];
foreach ($fields as $f) $indexByType[$f['field_type_real']] = $f['field_id'];

// 3. selector values for select and multi
foreach (['select', 'multi'] as $type) {
    $idx = $indexByType[$type] ?? null;
    [$c, $html] = http($FE . "$idx/values/");
    $vs = singleTemplate($html, "/values/");
    check("$type values editor", $c == 200 && clean($html) && $vs, $html);
    if (!$vs) continue;
    foreach (['Первый', 'Второй'] as $n => $name) {
        [$c, $addHtml] = http($vs . 'add/');
        $set = [];
        if (preg_match_all('~name="([^"]*\[fk_name\])"~', $addHtml, $m)) foreach (array_unique($m[1]) as $fn) $set[$fn] = "$name $type";
        [$c, $j, $raw] = json($vs . 'save', formData($addHtml, $set));
        check("$type value '$name' saved", $c == 200 && !empty($j['result']), $raw);
    }
    [$c, $j, $raw] = json($vs . 'get-data/');
    check("$type values listed", $c == 200 && count($j['data'] ?? []) >= 2, $raw);
}

// 4. order and deletion of a field
$before = array_keys(q("SHOW COLUMNS FROM `$table`")->fetchAll(PDO::FETCH_UNIQUE));
[$c, $j, $raw] = json($FE . $indexByType['phone'] . '/up/');
$after = array_keys(q("SHOW COLUMNS FROM `$table`")->fetchAll(PDO::FETCH_UNIQUE));
check('field moved up', $c == 200 && $before !== $after, $raw);
[$c, $j, $raw] = json($FE . 'get-data/');
foreach ($j['data'] ?? [] as $f) if ($f['field_type_real'] == 'info') $infoIdx = $f['field_id'];
[$c, $j, $raw] = json($FE . $infoIdx . '/delete/');
$cols2 = array_column(q("SHOW COLUMNS FROM `$table`")->fetchAll(), 'Field');
check('info field deleted', $c == 200 && !preg_grep('/_info$/', $cols2), $raw);

// 5. results page and grid
[$c, $html] = http($FS . "$formId/results/");
check('results page', $c == 200 && clean($html), $html);
$rs = singleTemplate($html, '/results/');
[$c, $j, $raw] = json(($rs ?? BASE . $FS . "$formId/results/") . 'get-data/page-1');
check('results grid', $c == 200 && is_array($j) && !empty($j['result']), $raw);

if ($keep) {
    echo "FORM_ID=$formId\n";
    done('forms');
}

// 6. delete form
[$c, $j, $raw] = json($FS . "$formId/delete/");
$left = q("SHOW TABLES LIKE '{$table}%'")->fetchAll(PDO::FETCH_COLUMN);
check('form deleted with its tables', $c == 200 && !empty($j['result']) && !$left && !scalar('SELECT COUNT(*) FROM frm_forms WHERE form_id = ?', [$formId]), $raw . ' left: ' . implode(',', $left));
$tags = scalar("SELECT COUNT(*) FROM share_lang_tags WHERE ltag_name LIKE ?", ['FIELD_' . strtoupper($table) . '%']);
check("no field translations left ($tags)", $tags == 0);
done('forms');
