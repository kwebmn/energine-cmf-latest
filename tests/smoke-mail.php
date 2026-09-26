<?php
// Mail sending end-to-end on the site from env.php: registration, password restore, feedback, form builder forms,
// mail module (admin editors, public subscription, subscription processor).
// Every real message goes to the local mailbox MAILBOX (tests/local.php) only (recipients are switched before the run).
// No captcha on the site any more; HTML parts are checked for escaped visitor values (markup, quotes, &, line breaks).
// Usage: php8.5 smoke-mail.php            (run cleanup-mail.php afterwards)
require __DIR__ . '/testlib.php';
date_default_timezone_set('Europe/Kyiv');   // as the site (share/gears/ini.func.php)

const MBOX = MAILBOX_FILE;
const TEST_EMAIL = MAILBOX;
const USER_NAME = 'Тестовый пользователь & Co';   // & must become &amp; in HTML parts
const SUBSCRIBE_EMAIL = 'claude-test@loki.kweb.biz';   // only written to mailout.txt (site.debug = 1)
const PROJECT = ROOT;
const MAILOUT = WEB . '/uploads/tmp/mailout.txt';

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
    [$c] = http('/subscriptions/');
    return $c == 200;
}

@unlink(MAILOUT);
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
[$c, $html] = http('/subscriptions/');
check('my subscriptions page without subscriptions', $c == 200 && clean($html), $html);

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
echo "-- form builder: demo form\n";
$off = mboxSize();
[$c, $html] = http('/form-example/');
// a visitor value with markup, quotes and &; the extra field is not a field of the form
$post = formIn($html, 'form-example/send', [DB_NAME . '.form_5[form_5_field_2]' => 'claude-test form 5 & "кавычки" <b>тег</b>', DB_NAME . '.form_5[claude_unknown]' => 'x', DB_NAME . '.form_5[form_5_field_3_email]' => TEST_EMAIL,
    DB_NAME . '.form_5[form_5_field_4_phone]' => '+380441234567', DB_NAME . '.form_5[form_5_field_5_multi][]' => ['1', '3'],
    DB_NAME . '.form_5[form_5_field_6]' => '2']);
[$c, $body] = http('/form-example/send/', $post);
$pk = scalar("SELECT pk_id FROM form_5 WHERE form_5_field_2 LIKE 'claude-test form 5%'");
check("form 5 result saved (pk $pk, HTTP $c)", $pk && $c == 302, $body);
check('form 5 multi values saved', $pk && q('SELECT fk_id FROM form_5_field_5_multi WHERE pk_id = ? ORDER BY fk_id', [$pk])->fetchAll(PDO::FETCH_COLUMN) == ['1', '3']);
$formName = scalar('SELECT form_name FROM frm_forms_translation WHERE form_id = 5 AND lang_id = 1');
$messages = mboxWait($off, 1);
$m = bySubject($messages, translation('TXT_EMAIL_FROM_FORM') . ' ' . $formName);
check('form 5 mail delivered', $m && $m['to'] === TEST_EMAIL && str_contains($m['text'], "Строка: claude-test form 5 & \"кавычки\" тег\n") && str_contains($m['text'], 'Первое,Третье')
    && str_contains($m['text'], 'Выпадающий список: Второй') && !str_contains($m['raw'], 'CLAUDE_UNKNOWN'), brief($messages) . ($m['raw'] ?? ''));
check('form 5 mail: value escaped in HTML', $m && str_contains($m['html'], '<strong>Строка</strong>: claude-test form 5 &amp; &quot;кавычки&quot; тег<br>'), $m['html'] ?? '');

// =====================================================================================================
echo "-- form builder: new form on a new page\n";
exec('php8.5 ' . escapeshellarg(__DIR__ . '/smoke-forms.php') . ' keep', $out, $rc);
$formId = preg_match('/FORM_ID=(\d+)/', implode("\n", $out), $mm) ? (int)$mm[1] : 0;
check("form created in the constructor (form $formId)", $rc == 0 && $formId, implode("\n", array_filter($out, fn($l) => !str_starts_with($l, 'OK'))));
freshJar('admin');
login();
$pageSegment = 'claude-form-test';
$page = ['componentAction' => 'add', 'share_sitemap' => ['smap_id' => '', 'smap_pid' => '80', 'site_id' => '1', 'smap_layout' => 'default.layout.xml',
    'smap_content' => 'form.content.xml', 'smap_segment' => $pageSegment, 'smap_redirect_url' => ''],
    'right_id' => [1 => 3, 3 => 1, 4 => 1], 'tags' => '',
    'share_sitemap_translation' => [1 => ['smap_name' => 'Тестовая форма'], 2 => ['smap_name' => 'Тестова форма']]];
