<?php
// CSRF (этап 5а): любой POST требует токен страницы — поле csrf_token или заголовок X-CSRF-Token;
// чужой Origin отклоняется и с верным токеном. Отказ — код 422: 403 подменяет своей страницей
// веб-сервер ISPConfig. Почта не уходит: отклонённые запросы останавливаются до компонентов,
// принятый гостевой запрос — проверка логина регистрации (без побочных действий).
// Действия, меняющие данные по одному адресу (удаление, включение пользователя), GET-ом не выполняются:
// ссылку с чужого сайта браузер открывает с cookie сессии.
// Всё, что тест меняет, возвращается.
require __DIR__ . '/testlib.php';

const NOTOKEN = ['X-CSRF-Token: '];
const MARK = 'claude-csrf-test';

// токен со страницы: <meta name="csrf-token"> и скрытое поле формы
function tokens($html) {
    preg_match('~<meta name="csrf-token" content="([^"]*)"~', $html, $meta);
    preg_match('~name="csrf_token" value="([^"]*)"~', $html, $field);
    return [$meta[1] ?? null, $field[1] ?? null];
}

// строки обратной связи с меткой убираются и до, и после прогона (без проверки они бы сохранились)
$cleanup = function () {
    q('DELETE FROM apps_feedback WHERE feed_theme = ?', [MARK]);
    q('DELETE FROM user_users WHERE u_name LIKE ?', [MARK . '-%']);
};
$cleanup();
register_shutdown_function($cleanup);

echo "-- гость\n";
@unlink($GLOBALS['jar']);
[$c, $html] = http('/contacts/');
[$meta, $field] = tokens($html);
check('страница отдаёт токен в meta и в форме', $meta && strlen($meta) == 64 && $meta === $field, "meta=$meta field=$field");
check('у гостя cookie nrgn_csrf', (bool)cookie('nrgn_csrf'));
// адреса получателей нужны только для отправки: в варианты выбора (атрибуты option) они не попадают
$addresses = [];
foreach (q('SELECT rcp_recipients FROM apps_feedback_recipient')->fetchAll(PDO::FETCH_COLUMN) as $list) {
    foreach (preg_split('/[\s,;]+/', (string)$list, -1, PREG_SPLIT_NO_EMPTY) as $address) $addresses[] = $address;
}
$shown = array_values(array_filter($addresses, fn($a) => stripos($html, $a) !== false));
check('страница обратной связи не выдаёт адреса получателей', $addresses && !$shown, implode(', ', $shown));

$before = (int)scalar('SELECT COUNT(*) FROM apps_feedback');
$feedback = ['componentAction' => 'send', 'apps_feedback[feed_author]' => MARK, 'apps_feedback[feed_theme]' => MARK,
    'apps_feedback[feed_text]' => MARK];
[$c, $body] = http('/contacts/send/', $feedback, NOTOKEN);
check("обратная связь без токена — 422 (HTTP $c)", $c == 422 && clean($body), $body);
check('обратная связь без токена ничего не сохранила', (int)scalar('SELECT COUNT(*) FROM apps_feedback') === $before);
$errCsrf = (string)translation('ERR_CSRF');
check('в ответе понятный текст ERR_CSRF', $errCsrf !== '' && str_contains($body, $errCsrf), $body);

[$c, $body] = http('/contacts/send/', $feedback + ['csrf_token' => str_repeat('0', 64)], NOTOKEN);
check("обратная связь с чужим токеном — 422 (HTTP $c)", $c == 422);

