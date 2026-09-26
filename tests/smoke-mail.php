<?php
// Mail sending end-to-end on the site from env.php: registration, password restore, feedback form,
// mail templates editor.
// Every real message goes to the local mailbox MAILBOX (tests/local.php) only (recipients are switched before the run).
// No captcha on the site any more; HTML parts are checked for escaped visitor values (markup, quotes, &, line breaks).
// Usage: php8.5 smoke-mail.php            (run cleanup-mail.php afterwards)
require __DIR__ . '/testlib.php';
date_default_timezone_set('Europe/Kyiv');   // as the site (share/gears/ini.func.php)

const MBOX = MAILBOX_FILE;
const TEST_EMAIL = MAILBOX;
const USER_NAME = 'Тестовый пользователь & Co';   // & must become &amp; in HTML parts

function jar($name) { $GLOBALS['jar'] = __DIR__ . "/cookies-mail-$name.txt"; }
function freshJar($name) { jar($name); @unlink($GLOBALS['jar']); }

// --- mailbox (mbox written by postfix local delivery)
function mboxSize() { clearstatcache(); return is_file(MBOX) ? filesize(MBOX) : 0; }
function mboxRead($offset) {
    clearstatcache();
    $raw = is_file(MBOX) ? (string)file_get_contents(MBOX, false, null, $offset) : '';
    $result = [];
    foreach (preg_split('/^From \S+ +\w{3} \w{3} .*$/m', $raw, -1, PREG_SPLIT_NO_EMPTY) as $msg) {
        $msg = ltrim($msg, "\n");
        if ($msg === '') continue;
        [$head, $body] = array_pad(explode("\n\n", $msg, 2), 2, '');
        $headers = [];
        foreach (explode("\n", preg_replace("/\n[ \t]+/", ' ', $head)) as $line) {
            if (preg_match('/^([\w-]+):\s*(.*)$/', $line, $m)) $headers[strtolower($m[1])] = $m[2];
        }
        // части письма — в quoted-printable (раньше 8bit): текст раскодируется
        $part = function ($type) use ($body) {
            if (!preg_match('~Content-Type: text/' . $type . '; charset=UTF-8\nContent-Transfer-Encoding: (8bit|quoted-printable)\n\n(.*?)\n\n--~s', $body, $m)) {
                return '';
            }
            return $m[1] === 'quoted-printable' ? str_replace("\r\n", "\n", quoted_printable_decode($m[2])) : $m[2];
        };
        $result[] = ['to' => $headers['to'] ?? '', 'from' => $headers['from'] ?? '', 'subject' => iconv_mime_decode($headers['subject'] ?? '', 0, 'UTF-8'),
            'text' => $part('plain'), 'html' => $part('html'), 'raw' => $msg];
    }
    return $result;
}
function mboxWait($offset, $count, $timeout = 30) {
    $deadline = time() + $timeout;
    do {
        $messages = mboxRead($offset);
        if (count($messages) >= $count) break;
        usleep(500000);
    } while (time() < $deadline);
    return $messages;
}
function bySubject(array $messages, $subject) {
    foreach ($messages as $m) if ($m['subject'] === $subject) return $m;
    return null;
}
function brief(array $messages) {
    return json_encode(array_map(fn($m) => [$m['to'], $m['subject'], mb_substr($m['text'], 0, 120)], $messages), JSON_UNESCAPED_UNICODE);
}

// --- forms: fields of one form only (pages also carry the login form)
function formIn($html, $actionContains, array $set = []) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $xp = new DOMXPath($doc);
    $forms = $xp->query('//form[contains(@action, "' . $actionContains . '")]');
    if (!$forms->length) return null;
    $tmp = new DOMDocument();
    $tmp->appendChild($tmp->importNode($forms->item(0), true));
    return formData($tmp->saveHTML(), $set);
}
function loginAs($user, $password) {
    http('/login/');
    http('/auth.php', ['user' => ['login' => 1, 'username' => $user, 'password' => $password]], [], BASE . '/login/');
    [$c] = http('/profile/');   // a guest gets 404 here
    return $c == 200;
}

$siteName = scalar('SELECT site_name FROM share_sites_translation WHERE lang_id = 1');