[$c, $j, $raw] = json('/admin/structure/single/divEditor/save', http_build_query($page));
$smapId = scalar('SELECT smap_id FROM share_sitemap WHERE smap_segment = ?', [$pageSegment]);
check("page created ($smapId)", !empty($j['result']) && $smapId, $raw);
[$c, $html] = http("/$pageSegment/", ['editMode' => 1]);
$panel = preg_match("~new PageToolbar\\('([^']+)'~", $html, $mm) ? $mm[1] : BASE . "/$pageSegment/single/adminPanel/";
$contentXml = preg_match('~<param name="id">0</param>~', file_get_contents(WEB . '/templates/content/form.content.xml')) ? file_get_contents(WEB . '/templates/content/form.content.xml') : '';
$contentXml = str_replace('<param name="id">0</param>', "<param name=\"id\">$formId</param>", $contentXml);
[$c, $j, $raw] = json($panel . 'widgets/save-content/', http_build_query(['xml' => $contentXml]));
check('form attached to the page (save-content)', !empty($j['result']) && str_contains((string)scalar('SELECT smap_content_xml FROM share_sitemap WHERE smap_id = ?', [$smapId]), "<param name=\"id\">$formId</param>"), $raw);
freshJar('guest');
$off = mboxSize();
[$c, $html] = http("/$pageSegment/");
check('new form rendered without captcha', $c == 200 && clean($html) && str_contains($html, "form_$formId") && stripos($html, 'captcha') === false, $html);
$fields = [];
foreach (q("SHOW COLUMNS FROM form_$formId")->fetchAll() as $col) $fields[$col['Field']] = $col['Type'];
$set = [];
$prefix = DB_NAME . ".form_$formId";
foreach ($fields as $name => $type) {
    if (in_array($name, ['pk_id', 'form_date'])) continue;
    if (str_ends_with($name, '_email')) $set["{$prefix}[$name]"] = TEST_EMAIL;
    elseif (str_ends_with($name, '_phone')) $set["{$prefix}[$name]"] = '+380441234567';
    elseif (str_starts_with($type, 'datetime')) $set["{$prefix}[$name]"] = '2026-09-13 12:30:00';
    elseif (str_starts_with($type, 'date')) $set["{$prefix}[$name]"] = '2026-09-13';
    elseif (str_starts_with($type, 'tinyint')) $set["{$prefix}[$name]"] = '1';
    elseif (str_ends_with($name, '_multi')) $set["{$prefix}[$name][]"] = scalar("SELECT MIN(fk_id) FROM {$name}_values");
    elseif (preg_match('/^int/', $type)) $set["{$prefix}[$name]"] = scalar("SELECT MIN(fk_id) FROM $name");
    elseif ($type === 'text') $set["{$prefix}[$name]"] = "claude-test new form\nвторая строка";
    else $set["{$prefix}[$name]"] = 'claude-test new form';
}
[$c, $body] = http("/$pageSegment/send/", formIn($html, "$pageSegment/send", $set));
$rows = (int)scalar("SELECT COUNT(*) FROM form_$formId");
check("new form result saved (HTTP $c, rows $rows)", $c == 302 && $rows == 1, $body . json_encode($set, JSON_UNESCAPED_UNICODE));
$messages = mboxWait($off, 1);
$m = bySubject($messages, translation('TXT_EMAIL_FROM_FORM') . ' Тестовая форма');
check('new form mail delivered', $m && $m['to'] === TEST_EMAIL && str_contains($m['text'], 'claude-test new form') && str_contains($m['html'], "claude-test new form<br>\nвторая строка"), brief($messages) . ($m['html'] ?? ''));
jar('admin');
[$c, $j, $raw] = json("/admin/form-builder/single/formEditor/$formId/results/get-data/page-1");
check('result visible in the admin results grid', $c == 200 && count($j['data'] ?? []) == 1, $raw);

// =====================================================================================================
echo "-- mail module: templates editor\n";
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