$check = ['login' => MARK . '-' . getmypid() . '@localhost'];
[$c, $body] = http('/register/check/', $check, ['X-Request: JSON', 'X-CSRF-Token: ' . $meta]);
$j = json_decode($body, true);
check("проверка логина регистрации с токеном — ответ JSON (HTTP $c)", $c == 200 && is_array($j) && ($j['field'] ?? '') === 'login', $body);
[$c, $body] = http('/register/check/', $check + ['csrf_token' => $meta], ['X-Request: JSON', 'X-CSRF-Token: ']);
check("токен в поле формы тоже принимается (HTTP $c)", $c == 200 && is_array(json_decode($body, true)), $body);
[$c, $body] = http('/register/check/', $check, ['X-Request: JSON', 'X-CSRF-Token: ']);
check("проверка логина без токена — 422 (HTTP $c)", $c == 422, $body);
[$c, $body] = http('/register/check/', $check, ['X-Request: JSON', 'X-CSRF-Token: ' . $meta, 'Origin: https://evil.example']);
check("чужой Origin с верным токеном — 422 (HTTP $c)", $c == 422, $body);
[$c, $body] = http('/register/check/', $check, ['X-Request: JSON', 'X-CSRF-Token: ' . $meta, 'Origin: ' . BASE]);
check("свой Origin — принят (HTTP $c)", $c == 200, $body);

echo "-- вход\n";
[$authCode] = http('/auth.php', ['user' => ['login' => 1, 'username' => $GLOBALS['E']['ADMIN_EMAIL'], 'password' => $GLOBALS['E']['ADMIN_PASSWORD']]],
    NOTOKEN, BASE . '/login/');
check('вход без токена не выполнен', !cookie('NRGNSID'));
// для разбора редкого сбоя (сообщения нет): ответ auth.php и cookie причины в банке до открытия страницы
$authDiag = "auth.php HTTP $authCode, failed_login в банке: " . var_export(cookie('failed_login'), true);
[$c, $html] = http('/login/');
check('страница входа объясняет причину текстом ERR_CSRF', $errCsrf !== '' && str_contains($html, $errCsrf),
    (preg_match('~<div class="error_message">(.*?)</div>~s', $html, $m) ? $m[1] : '(нет сообщения)') . "; $authDiag, страница HTTP $c");

login();
check('вход с токеном выполнен', (bool)cookie('NRGNSID'));
[$c, $html] = http('/');
[$adminToken] = tokens($html);
check('после входа токен другой', $adminToken && $adminToken !== $meta);

echo "-- администратор\n";
$newsId = (int)scalar("SELECT MIN(news_id) FROM apps_news WHERE news_segment NOT LIKE 'claude-test%'");
$orig = scalar('SELECT news_title FROM apps_news_translation WHERE news_id = ? AND lang_id = 1', [$newsId]);
$path = "/admin/news-editor/single/newsRepo/$newsId/edit/";
[$c, $html] = http($path);
$save = preg_replace('~\d+/edit/$~', '', $path) . 'save';
$data = formData($html, ["apps_news_translation[1][news_title]" => $orig . ' ' . MARK]);
try {
    [$c, $body] = http($save, preg_replace('~(^|&)csrf_token=[^&]*~', '', $data), ['X-Request: JSON', 'X-CSRF-Token: ']);
    $j = json_decode($body, true);
    check("сохранение новости без токена — отказ JSON-ом (HTTP $c)", $c == 422 && is_array($j) && empty($j['result'])
        && str_contains(json_encode($j['errors'] ?? [], JSON_UNESCAPED_UNICODE), $errCsrf), $body);
    check('новость не изменилась', scalar('SELECT news_title FROM apps_news_translation WHERE news_id = ? AND lang_id = 1', [$newsId]) === $orig);
    [$c, $body] = http($save, preg_replace('~(^|&)csrf_token=[^&]*~', '', $data), ['X-Request: JSON', 'X-CSRF-Token: ' . $meta]);
    check("токен гостя после входа не подходит (HTTP $c)", $c == 422, $body);
    [$c, $body] = http($save, $data, ['X-Request: JSON']);
    $j = json_decode($body, true);
    check("сохранение с токеном формы — принято (HTTP $c)", $c == 200 && !empty($j['result']), $body);
    check('новость сохранена', scalar('SELECT news_title FROM apps_news_translation WHERE news_id = ? AND lang_id = 1', [$newsId]) === $orig . ' ' . MARK);
} finally {
    q('UPDATE apps_news_translation SET news_title = ? WHERE news_id = ? AND lang_id = 1', [$orig, $newsId]);
}

