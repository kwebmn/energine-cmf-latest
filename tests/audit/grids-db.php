<?php
// Помощник grids.js: записи с разметкой в текстовых полях — так их мог бы прислать посетитель
// (обратная связь, регистрация) или записать редактор (файл репозитория).
//   php8.5 grids-db.php add        — создать записи, вывести их id (JSON)
//   php8.5 grids-db.php remove     — убрать все записи теста
require dirname(__DIR__) . '/testlib.php';

const PAYLOAD = '<img src="x" onerror="window.claudeXss=(window.claudeXss||0)+1"><b>claude-grid</b>';
const MARK = 'claude-grid-%';
const FILE = 'uploads/public/claude-grid-file.png';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'add':
        q('INSERT INTO apps_feedback (feed_date, rcp_id, feed_email, feed_author, feed_theme, feed_text)
           SELECT NOW(), MIN(rcp_id), ?, ?, ?, ? FROM apps_feedback_recipient',
            ['claude-grid-feedback@localhost', PAYLOAD, PAYLOAD, PAYLOAD]);
        $feed = pdo()->lastInsertId();
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
        echo json_encode(['feed' => (int)$feed, 'user' => (int)$user, 'upload' => (int)$upload, 'root' => (int)$root]);
        break;
    case 'remove':
        q('DELETE FROM apps_feedback WHERE feed_email = ?', ['claude-grid-feedback@localhost']);
        q('DELETE FROM user_users WHERE u_name LIKE ?', [MARK]);
        q('DELETE FROM share_uploads WHERE upl_filename = ?', ['claude-grid-file.png']);
        @unlink(WEB . '/' . FILE);
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