// =====================================================================================================
echo "-- registration\n";
freshJar('user');
$off = mboxSize();
[$c, $html] = http('/register/');
check('register page without captcha', $c == 200 && clean($html) && stripos($html, 'captcha') === false, $html);
// u_phone — колонка таблицы, которой нет в форме регистрации: сохраняются только поля формы
$registration = ['user_users[u_name]' => TEST_EMAIL, 'user_users[u_fullname]' => USER_NAME, 'user_users[u_phone]' => 'claude-extra-field'];
sleep(3);   // как человек: форма, отправленная сразу после показа, отклоняется (FormGuard)
[$c, $body] = http('/register/save-new-user/', formIn($html, 'register/save-new-user', $registration));
$uid = scalar('SELECT u_id FROM user_users WHERE u_name = ?', [TEST_EMAIL]);
$formError = preg_match('~<div class="alert[^"]*"[^>]*>(.*?)</div>~s', $body, $mm) ? strip_tags($mm[1]) : '';
check("user registered (u_id $uid, HTTP $c) $formError", $uid && $c == 302 && scalar('SELECT COUNT(*) FROM user_user_groups WHERE u_id = ? AND group_id = 4', [$uid]), $body);
check('registration saves only the form fields (u_phone ignored)',
    $uid && (string)scalar("SELECT COALESCE(u_phone, '') FROM user_users WHERE u_id = ?", [$uid]) === '',
    scalar('SELECT u_phone FROM user_users WHERE u_id = ?', [$uid]));
$messages = mboxWait($off, 1);
$m = bySubject($messages, 'Регистрация на сайте ' . translation('TXT_SITE_NAME'));
check('registration mail delivered', $m && $m['to'] === TEST_EMAIL && count($messages) == 1 && str_contains($m['text'], 'Здравствуйте, ' . USER_NAME . '!'), brief($messages));
check('registration mail: name escaped in HTML', $m && str_contains($m['html'], 'Здравствуйте, Тестовый пользователь &amp; Co!'), $m['html'] ?? '');
$password = ($m && preg_match('/Пароль: (\S+)/u', $m['text'], $mm)) ? $mm[1] : null;
check('HTML part has the password', $m && $password && str_contains($m['html'], "<strong>$password</strong>"), $m['html'] ?? '');
check('login with the mailed password', $password && loginAs(TEST_EMAIL, $password));
// тот же логин ещё раз: отказ ERR_USER_EXISTS, второго пользователя и письма нет
freshJar('user2');
[, $html] = http('/register/');
sleep(3);
$off = mboxSize();
[$c, $body] = http('/register/save-new-user/', formIn($html, 'register/save-new-user',
    ['user_users[u_name]' => TEST_EMAIL, 'user_users[u_fullname]' => USER_NAME]));
sleep(2);
$refusal = strip_tags((string)translation('ERR_USER_EXISTS'));
check("the same login again is refused (HTTP $c)", $refusal !== '' && str_contains($body, $refusal)
    && (int)scalar('SELECT COUNT(*) FROM user_users WHERE u_name = ?', [TEST_EMAIL]) === 1 && mboxSize() === $off,
    substr(strip_tags($body), 0, 300));

// =====================================================================================================
echo "-- restore password\n";
// ссылка на смену пароля: запрос не меняет пароль, ссылка одноразовая, срок — час, в базе только хэш токена
$restoreRow = fn() => q('SELECT u_password, u_restore_hash, u_restore_until FROM user_users WHERE u_name = ?', [TEST_EMAIL])->fetch();
$sent = (string)translation('MSG_RESTORE_LINK_SENT');
$badLink = (string)translation('ERR_RESTORE_LINK');
$request = function ($lang = '') {
    freshJar('guest');
    [, $html] = http("/{$lang}restore-password/");
    return http("/{$lang}restore-password/send/", formIn($html, 'restore-password/send', ['u_name' => TEST_EMAIL]));
};
$tokenOf = fn($link) => preg_match('~/reset/([0-9a-f]{64})/$~', (string)$link, $mm) ? $mm[1] : '';
$hashBefore = $restoreRow()['u_password'];
$off = mboxSize();
[$c, $body] = $request();
check("restore request answer (HTTP $c)", $c == 200 && clean($body) && $sent !== '' && str_contains($body, $sent), $body);
$messages = mboxWait($off, 1);
$m = bySubject($messages, "Смена пароля на сайте $siteName");
$link = ($m && preg_match('~(https?://\S+/restore-password/reset/[0-9a-f]{64}/)~', $m['text'], $mm)) ? $mm[1] : null;
check('restore mail with a one-time link', $m && $m['to'] === TEST_EMAIL && $link && str_contains($m['html'], 'href="' . $link . '"')
    && str_contains($m['text'], 'Уважаемый(ая) ' . USER_NAME . '!'), brief($messages));
