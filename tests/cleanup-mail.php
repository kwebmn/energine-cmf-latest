<?php
// Removes everything smoke-mail.php creates. Usage: php8.5 cleanup-mail.php [mailbox]  ("mailbox" also deletes MAILBOX_FILE)
require __DIR__ . '/testlib.php';

$report = [];
$del = function ($label, $sql, $args = []) use (&$report) {
    $report[] = sprintf('%-32s %d', $label, q($sql, $args)->rowCount());
};

// forms created by smoke-forms.php: through the admin so that their tables are dropped
foreach (q("SELECT DISTINCT form_id FROM frm_forms_translation WHERE form_name IN ('Тестовая форма', 'Тестова форма')")->fetchAll(PDO::FETCH_COLUMN) as $formId) {
    passthru('php8.5 ' . escapeshellarg(__DIR__ . '/del-form.php') . ' ' . (int)$formId);
}
$del('page claude-form-test', "DELETE FROM share_sitemap WHERE smap_segment = 'claude-form-test'");
$del('form_5 results', "DELETE FROM form_5 WHERE form_5_field_2 LIKE 'claude-test%'");
$del('feedback', "DELETE FROM apps_feedback WHERE feed_theme LIKE 'claude-test%'");
$del('subscriptions', "DELETE s FROM mail_subscriptions s JOIN mail_subscriptions_translation t USING(subscription_id) WHERE t.subscription_name LIKE 'claude-test%'");
$del('crm messages', "DELETE c FROM mail_crm c JOIN mail_crm_translation t USING(crm_id) WHERE t.crm_name LIKE 'claude-test%'");
$del('unbound tab rows', "DELETE FROM mail_email2subscriptions WHERE subscription_id IS NULL");
$del('unbound tab users', "DELETE FROM mail_subscriptions2users WHERE subscription_id IS NULL");
$del('e-mail subscribers', "DELETE FROM mail_email_subscribers WHERE me_name IN (?, 'claude-test@loki.kweb.biz', 'claude-test@localhost')", [MAILBOX]);
$del('test user', "DELETE FROM user_users WHERE u_name = ?", [MAILBOX]);
$del('ads items', "DELETE FROM ads_items WHERE ads_item_name LIKE 'claude-test%'");
$del('ads types', "DELETE FROM ads_types WHERE ads_type_sysname LIKE 'claude-test%'");
$del('banner categories', "DELETE FROM share_sitemap WHERE smap_segment LIKE 'claude-test%'");
foreach ([WEB . '/uploads/tmp/mailout.txt'] as $file) {
    $report[] = sprintf('%-32s %d', basename($file), is_file($file) && unlink($file));
}
if (($argv[1] ?? '') === 'mailbox' && is_file(MAILBOX_FILE)) {
    $report[] = sprintf('%-32s %d', MAILBOX_FILE, unlink(MAILBOX_FILE));
}
foreach (glob(__DIR__ . '/cookies-mail-*.txt') as $jar) unlink($jar);
echo implode("\n", $report), "\n";
