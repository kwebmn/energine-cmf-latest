<?php
// Removes everything smoke-mail.php creates. Usage: php8.5 cleanup-mail.php [mailbox]  ("mailbox" also deletes MAILBOX_FILE)
require __DIR__ . '/testlib.php';

$report = [];
$del = function ($label, $sql, $args = []) use (&$report) {
    $report[] = sprintf('%-32s %d', $label, q($sql, $args)->rowCount());
};

$del('test user', "DELETE FROM user_users WHERE u_name = ?", [MAILBOX]);
if (($argv[1] ?? '') === 'mailbox' && is_file(MAILBOX_FILE)) {
    $report[] = sprintf('%-32s %d', MAILBOX_FILE, unlink(MAILBOX_FILE));
}
foreach (glob(__DIR__ . '/cookies-mail-*.txt') as $jar) unlink($jar);
echo implode("\n", $report), "\n";