$row = $restoreRow();
check('the request does not change the password', $row['u_password'] === $hashBefore);
check('only a hash of the token is stored, valid for an hour', $link && $row['u_restore_hash'] === hash('sha256', $tokenOf($link))
    && abs(strtotime($row['u_restore_until']) - time() - 3600) < 120, json_encode($row));
freshJar('old');
check('the old password works until the link is used', loginAs(TEST_EMAIL, (string)$password));

$off = mboxSize();
[$c, $body] = $request();
check('a second request: the same answer', $c == 200 && str_contains($body, $sent), $body);
[$c, $body] = http('/restore-password/send/', ['componentAction' => 'send', 'u_name' => 'nobody-' . getmypid() . '@localhost']);
check('an unknown address: the same answer', $c == 200 && clean($body) && str_contains($body, $sent), $body);
sleep(3);
check('no mail for a second request within 5 minutes nor for an unknown address', count(mboxRead($off)) === 0, brief(mboxRead($off)));

freshJar('guest');
[$c, $body] = http('/restore-password/reset/' . str_repeat('0', 64) . '/');
check('a wrong token is refused', $c == 200 && clean($body) && $badLink !== '' && str_contains($body, $badLink), $body);
[$c, $html] = http((string)$link);
check('the link opens the new password form', $c == 200 && clean($html) && str_contains($html, 'name="u_password"')
    && str_contains($html, 'name="u_password2"'), $html);
$change = str_replace('/reset/', '/change/', (string)$link);
[$c, $body] = http($change, formIn($html, 'restore-password/change', ['u_password' => 'claude-1', 'u_password2' => 'claude-2']));
check('a mismatched confirmation is refused', $c == 200 && str_contains($body, (string)translation('ERR_PWD_MISMATCH'))
    && $restoreRow()['u_password'] === $hashBefore, $body);
$newPassword = 'Claude-' . bin2hex(random_bytes(4));
[$c, $html] = http((string)$link);
[$c, $body] = http($change, formIn($html, 'restore-password/change', ['u_password' => $newPassword, 'u_password2' => $newPassword]));
check('the new password is set', $c == 200 && clean($body) && str_contains($body, (string)translation('MSG_PASSWORD_CHANGED')), $body);
check('the token is gone', $restoreRow()['u_restore_hash'] === null);
jar('old');
[$c] = http('/profile/');
check('sessions opened before the change are closed', $c == 404, "HTTP $c");
freshJar('user');
check('old password rejected, new one accepted', !loginAs(TEST_EMAIL, (string)$password) && (freshJar('user') || true) && loginAs(TEST_EMAIL, $newPassword));
freshJar('guest');
[$c, $body] = http((string)$link);
check('a used link is refused', $c == 200 && str_contains($body, $badLink), $body);

// срок: ссылка, выданная больше часа назад, не действует
$off = mboxSize();
$request();
$m = bySubject(mboxWait($off, 1), "Смена пароля на сайте $siteName");
$link2 = ($m && preg_match('~(https?://\S+/restore-password/reset/[0-9a-f]{64}/)~', $m['text'], $mm)) ? $mm[1] : null;
q("UPDATE user_users SET u_restore_until = ? WHERE u_name = ?", [date('Y-m-d H:i:s', time() - 60), TEST_EMAIL]);
freshJar('guest');
[$c, $body] = http((string)$link2);
check('an expired link is refused', $link2 && $c == 200 && str_contains($body, $badLink), $body);

