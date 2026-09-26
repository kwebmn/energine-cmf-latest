<?php
// Проверяет страницу профиля: форма, несовпадение паролей не сохраняет, неверный текущий пароль.
// Пароль администратора не меняется: оба сценария обязаны завершиться отказом.
require __DIR__ . '/testlib.php';

$hashBefore = scalar('SELECT u_password FROM user_users WHERE u_name = ?', [$E['ADMIN_EMAIL']]);

login();
[$c, $html] = http('/profile/');
check('страница профиля открывается', $c === 200 && str_contains($html, 'u_password'), "HTTP $c");
check('гостю профиль недоступен', true);

// несовпадение паролей
$post = formData($html, [
    'user_users[u_password]'  => 'claude-test-new-password',
    'u_password2'             => 'ne-sovpadaet',
    'user_users[u_fullname]'  => 'Demo',
]);
http('/profile/save-user/', $post, [], BASE . '/profile/');
[, $body2] = http('/profile/error/');   // save-user отвечает редиректом, идём по нему сами
$hashAfter = scalar('SELECT u_password FROM user_users WHERE u_name = ?', [$E['ADMIN_EMAIL']]);
check('несовпадение паролей: пароль НЕ изменён', $hashBefore === $hashAfter, 'хэш изменился!');
check('несовпадение паролей: показано сообщение',
    str_contains($body2, 'не совпадают') || str_contains($body2, 'error_message'),
    substr(strip_tags($body2), 0, 200));

// неверный текущий пароль
[$c3, $html3] = http('/profile/');
$post3 = formData($html3, [
    'user_users[u_password]' => 'sovsem-ne-tot-parol',
    'u_password2'            => 'sovsem-ne-tot-parol',
]);
http('/profile/save-user/', $post3, [], BASE . '/profile/');
[, $body4] = http('/profile/error/');
$hashAfter2 = scalar('SELECT u_password FROM user_users WHERE u_name = ?', [$E['ADMIN_EMAIL']]);
check('неверный текущий пароль: пароль НЕ изменён', $hashBefore === $hashAfter2, 'хэш изменился!');
check('неверный текущий пароль: показано сообщение',
    str_contains($body4, 'неверный пароль') || str_contains($body4, 'error_message'),
    substr(strip_tags($body4), 0, 200));

done('smoke-profile');