// =====================================================================================================
echo "-- mail module: CRM messages\n";
$C = '/admin/mail-crm/single/mailCRMEditor/';
[$c, $html] = http($C . 'add/');
check('CRM add form', $c == 200 && clean($html), $html);
[$c, $j, $raw] = json($C . 'save', formData($html, ['mail_crm[crm_date]' => date('Y-m-d H:i:s'), 'mail_crm[crm_is_active]' => '1',
    'mail_crm_translation[1][crm_name]' => 'claude-test CRM', 'mail_crm_translation[1][crm_text_rtf]' => '<p>Текст <b>сообщения</b> CRM &amp; Co</p>',
    'mail_crm_translation[2][crm_name]' => 'claude-test CRM ua', 'mail_crm_translation[2][crm_text_rtf]' => '<p>Текст повідомлення</p>']));
$crmId = (int)($j['data'] ?? 0);
check("CRM message saved ($crmId)", !empty($j['result']) && $crmId, $raw);

// =====================================================================================================
echo "-- mail module: subscriptions editor with tabs of a new subscription\n";
$E = '/admin/mail-subscriptions/single/mailSubscriptionEditor/';
[$c, $html] = http($E . 'add/');
check('subscription add form with tabs', $c == 200 && clean($html) && str_contains($html, 'mailSubscriptionEditor//email/'), $html);
$addHtml = $html;
[$c, $html] = http($E . '/email/');       // URL of the tab as built by the form (double slash)
check('emails tab of an unsaved subscription', $c == 200 && clean($html) && str_contains($html, translation('TAB_SUBSCRIBED_EMAILS')), $html);
[$c, $html] = http($E . 'email/add/');
[$c, $j, $raw] = json($E . 'email/save/', formData($html, ['mail_email_subscribers[me_name]' => TEST_EMAIL]));
check('e-mail added in the tab', !empty($j['result']) && scalar('SELECT COUNT(*) FROM mail_email2subscriptions es JOIN mail_email_subscribers e USING(me_id) WHERE e.me_name = ? AND es.subscription_id IS NULL AND es.session_id IS NOT NULL', [TEST_EMAIL]), $raw);
[$c, $j, $raw] = json($E . 'email/save/', formData($html, ['mail_email_subscribers[me_name]' => 'not an e-mail']));
check('invalid e-mail rejected in the tab', empty($j['result']), $raw);
[$c, $html] = http($E . '/users/');
check('users tab of an unsaved subscription', $c == 200 && clean($html), $html);
[$c, $html] = http($E . 'users/add/');
$lookup = $E . 'users//' . (preg_match('~data-url="/([^"]+)"~', $html, $mm) ? $mm[1] : 'no-lookup/') . 'get-data/';   // Lookup.js: component path + data-url
foreach (['Тестовый' => 'u_fullname', 'loki.kweb' => 'u_name'] as $term => $field) {
    [$c, $j, $raw] = json($lookup, http_build_query(['filter' => json_encode(['children' => [['field' => '[user_users][u_name]', 'condition' => 'like', 'type' => 'string', 'operator' => '', 'value' => $term]]])]));
    check("users lookup finds the user by $field", !empty($j['result']) && in_array((string)$uid, array_column($j['data'] ?? [], 'u_id')), $raw);
}
[$c, $j, $raw] = json($E . 'users/save/', formData($html, ['mail_subscriptions2users[u_id]' => (string)$uid]));
check('user added in the tab', !empty($j['result']) && scalar('SELECT COUNT(*) FROM mail_subscriptions2users WHERE u_id = ? AND subscription_id IS NULL', [$uid]), $raw);
[$c, $j, $raw] = json($E . 'users/get-data/');
check('users tab lists the user', count($j['data'] ?? []) == 1, $raw);
[$c, $j, $raw] = json($E . 'save', formData($addHtml, ['mail_subscriptions[subscription_type]' => 'crm', 'mail_subscriptions[subscription_period]' => 'daily',
    'mail_subscriptions[subscription_is_active]' => '1', 'mail_subscriptions[subscription_is_default]' => '0', 'mail_subscriptions[subscription_is_hidden]' => '1',
    'mail_subscriptions_translation[1][subscription_name]' => 'claude-test CRM рассылка', 'mail_subscriptions_translation[2][subscription_name]' => 'claude-test CRM розсилка']));
$crmSub = (int)($j['data'] ?? 0);
check("CRM subscription saved ($crmSub)", !empty($j['result']) && $crmSub, $raw);
check('tab rows bound to the saved subscription',
    scalar('SELECT COUNT(*) FROM mail_email2subscriptions WHERE subscription_id = ? AND session_id IS NULL', [$crmSub]) == 1
    && scalar('SELECT COUNT(*) FROM mail_subscriptions2users WHERE subscription_id = ? AND session_id IS NULL', [$crmSub]) == 1);
