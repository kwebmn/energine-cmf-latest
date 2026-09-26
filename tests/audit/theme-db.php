<?php
// Помощник theme.js: временный посетитель для страницы профиля (группа зарегистрированных, как после
// регистрации) и его удаление.
//   php8.5 theme-db.php user-add       — создать, вывести {"login": …, "password": …}
//   php8.5 theme-db.php user-remove    — удалить всех посетителей теста
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'user-add':
        $login = 'claude-theme-' . getmypid() . '@localhost';
        $password = bin2hex(random_bytes(8));
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude Theme']);
        $uid = pdo()->lastInsertId();
        // та же группа, что у зарегистрированного посетителя (Register)
        q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, 4)', [$uid]);
        echo json_encode(['login' => $login, 'password' => $password]);
        break;
    case 'user-remove':
        q("DELETE FROM user_users WHERE u_name LIKE 'claude-theme-%'");
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
