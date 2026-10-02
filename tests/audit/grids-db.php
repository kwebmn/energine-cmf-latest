<?php
// Помощник grids.js: записи с разметкой в текстовых полях — так их мог бы прислать посетитель
// (регистрация) или записать редактор (файл репозитория).
//   php8.5 grids-db.php add        — создать записи, вывести их id (JSON)
//   php8.5 grids-db.php remove     — убрать все записи теста
//   php8.5 grids-db.php user-active ID — активен ли пользователь (1/0)
require dirname(__DIR__) . '/testlib.php';

const PAYLOAD = '<img src="x" onerror="window.claudeXss=(window.claudeXss||0)+1"><b>claude-grid</b>';
const MARK = 'claude-grid-%';
const FILE = 'uploads/public/claude-grid-file.png';
const DIR = 'uploads/public/claude-grid-dir';
// картинка 1×1 (меньше 1 КиБ) — размер файла в байтах
const TINY_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'add':
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            ['claude-grid-' . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), PAYLOAD]);
        $user = pdo()->lastInsertId();
        // файл в корне репозитория: копия картинки демо-загрузок (путь в репозитории уникален)
        copy(WEB . '/uploads/public/13662314846.png', WEB . '/' . FILE);
        chown(WEB . '/' . FILE, SITE_USER);
        $root = scalar("SELECT upl_id FROM share_uploads WHERE upl_pid IS NULL ORDER BY upl_id LIMIT 1");
        q("INSERT INTO share_uploads (upl_pid, upl_path, upl_filename, upl_name, upl_title, upl_publication_date, upl_internal_type,
                upl_mime_type, upl_width, upl_height, upl_is_active)
           VALUES (?, ?, 'claude-grid-file.png', 'claude-grid-file.png', ?, NOW(), 'image', 'image/png', 90, 68, 1)",
            [$root, FILE, PAYLOAD]);
        $upload = pdo()->lastInsertId();
        // запись журнала действий на сегодня — для фильтра журнала по дате
        q("INSERT INTO share_action_log (al_date, al_classname, al_objectname, al_action, al_data) VALUES (NOW(), 'claude-grid', 'claude-grid', 'claude', '')");
        // пользователь с «+» в логине — для фильтра грида: значение фильтра должно дойти до сервера как есть
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            ['claude-grid-a+b@example.org', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), 'Claude Grid Plus']);
        // этап 8, шаг 6: три пользователя — выбор и удаление строк; неактивный — «Активировать»
        $del = [];
        foreach ([1, 2, 3] as $n) {
            q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
                ["claude-grid-del$n-" . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), "Claude Del $n"]);
            $del[] = (int)pdo()->lastInsertId();
        }
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 0)',
            ['claude-grid-off-' . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), 'Claude Off']);
        $off = (int)pdo()->lastInsertId();
        // папка репозитория с большой картинкой и маленькой (меньше 1 КиБ): папки, крошки, размер файла, превью
        $pub = scalar("SELECT upl_id FROM share_uploads WHERE upl_path = 'uploads/public' LIMIT 1");
        @mkdir(WEB . '/' . DIR);
        copy(WEB . '/uploads/public/13662314846.png', WEB . '/' . DIR . '/claude-grid-big.png');
        file_put_contents(WEB . '/' . DIR . '/claude-grid-tiny.png', base64_decode(TINY_PNG));
        foreach (['', '/claude-grid-big.png', '/claude-grid-tiny.png'] as $f) {
            chown(WEB . '/' . DIR . $f, SITE_USER);
        }
        q("INSERT INTO share_uploads (upl_pid, upl_childs_count, upl_path, upl_filename, upl_name, upl_title, upl_publication_date,
                upl_internal_type, upl_mime_type, upl_is_active)
           VALUES (?, 2, ?, 'claude-grid-dir', 'claude-grid-dir', 'claude-grid-dir', NOW(), 'folder', 'unknown/mime-type', 1)", [$pub, DIR]);
        $dir = (int)pdo()->lastInsertId();
        $files = [];
        foreach (['big' => [90, 68], 'tiny' => [1, 1]] as $name => [$w, $h]) {
            q("INSERT INTO share_uploads (upl_pid, upl_path, upl_filename, upl_name, upl_title, upl_publication_date, upl_internal_type,
                    upl_mime_type, upl_width, upl_height, upl_is_active)
               VALUES (?, ?, ?, ?, ?, NOW(), 'image', 'image/png', ?, ?, 1)",
                [$dir, DIR . "/claude-grid-$name.png", "claude-grid-$name.png", "claude-grid-$name.png", "claude-grid-$name", $w, $h]);
            $files[$name] = (int)pdo()->lastInsertId();
        }
        echo json_encode(['user' => (int)$user, 'upload' => (int)$upload, 'root' => (int)$root,
            'today' => scalar('SELECT DATE(NOW())'), 'del' => $del, 'off' => $off, 'dir' => $dir, 'big' => $files['big'],
            'tiny' => $files['tiny'], 'pub' => (int)$pub]);
        break;
    case 'remove':
        q('DELETE FROM user_users WHERE u_name LIKE ?', [MARK]);
        q("DELETE FROM share_action_log WHERE al_classname = 'claude-grid'");
        q('DELETE FROM share_uploads WHERE upl_filename = ?', ['claude-grid-file.png']);
        @unlink(WEB . '/' . FILE);
        q("DELETE FROM share_uploads WHERE upl_path LIKE 'uploads/public/claude-grid-dir%'");
        @unlink(WEB . '/' . DIR . '/claude-grid-big.png');
        @unlink(WEB . '/' . DIR . '/claude-grid-tiny.png');
        @rmdir(WEB . '/' . DIR);
        break;
    case 'user-active':
        echo scalar('SELECT u_is_active FROM user_users WHERE u_id = ?', [(int)$argv[2]]);
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