[$c, $html] = http($E . "$crmSub/edit/");
check('subscription edit form', $c == 200 && clean($html) && str_contains($html, "mailSubscriptionEditor/$crmSub/email/"), $html);
[$c, $j, $raw] = json($E . "$crmSub/email/get-data/");
check('emails tab of the saved subscription', count($j['data'] ?? []) == 1, $raw);
[$c, $html] = http($E . 'add/');
[$c, $j, $raw] = json($E . 'save', formData($html, ['mail_subscriptions[subscription_type]' => 'news', 'mail_subscriptions[subscription_period]' => 'weekly',
    'mail_subscriptions[subscription_is_active]' => '1', 'mail_subscriptions[subscription_is_default]' => '1', 'mail_subscriptions[subscription_is_hidden]' => '0',
    'mail_subscriptions_translation[1][subscription_name]' => 'claude-test новости', 'mail_subscriptions_translation[1][subscription_description]' => 'Еженедельный обзор',
    'mail_subscriptions_translation[2][subscription_name]' => 'claude-test новини', 'mail_subscriptions_translation[2][subscription_description]' => 'Щотижневий огляд']));
$newsSub = (int)($j['data'] ?? 0);
check("news subscription saved ($newsSub)", !empty($j['result']) && $newsSub, $raw);
[$c, $j, $raw] = json($E . 'get-data/');
// в базе есть демо-рассылки, поэтому ищем в списке свои
$ids = array_column($j['data'] ?? [], 'subscription_id');
check('subscriptions grid', in_array($crmSub, $ids) && in_array($newsSub, $ids), $raw);

// =====================================================================================================
echo "-- public e-mail subscription\n";
freshJar('guest');
[$c, $html] = http('/subscribe/');
$single = singleTemplate($html, 'emailSubscription');
check('subscribe page', $c == 200 && clean($html) && $single && str_contains($html, 'action="/subscribe-now/"'), $html);
[$c, $j, $raw] = json($single . '/subscribe-now/', http_build_query(['email' => SUBSCRIBE_EMAIL]));   // SubscriptionForm.js: single_template + action
check('subscribed', !empty($j['result']) && ($j['message'] ?? '') === translation('MSG_SUBSCRIBED')
    && scalar('SELECT COUNT(*) FROM mail_email2subscriptions es JOIN mail_email_subscribers e USING(me_id) WHERE e.me_name = ? AND es.subscription_id = ?', [SUBSCRIBE_EMAIL, $newsSub]) == 1, $raw);
[$c, $j, $raw] = json($single . 'subscribe-now/', http_build_query(['email' => SUBSCRIBE_EMAIL]));
check('second subscription of the same address', empty($j['result']) && ($j['message'] ?? '') === translation('ERR_MAIL_EXISTS'), $raw);
[$c, $j, $raw] = json($single . 'subscribe-now/', http_build_query(['email' => 'broken@']));
check('invalid address', empty($j['result']) && ($j['message'] ?? '') === translation('ERR_BAD_EMAIL'), $raw);
[$c, $j, $raw] = json('/admin/mail-subscribers/single/mailSubscriptionEditor/get-data/');
check('guest has no access to the subscribers grid', empty($j['data']), $raw);

echo "-- subscribers editor\n";
jar('admin');
$SE = '/admin/mail-subscribers/single/mailSubscriptionEditor/';
[$c, $j, $raw] = json($SE . 'get-data/');
$mails = array_column($j['data'] ?? [], 'me_name');
check('subscribers grid lists both addresses', in_array(TEST_EMAIL, $mails) && in_array(SUBSCRIBE_EMAIL, $mails), $raw);
[$c, $html] = http($SE . 'add/');
[$c, $j, $raw] = json($SE . 'save', formData($html, ['mail_email_subscribers[me_name]' => 'claude-test@localhost', 'mail_email_subscribers[me_date]' => date('Y-m-d H:i:s')]));
$meId = (int)($j['data'] ?? 0);
check("subscriber added ($meId)", !empty($j['result']) && $meId, $raw);
[$c, $html] = http($SE . "$meId/edit/");
check('subscriber edit form', $c == 200 && clean($html) && str_contains($html, 'claude-test@localhost'), $html);
[$c, $j, $raw] = json($SE . "$meId/delete/");
check('subscriber deleted', !empty($j['result']) && !scalar('SELECT COUNT(*) FROM mail_email_subscribers WHERE me_id = ?', [$meId]), $raw);

