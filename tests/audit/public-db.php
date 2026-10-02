<?php
// Помощник public.js: временный посетитель (группа пользователя по умолчанию — как после регистрации) и его
// удаление. В логине — «+»: проверка занятости логина при регистрации должна передать его без искажений.
//   php8.5 public-db.php user-add       — создать, вывести {"login": …, "password": …}
//   php8.5 public-db.php user-remove    — удалить всех посетителей теста
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'user-add':
        $login = 'claude-public+' . getmypid() . '@example.org';
        $password = bin2hex(random_bytes(8));
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude Public']);
        $uid = pdo()->lastInsertId();
        q('INSERT INTO user_user_groups (u_id, group_id) SELECT ?, group_id FROM user_groups WHERE group_user_default = 1', [$uid]);
        echo json_encode(['login' => $login, 'password' => $password]);
        break;
    case 'user-remove':
        q("DELETE FROM user_users WHERE u_name LIKE 'claude-public+%'");
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
