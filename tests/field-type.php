<?php
// enum FieldType (надёжность, этап 4): перечисление типов полей с теми же значениями, что константы
// FieldDescription::FIELD_TYPE_* (константы остаются псевдонимами); FieldDescription::setType() принимает
// FieldType или строку и отвергает неизвестный тип ошибкой разработчика ERR_DEV_UNKNOWN_FIELD_TYPE — опечатка в
// type="…" конфига видна сразу, а не странным полем в форме.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
require_once ROOT . '/core/modules/share/gears/Registry.php'; // функция E()
require_once ROOT . '/core/modules/share/gears/Utils.php';    // функция translate() — её зовёт конструктор FieldDescription
\Energine\share\gears\Primitive::setConfig(include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php'));
defined('HTDOCS_DIR') || define('HTDOCS_DIR', WEB);

use Energine\share\gears\FieldDescription;

if (!enum_exists('Energine\share\gears\FieldType')) {
    check('перечисление Energine\share\gears\FieldType есть', false);
    done('field-type');
}
$enum = 'Energine\share\gears\FieldType';
$constants = array_filter((new ReflectionClass(FieldDescription::class))->getConstants(), fn($v, $k) => str_starts_with($k, 'FIELD_TYPE_'), ARRAY_FILTER_USE_BOTH);
$missing = [];
foreach ($constants as $name => $value) {
    if ($enum::tryFrom($value) === null) $missing[] = "$name=$value";
}
check('у каждой константы FIELD_TYPE_* есть вариант перечисления с тем же значением (' . count($constants) . ')', !$missing && count($constants) >= 25, implode(', ', $missing));
check('у перечисления нет лишних вариантов', count($enum::cases()) === count($constants), count($enum::cases()) . ' vs ' . count($constants));
check('неизвестный тип — не вариант', $enum::tryFrom('strng') === null);

$fd = new FieldDescription('claude_field');
$accepted = true;
foreach ($constants as $value) {
    try { $fd->setType($value); } catch (\Throwable $e) { $accepted = false; }
}
check('все прежние строковые типы принимаются setType()', $accepted);
$fd->setType($enum::STRING);
check('setType(FieldType::STRING) — тип «string»', $fd->getType() === FieldDescription::FIELD_TYPE_STRING, var_export($fd->getType(), true));
$e = null;
try { $fd->setType('strng'); } catch (\Throwable $x) { $e = $x; }
$details = $e instanceof \Energine\share\gears\SystemException ? (array)$e->getCustomMessage() : [];
check('setType(«strng») — ошибка разработчика ERR_DEV_UNKNOWN_FIELD_TYPE с именем поля и значением',
    $e && str_contains($e->getMessage() . json_encode($details, JSON_UNESCAPED_UNICODE), 'ERR_DEV_UNKNOWN_FIELD_TYPE')
        && in_array('claude_field', $details, true) && in_array('strng', $details, true),
    $e ? get_class($e) . ': ' . $e->getMessage() . ' ' . json_encode($details, JSON_UNESCAPED_UNICODE) : 'исключения нет');

// типы колонок базы отображаются на визуальные полностью: редкий тип колонки — не ошибка формы
$fd2 = new FieldDescription('claude_blob');
$fd2->setSystemType(\Energine\share\gears\QAL::COLTYPE_BLOB);
check('колонка BLOB — текстовое поле, а не неизвестный тип', $fd2->getType() === FieldDescription::FIELD_TYPE_TEXT, var_export($fd2->getType(), true));

// конфиги компонентов: каждый type="…" у <field> — известный тип (опечатка сломала бы форму ошибкой разработчика)
$bad = [];
foreach (['core', 'site'] as $dir) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(ROOT . "/$dir", FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        if (substr((string)$file, -4) !== '.xml') continue;
        if (preg_match_all('~<field\b[^>]*\btype="([^"]*)"~', (string)file_get_contents((string)$file), $m)) {
            foreach ($m[1] as $t) {
                if ($enum::tryFrom($t) === null) $bad[] = substr((string)$file, strlen(ROOT) + 1) . ": $t";
            }
        }
    }
}
check('в конфигах компонентов (core, site) нет неизвестных type="…" у полей', !$bad, implode(' | ', array_unique($bad)));
done('field-type');
