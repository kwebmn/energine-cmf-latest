<?php
// Предохранители удаления, которые не срабатывали с 2016 года (грид передаёт номера массивом):
//  1. пользователь не может удалить сам себя (UserEditor::deleteData, ERR_CANT_DELETE_YOURSELF);
//  2. язык по умолчанию не удаляется (LanguageEditor::deleteData, ERR_CANT_DELETE) — иначе каскад снёс бы все тексты,
//     подписи и письма на этом языке.
// Без риска для живых данных: временный администратор удаляет себя; временный язык на время проверки становится
// языком по умолчанию (флаг возвращается в конце, даже при падении).
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$adminGroup = (int)scalar('SELECT group_id FROM share_access_level WHERE right_id = 3 AND smap_id = ?', [$root]);
$defaultLang = (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 1');
function cleanup(): void {
    global $defaultLang;
    q("DELETE FROM user_users WHERE u_name = 'claude-guard@example.org'");
    q("DELETE FROM share_languages WHERE lang_abbr = 'zz'");
    q('UPDATE share_languages SET lang_default = IF(lang_id = ?, 1, 0)', [$defaultLang]);
}
cleanup();
register_shutdown_function('cleanup');

// 1. временный администратор удаляет себя
$pwd = bin2hex(random_bytes(8));
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)', ['claude-guard@example.org', password_hash($pwd, PASSWORD_DEFAULT), 'Claude Guard']);
$uid = (int)pdo()->lastInsertId();
q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, ?)', [$uid, $adminGroup]);
@unlink($GLOBALS['jar']);
http('/login/');
http('/auth.php', ['user' => ['login' => 1, 'username' => 'claude-guard@example.org', 'password' => $pwd]], [], BASE . '/login/');
[$c, $j, $raw] = json("/admin/users/single/userEditor/$uid/delete/", '');
$stillThere = (int)scalar('SELECT COUNT(*) FROM user_users WHERE u_id = ?', [$uid]) === 1;
check('администратор не может удалить сам себя: отказ, запись на месте', empty($j['result']) && $stillThere
    && str_contains(json_encode($j['errors'] ?? [], JSON_UNESCAPED_UNICODE), (string)translation('ERR_CANT_DELETE_YOURSELF')), "HTTP $c " . substr($raw, 0, 160) . ' | exists=' . var_export($stillThere, true));
logout();

// 2. язык по умолчанию не удаляется (временный язык на время проверки — по умолчанию)
login();
q("INSERT INTO share_languages (lang_abbr, lang_name, lang_default, lang_order_num) VALUES ('zz', 'Claude', 0, 99)");
$lid = (int)pdo()->lastInsertId();
q('UPDATE share_languages SET lang_default = IF(lang_id = ?, 1, 0)', [$lid]);
[$c, $j, $raw] = json("/admin/translations/languages/single/langEditor/$lid/delete/", '');
$langThere = (int)scalar('SELECT COUNT(*) FROM share_languages WHERE lang_id = ?', [$lid]) === 1;
q('UPDATE share_languages SET lang_default = IF(lang_id = ?, 1, 0)', [$defaultLang]);
check('язык по умолчанию не удаляется: отказ, язык на месте', empty($j['result']) && $langThere
    && str_contains(json_encode($j['errors'] ?? [], JSON_UNESCAPED_UNICODE), (string)translation('ERR_CANT_DELETE')), "HTTP $c " . substr($raw, 0, 160) . ' | exists=' . var_export($langThere, true));
check('язык по умолчанию возвращён', (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 1') === $defaultLang);
logout();
done('delete-guards');
