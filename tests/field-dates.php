<?php
// Поля даты — встроенные поля браузера (этап 7): input type="date" присылает ГГГГ-ММ-ДД, type="datetime-local" —
// ГГГГ-ММ-ДДTЧЧ:ММ (дата и время через T). Шаблон поля (его проверяют и сервер, и валидатор формы в браузере)
// принимает и это, и прежнюю запись через пробел. База (MariaDB) принимает обе записи.
// Ядро не поднимается: перевод подписей поля здесь не нужен — translate() возвращает константу.
function translate($const) { return $const; }
require dirname(__DIR__) . '/vendor/autoload.php';

use Energine\share\gears\FieldDescription;

$fail = 0;
function check($label, $got, $want) {
    global $fail;
    $ok = $got === $want;
    echo ($ok ? 'OK   ' : 'FAIL '), $label, ($ok ? '' : ': ожидалось ' . var_export($want, true) . ', получено ' . var_export($got, true)), "\n";
    if (!$ok) $fail++;
}
function field($type, $nullable) {
    $f = new FieldDescription('claude_date');
    $f->setProperty('nullable', $nullable);
    $f->setType($type);
    return $f;
}

$dt = field(FieldDescription::FIELD_TYPE_DATETIME, false);
check('datetime: значение datetime-local (через T)', $dt->validate('2026-10-01T12:30'), true);
check('datetime: значение datetime-local с секундами', $dt->validate('2026-10-01T12:30:15'), true);
check('datetime: прежняя запись через пробел', $dt->validate('2026-10-01 12:30'), true);
check('datetime: дата без времени — нет', $dt->validate('2026-10-01'), false);
check('datetime: обязательное пустое — нет', $dt->validate(''), false);
check('datetime: необязательное пустое — да', field(FieldDescription::FIELD_TYPE_DATETIME, true)->validate(''), true);
check('datetime: необязательное через T — да', field(FieldDescription::FIELD_TYPE_DATETIME, true)->validate('2026-10-01T12:30'), true);

$d = field(FieldDescription::FIELD_TYPE_DATE, false);
check('date: значение type="date"', $d->validate('1990-02-03'), true);
check('date: дата со временем — нет', $d->validate('1990-02-03T10:00'), false);
check('date: необязательное пустое — да', field(FieldDescription::FIELD_TYPE_DATE, true)->validate(''), true);

echo "== field-dates failures: $fail\n";
exit($fail ? 1 : 0);
