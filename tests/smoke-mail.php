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
        $part = function ($type) use ($body) {
            return preg_match('~Content-Type: text/' . $type . '; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n(.*?)\n\n--~s', $body, $m) ? $m[1] : '';
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

$siteName = scalar('SELECT site_name FROM share_sites_translation st JOIN share_sites s USING(site_id) WHERE s.site_is_default = 1 AND st.lang_id = 1');

// =====================================================================================================
echo "-- registration\n";
freshJar('user');
$off = mboxSize();
[$c, $html] = http('/register/');
check('register page without captcha', $c == 200 && clean($html) && stripos($html, 'captcha') === false, $html);
$registration = ['user_users[u_name]' => TEST_EMAIL, 'user_users[u_fullname]' => USER_NAME];
[$c, $body] = http('/register/save-new-user/', formIn($html, 'register/save-new-user', $registration));
$uid = scalar('SELECT u_id FROM user_users WHERE u_name = ?', [TEST_EMAIL]);
$formError = preg_match('~<div class="alert[^"]*"[^>]*>(.*?)</div>~s', $body, $mm) ? strip_tags($mm[1]) : '';
check("user registered (u_id $uid, HTTP $c) $formError", $uid && $c == 302 && scalar('SELECT COUNT(*) FROM user_user_groups WHERE u_id = ? AND group_id = 4', [$uid]), $body);
$messages = mboxWait($off, 1);
$m = bySubject($messages, 'Регистрация на сайте ' . translation('TXT_SITE_NAME'));
check('registration mail delivered', $m && $m['to'] === TEST_EMAIL && count($messages) == 1 && str_contains($m['text'], 'Здравствуйте, ' . USER_NAME . '!'), brief($messages));
check('registration mail: name escaped in HTML', $m && str_contains($m['html'], 'Здравствуйте, Тестовый пользователь &amp; Co!'), $m['html'] ?? '');
$password = ($m && preg_match('/Пароль: (\S+)/u', $m['text'], $mm)) ? $mm[1] : null;
check('HTML part has the password', $m && $password && str_contains($m['html'], "<strong>$password</strong>"), $m['html'] ?? '');
check('login with the mailed password', $password && loginAs(TEST_EMAIL, $password));

// =====================================================================================================
echo "-- restore password\n";
freshJar('guest');
$off = mboxSize();
[$c, $html] = http('/restore-password/');
[$c, $body] = http('/restore-password/send/', formIn($html, 'restore-password/send', ['u_name' => TEST_EMAIL]));
check("restore form answer (HTTP $c)", $c == 200 && clean($body) && str_contains($body, translation('MSG_PASSWORD_SENT')), $body);
$messages = mboxWait($off, 1);
$m = bySubject($messages, "Новый пароль для сайта $siteName");
check('restore mail delivered', $m && $m['to'] === TEST_EMAIL && str_contains($m['text'], 'Уважаемый(ая) ' . USER_NAME . '!') && str_contains($m['html'], 'Уважаемый(ая) Тестовый пользователь &amp; Co!'), brief($messages));
$newPassword = ($m && preg_match('/новый пароль: (\S+)/u', $m['text'], $mm)) ? $mm[1] : null;
check('old password rejected, new one accepted', $newPassword && $newPassword !== $password && !loginAs(TEST_EMAIL, (string)$password)
    && (freshJar('user') || true) && loginAs(TEST_EMAIL, $newPassword));
[$c, $body] = http('/restore-password/send/', ['componentAction' => 'send', 'u_name' => 'nobody-' . getmypid() . '@localhost']);
check('restore for unknown user', $c == 200 && clean($body) && str_contains($body, translation('ERR_NO_U_NAME')), $body);

// =====================================================================================================
echo "-- feedback form\n";
freshJar('guest');
$off = mboxSize();
[$c, $html] = http('/contacts/');
check('feedback form without captcha', $c == 200 && clean($html) && stripos($html, 'captcha') === false, $html);
$feedback = ['apps_feedback[feed_author]' => 'Claude <b>Test</b>', 'apps_feedback[feed_email]' => TEST_EMAIL,
    'apps_feedback[feed_theme]' => 'claude-test feedback', 'apps_feedback[feed_text]' => "Проверка <script>alert(1)</script> & \"кавычки\"\nвторая строка [feed_email]"];
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
check('templates grid lists 8 templates', $c == 200 && count($j['data'] ?? []) == 8, $raw);
[$c, $html] = http($T . '1/edit/');
check('template edit form', $c == 200 && clean($html) && str_contains($html, 'user_registration'), $html);
$before = q('SELECT * FROM mail_templates_translation WHERE template_id = 1 ORDER BY lang_id')->fetchAll();
[$c, $j, $raw] = json($T . 'save', formData($html));
$after = q('SELECT * FROM mail_templates_translation WHERE template_id = 1 ORDER BY lang_id')->fetchAll();
check('template saved without changes', !empty($j['result']) && $before == $after, $raw . ' ' . json_encode([$before, $after], JSON_UNESCAPED_UNICODE));
[$c, $j, $raw] = json($T . '1/delete/');
check('template cannot be deleted', empty($j['result']) && scalar('SELECT COUNT(*) FROM mail_templates') == 8, $raw);

done('mail');
