<?php
// Профиль посетителя (кабинет). Форма без служебных полей (активность, ссылка восстановления пароля);
// пароли в ней не обязательны: имя и прочее сохраняются без пароля. Пароль меняется только с верным
// текущим паролем и совпадающим повтором. Поля, которых нет в форме, не сохраняются.
// Всё — на временном пользователе группы зарегистрированных (как после регистрации); он удаляется.
require __DIR__ . '/testlib.php';

$login = 'claude-profile-' . getmypid() . '@localhost';
$password = bin2hex(random_bytes(8));
$cleanup = fn() => q('DELETE FROM user_users WHERE u_name LIKE ?', ['claude-profile-%']);
$cleanup();
register_shutdown_function($cleanup);
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
    [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude Profile']);
$uid = (int)pdo()->lastInsertId();
q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, 4)', [$uid]);
$row = fn() => q('SELECT u_fullname, u_password, u_is_active, u_restore_hash, u_restore_until FROM user_users WHERE u_id = ?', [$uid])->fetch();

function signIn($login, $password) {
    @unlink($GLOBALS['jar']);
    http('/login/');
    http('/auth.php', ['user' => ['login' => 1, 'username' => $login, 'password' => $password]], [], BASE . '/login/');
    return (bool)cookie('NRGNSID');
}
// имена полей формы, помеченных обязательными (класс required у обёртки поля)
function requiredNames($html) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $names = [];
    foreach ((new DOMXPath($doc))->query('//*[contains(concat(" ", normalize-space(@class), " "), " required ")]//*[@name]') as $el) {
        $names[] = $el->getAttribute('name');
    }
    return $names;
}
// сохранить форму профиля; ответ — редирект, страница результата открывается отдельно
function saveProfile($html, array $set) {
    http('/profile/save-user/', formData($html, $set), [], BASE . '/profile/');
}
$noPassword = ['user_users[u_password]' => '', 'u_password2' => '', 'u_password_current' => ''];

@unlink($GLOBALS['jar']);
[$c, $html] = http('/profile/');
check('гостю форма профиля не показывается', !str_contains($html, 'save-user'), "HTTP $c");

check('посетитель вошёл', signIn($login, $password));
[$c, $html] = http('/profile/');
check("форма профиля открывается (HTTP $c)", $c == 200 && str_contains($html, 'save-user'));
check('в форме нет служебных полей (активность, ссылка восстановления)',
    !preg_match('~name="user_users\[(u_is_active|u_restore_hash|u_restore_until)\]"~', $html),
    implode(' ', preg_match_all('~name="user_users\[(u_is_active|u_restore_\w+)\]"~', $html, $m) ? $m[1] : []));
check('в форме есть текущий пароль, новый и повтор',
    str_contains($html, 'name="u_password_current"') && str_contains($html, 'name="user_users[u_password]"')
    && str_contains($html, 'name="u_password2"'));
$required = requiredNames($html);
check('пароли в форме не обязательны', !array_intersect(['u_password_current', 'user_users[u_password]', 'u_password2'], $required),
    implode(' ', $required));

echo "-- данные без пароля\n";
saveProfile($html, ['user_users[u_fullname]' => 'Claude Profile renamed'] + $noPassword);
$r = $row();
check('имя сохраняется без пароля', $r['u_fullname'] === 'Claude Profile renamed', $r['u_fullname']);
check('пароль при этом не изменился', password_verify($password, $r['u_password']));
// лишние поля в запросе — как если бы посетитель дописал их в форму сам
saveProfile($html, ['user_users[u_fullname]' => 'Claude Profile 2', 'user_users[u_is_active]' => '0',
        'user_users[u_restore_hash]' => str_repeat('a', 64), 'user_users[u_restore_until]' => '2030-01-01 00:00:00'] + $noPassword);
$r = $row();
check('поля, которых нет в форме, не сохраняются (активность, ссылка восстановления)', $r['u_fullname'] === 'Claude Profile 2'
    && (int)$r['u_is_active'] === 1 && $r['u_restore_hash'] === null && $r['u_restore_until'] === null,
    json_encode(array_diff_key($r, ['u_password' => 1])));

echo "-- смена пароля\n";
$new = bin2hex(random_bytes(8));
saveProfile($html, ['user_users[u_password]' => $new, 'u_password2' => $new . 'x', 'u_password_current' => $password]);
[, $body] = http('/profile/error/');
check('несовпадение повтора: пароль не изменён', password_verify($password, $row()['u_password']));
check('несовпадение повтора: сообщение ERR_PWD_MISMATCH', str_contains($body, (string)translation('ERR_PWD_MISMATCH')),
    substr(strip_tags($body), 0, 200));
saveProfile($html, ['user_users[u_password]' => $new, 'u_password2' => $new, 'u_password_current' => $password . 'x']);
[, $body] = http('/profile/error/');
check('неверный текущий пароль: пароль не изменён', password_verify($password, $row()['u_password']));
check('неверный текущий пароль: сообщение TXT_USER_PROFILE_WRONG_PWD',
    str_contains($body, (string)translation('TXT_USER_PROFILE_WRONG_PWD')), substr(strip_tags($body), 0, 200));
saveProfile($html, ['user_users[u_password]' => $new, 'u_password2' => $new, 'u_password_current' => $password]);
check('верный текущий пароль и повтор: пароль сменён', password_verify($new, $row()['u_password']));
logout();
check('вход с новым паролем', signIn($login, $new));
logout();

done('smoke-profile');
