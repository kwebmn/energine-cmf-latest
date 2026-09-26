<?php
// Лимит попыток входа (этап 5а): 5 неудач на один логин или 20 с одного IP за 15 минут — следующая
// попытка отклоняется без проверки пароля. Временный пользователь и строки попыток теста убираются
// в любом случае: запертый IP — это IP всех тестов этой машины.
require __DIR__ . '/testlib.php';

$login = 'claude-limit-' . getmypid() . '@localhost';
$password = bin2hex(random_bytes(8));
$cleanup = function () use ($login) {
    q('DELETE FROM user_login_attempts WHERE la_login LIKE ?', ['claude-limit-%']);
    q('DELETE FROM user_users WHERE u_name = ?', [$login]);
};
$cleanup();
register_shutdown_function($cleanup);
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
    [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude limit test']);

// вход с чистой банкой cookie: [вошёл ли, текст сообщения формы входа]
function attempt($login, $password, $page = '/login/') {
    @unlink($GLOBALS['jar']);
    http($page);
    http('/auth.php', ['user' => ['login' => 1, 'username' => $login, 'password' => $password]], [], BASE . $page);
    $in = (bool)cookie('NRGNSID');
    [, $html] = http($page);
    $message = preg_match('~<div class="error_message">(.*?)</div>~s', $html, $m) ? trim(strip_tags($m[1])) : '';
    if ($in) logout();
    return [$in, $message];
}
$bad = (string)translation('ERR_BAD_AUTH');
$locked = (string)translation('ERR_TOO_MANY_ATTEMPTS');
check('перевод ERR_TOO_MANY_ATTEMPTS есть', $locked !== '');

echo "-- логин\n";
for ($i = 1; $i <= 5; $i++) {
    [$in, $message] = attempt($login, 'wrong-' . $i);
    check("неверный пароль $i — не вошёл, «{$message}»", !$in && $message === $bad);
}
[$in, $message] = attempt($login, $password);
check('шестая попытка с верным паролем отклонена', !$in && $message === $locked, $message);
[$in, $message] = attempt($login, $password, '/ua/login/');
check('сообщение на украинском', !$in && $message === (string)translation('ERR_TOO_MANY_ATTEMPTS', 2), $message);

q('UPDATE user_login_attempts SET la_date = la_date - 16 * 60 WHERE la_login = ?', [$login]);
[$in] = attempt($login, $password);
check('через 15 минут вход открыт', $in);
check('удачный вход очистил неудачи логина', (int)scalar('SELECT COUNT(*) FROM user_login_attempts WHERE la_login = ?', [$login]) === 0);

echo "-- заблокированный пользователь\n";
q('UPDATE user_users SET u_is_active = 0 WHERE u_name = ?', [$login]);
[$in, $message] = attempt($login, $password);
check('неактивный пользователь с верным паролем не входит', !$in && $message === $bad, $message);
q('UPDATE user_users SET u_is_active = 1 WHERE u_name = ?', [$login]);
q('DELETE FROM user_login_attempts WHERE la_login = ?', [$login]);

echo "-- IP\n";
for ($i = 1; $i <= 20; $i++) attempt('claude-limit-nobody-' . $i . '@localhost', 'x');
[$in, $message] = attempt($login, $password);
check('20 неудач с IP по разным логинам запирают IP', !$in && $message === $locked, $message);
q('DELETE FROM user_login_attempts WHERE la_login LIKE ?', ['claude-limit-%']);
[$in] = attempt($login, $password);
check('без неудач вход снова открыт', $in);

done('login-limit');