echo "-- действия, меняющие данные, — только POST-ом\n";
// ссылка или картинка на чужом сайте открывает адрес GET-ом, и cookie сессии уходит с ним (SameSite=Lax
// пропускает переходы по ссылке): такой запрос ничего не удаляет и не меняет
q("INSERT INTO apps_feedback (feed_date, rcp_id, feed_email, feed_author, feed_theme, feed_text)
   SELECT NOW(), MIN(rcp_id), 'claude-csrf@localhost', ?, ?, ? FROM apps_feedback_recipient", [MARK, MARK, MARK]);
$feedId = (int)pdo()->lastInsertId();
$feedExists = fn() => (int)scalar('SELECT COUNT(*) FROM apps_feedback WHERE feed_id = ?', [$feedId]) === 1;
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
    [MARK . '-' . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), MARK]);
$userId = (int)pdo()->lastInsertId();
$gets = [
    'удаление обращения' => "/admin/feedback-editor/single/feedbackList/$feedId/delete/",
    'выключение пользователя' => "/admin/users/single/userEditor/$userId/activate/",
];
foreach ($gets as $label => $url) {
    [$c, $body] = http($url);
    // у single-адресов страницу отказа строит ErrorDocument (<title>Errors</title>), текст — ERR_CSRF
    check("$label GET-ом — отказ 422 с текстом ERR_CSRF (HTTP $c)", $c == 422 && str_contains($body, $errCsrf)
        && !preg_match('/Fatal error|Warning: |Notice: |Deprecated: /', $body), substr($body, 0, 300));
}
check('обращение не удалено', $feedExists());
check('пользователь остался активным', (int)scalar('SELECT u_is_active FROM user_users WHERE u_id = ?', [$userId]) === 1);
// так действуют кнопки грида: POST с токеном в заголовке
[$c, $body] = http("/admin/users/single/userEditor/$userId/activate/", '', ['X-Request: JSON']);
check("выключение пользователя POST-ом с токеном — принято (HTTP $c)", $c == 200
    && (int)scalar('SELECT u_is_active FROM user_users WHERE u_id = ?', [$userId]) === 0, $body);
[$c, $body] = http("/admin/feedback-editor/single/feedbackList/$feedId/delete/", '', ['X-Request: JSON']);
check("удаление обращения POST-ом с токеном — принято (HTTP $c)", $c == 200 && !$feedExists(), $body);
logout();
check('выход POST-ом с токеном выполнен', !cookie('NRGNSID'));

echo "-- возврат после входа только на свой сайт\n";
foreach (['https://evil.example/', '//evil.example/', '/\\evil.example/'] as $return) {
    $ch = curl_init(BASE . '/auth.php?return=' . rawurlencode($return));
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_REFERER => BASE . '/login/', CURLOPT_TIMEOUT => 60]);
    curl_exec($ch);
    $location = (string)curl_getinfo($ch, CURLINFO_REDIRECT_URL);
    check("return=$return не уводит с сайта (Location: $location)", $location !== '' && parse_url($location, PHP_URL_HOST) === parse_url(BASE, PHP_URL_HOST));
}
$ch = curl_init(BASE . '/auth.php?return=' . rawurlencode('/news/'));
curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_REFERER => BASE . '/login/', CURLOPT_TIMEOUT => 60]);
curl_exec($ch);
check('return=/news/ ведёт на /news/', str_ends_with((string)curl_getinfo($ch, CURLINFO_REDIRECT_URL), '/news/'), curl_getinfo($ch, CURLINFO_REDIRECT_URL));
done('csrf');