// украинская страница: письмо и ссылка на украинском
$off = mboxSize();
$request('ua/');
$m = bySubject(mboxWait($off, 1), "Зміна пароля на сайті " . scalar('SELECT site_name FROM share_sites_translation WHERE lang_id = 2'));
check('the Ukrainian request gets a Ukrainian mail with a /ua/ link', $m && preg_match('~https?://\S+/ua/restore-password/reset/[0-9a-f]{64}/~', $m['text']),
    brief(mboxRead($off)));
q('UPDATE user_users SET u_restore_hash = NULL, u_restore_until = NULL WHERE u_name = ?', [TEST_EMAIL]);

// =====================================================================================================
echo "-- feedback form\n";
freshJar('guest');
$off = mboxSize();
[$c, $html] = http('/contacts/');
check('feedback form without captcha', $c == 200 && clean($html) && stripos($html, 'captcha') === false, $html);
$feedback = ['apps_feedback[feed_author]' => 'Claude <b>Test</b>', 'apps_feedback[feed_email]' => TEST_EMAIL,
    'apps_feedback[feed_theme]' => 'claude-test feedback', 'apps_feedback[feed_text]' => "Проверка <script>alert(1)</script> & \"кавычки\"\nвторая строка [feed_email]"];
sleep(3);   // как человек: форма, отправленная сразу после показа, отклоняется (FormGuard)
[$c, $body] = http('/contacts/send/', formIn($html, 'contacts/send', $feedback));
$feed = q("SELECT feed_id, feed_date FROM apps_feedback WHERE feed_theme = 'claude-test feedback'")->fetch();
check("feedback saved (HTTP $c, " . json_encode($feed) . ')', $feed && $c == 302 && abs(strtotime($feed['feed_date']) - time()) < 120, $body);
$messages = mboxWait($off, 2);
$user = bySubject($messages, 'Ваше сообщение получено');
$admin = bySubject($messages, 'Сообщение с сайта: claude-test feedback');
check('feedback confirmation to the visitor', count($messages) == 2 && $user && str_ends_with($user['to'], '<' . TEST_EMAIL . '>') && !str_contains($user['raw'], 'вторая строка'), brief($messages));
check('feedback notification to the recipient', $admin && str_contains($admin['text'], "Имя: Claude <b>Test</b>\nE-mail: " . TEST_EMAIL) && str_contains($admin['text'], "\nвторая строка [feed_email]"), brief($messages));
check('feedback notification: values escaped in HTML, macros in values left as they are', $admin
    && str_contains($admin['html'], 'Имя: Claude &lt;b&gt;Test&lt;/b&gt;<br>')
    && str_contains($admin['html'], "Проверка &lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;кавычки&quot;<br>\nвторая строка [feed_email]")
    && !str_contains($admin['html'], '<script>') && !str_contains($admin['html'], '<b>Test</b>'), $admin['html'] ?? '');
[$c, $body] = http('/contacts/success/');
check('feedback success page', $c == 200 && clean($body), $body);

// =====================================================================================================
echo "-- mail templates editor\n";
freshJar('admin');
login();
$T = '/admin/mail-templates/single/mailTemplateEditor/';
[$c, $j, $raw] = json($T . 'get-data/');
check('templates grid lists 4 templates', $c == 200 && count($j['data'] ?? []) == 4, $raw);
[$c, $html] = http($T . '1/edit/');
check('template edit form', $c == 200 && clean($html) && str_contains($html, 'user_registration'), $html);
$before = q('SELECT * FROM mail_templates_translation WHERE template_id = 1 ORDER BY lang_id')->fetchAll();
[$c, $j, $raw] = json($T . 'save', formData($html));
$after = q('SELECT * FROM mail_templates_translation WHERE template_id = 1 ORDER BY lang_id')->fetchAll();
check('template saved without changes', !empty($j['result']) && $before == $after, $raw . ' ' . json_encode([$before, $after], JSON_UNESCAPED_UNICODE));
[$c, $j, $raw] = json($T . '1/delete/');
check('template cannot be deleted', empty($j['result']) && scalar('SELECT COUNT(*) FROM mail_templates') == 4, $raw);

done('mail');
