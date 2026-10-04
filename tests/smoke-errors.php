<?php
// Текст внутренних ошибок (база, пути сервера) не виден вне режима отладки: ни в ответе админке (JSON),
// ни на странице ошибки. Переведённые сообщения (404, проверки форм) остаются как есть.
require __DIR__ . '/testlib.php';

$leak = '/SQLSTATE|Duplicate entry|PDOException|Integrity constraint|\.php\b|\/var\/www/i';
login();
// повтор существующей константы в редакторе переводов упирается в уникальный ключ ltag_name
[$code, $j, $body] = json('/admin/translations/single/transEditor/save', http_build_query([
    'componentAction' => 'add', 'share_lang_tags' => ['ltag_id' => '', 'ltag_name' => 'TXT_HOME'],
    'share_lang_tags_translation' => [1 => ['ltag_value_rtf' => 'x'], 2 => ['ltag_value_rtf' => 'x']]]));
$msg = json_encode($j['errors'] ?? null, JSON_UNESCAPED_UNICODE);
check('ошибка базы при сохранении: отказ без текста ошибки SQL', is_array($j) && empty($j['result']) && !preg_match($leak, $body),
    "HTTP $code " . substr($body, 0, 200));
$serverText = (string)translation('ERR_SERVER');
check('ошибка базы при сохранении: понятное сообщение', $serverText !== '' && str_contains($msg, $serverText),
    $msg);
check('константа не задвоилась', (int)scalar("SELECT COUNT(*) FROM share_lang_tags WHERE ltag_name = 'TXT_HOME'") === 1);
// переведённое сообщение проверки остаётся: неизвестная страница — 404 со своим текстом
[$code, $page] = http('/claude-no-such-page-' . bin2hex(random_bytes(3)) . '/');
check('404 — переведённый текст, без путей сервера', $code == 404 && !preg_match($leak, $page), "HTTP $code");
done('errors');