// =====================================================================================================
echo "-- my subscriptions (registered user)\n";
jar('user');
[$c, $html] = http('/subscriptions/');
check('subscriptions page lists visible subscriptions only', $c == 200 && clean($html) && str_contains($html, 'claude-test новости') && str_contains($html, 'Еженедельный обзор') && !str_contains($html, 'claude-test CRM'), $html);
$dataUrl = preg_match('~data-url="([^"]+)"~', $html, $mm) ? html_entity_decode($mm[1]) : '';
check("toggle URL $dataUrl", str_starts_with($dataUrl, BASE . '/subscriptions/single/subscriptions/toggle/'), $html);
[$c, $j, $raw] = json($dataUrl . "$newsSub/");
check('toggle: subscribed', !empty($j['result']) && ($j['message'] ?? '') === translation('TXT_SUBSCRIBED') && scalar('SELECT COUNT(*) FROM mail_subscriptions2users WHERE u_id = ? AND subscription_id = ?', [$uid, $newsSub]) == 1, $raw);
[$c, $html] = http('/subscriptions/');
check('checkbox is checked', (bool)preg_match('~value="' . $newsSub . '"\s+checked~', $html), $html);
[$c, $j, $raw] = json($dataUrl . "$newsSub/");
check('toggle: unsubscribed', !empty($j['result']) && ($j['message'] ?? '') === translation('TXT_UNSUBSCRIBED') && !scalar('SELECT COUNT(*) FROM mail_subscriptions2users WHERE u_id = ? AND subscription_id = ?', [$uid, $newsSub]), $raw);
[$c, $j, $raw] = json($dataUrl . "$newsSub/");
freshJar('guest');
[$c, $j, $raw] = json("/subscriptions/single/subscriptions/toggle/$newsSub/");
check("guest cannot toggle (HTTP $c)", empty($j['result']), $raw);

// =====================================================================================================
echo "-- subscription processor (site.debug = 1: messages are written to uploads/tmp/mailout.txt)\n";
$cmd = 'cd ' . escapeshellarg(PROJECT . '/cli') . ' && runuser -u ' . SITE_USER . ' -- php8.5 mail_sender.php run 2>&1';
exec($cmd, $out1, $rc);
$log = implode("\n", $out1);
$activeSubs = (int)scalar('SELECT COUNT(*) FROM mail_subscriptions WHERE subscription_is_active = 1');
check('processor run', $rc == 0 && str_contains($log, "Found $activeSubs active subscriptions") && !preg_match('/Error|Exception|Warning|Deprecated/', $log), $log);
check('CRM digest to the user and the e-mail (deduplicated)', str_contains($log, 'Sending crm mail to ' . TEST_EMAIL) && substr_count($log, 'Sending crm mail') == 1, $log);
check('news digest to the subscribed users/e-mails', str_contains($log, 'Sending news mail to ' . SUBSCRIBE_EMAIL) && str_contains($log, 'Sending news mail to ' . TEST_EMAIL), $log);
$mailout = is_file(MAILOUT) ? file_get_contents(MAILOUT) : '';
preg_match_all('~SUBJECT: =\?UTF-8\?B\?([^?]+)\?=~', $mailout, $mm);
$subjects = array_map('base64_decode', $mm[1]);
check('mailout subjects: ' . implode(' | ', $subjects), in_array('Информационная рассылка', $subjects) && in_array('Новости сайта', $subjects), $mailout);
check('CRM item in the digest: text decoded, HTML escaped', str_contains($mailout, 'claude-test CRM (' . date('d.m.Y') . ")\nТекст сообщения CRM & Co\n")
    && str_contains($mailout, '<h3>claude-test CRM</h3>') && str_contains($mailout, '<p>Текст сообщения CRM &amp; Co</p>'), $mailout);
check('subscriber name escaped in the HTML part of the digest', str_contains($mailout, 'Здравствуйте, ' . USER_NAME . "!\n") && str_contains($mailout, '<p>Здравствуйте, Тестовый пользователь &amp; Co!</p>'), $mailout);
check('news item link in the digest', (bool)preg_match('~<a href="http://' . preg_quote(parse_url(BASE, PHP_URL_HOST), '~') . '/news/\d+--[^"]+/"><strong>~', $mailout), $mailout);
check('sent dates stored', scalar('SELECT COUNT(*) FROM mail_subscriptions WHERE subscription_sent_date IS NOT NULL AND subscription_id IN (?, ?)', [$crmSub, $newsSub]) == 2);
exec($cmd, $out2, $rc);
check('second run waits for the period', $rc == 0 && substr_count(implode("\n", $out2), 'Processing is not required') == $activeSubs, implode("\n", $out2));

done('mail');
