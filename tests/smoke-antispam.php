<?php
// Ловушка для ботов и минимальное время заполнения (этап 5а, FormGuard): регистрация отклоняет отправку
// с заполненным скрытым полем hp_url и раньше чем через 3 секунды после показа формы. Отказ возвращает
// форму с текстом ERR_FORM_SPAM. Проверяются только отказы; удачная регистрация (с письмом) — в smoke-mail.php.
// Запросы составлены так, чтобы и без защиты письмо не ушло наружу: регистрация идёт на локальный ящик
// (его убирает cleanup-mail.php).
require __DIR__ . '/testlib.php';

const MARK = 'claude-antispam';
$spam = (string)translation('ERR_FORM_SPAM');
check('перевод ERR_FORM_SPAM есть', $spam !== '');
// поля формы со страницы: время показа и ловушка
function guard($html) {
    preg_match('~name="form_ts" value="(\d+)"~', $html, $ts);
    return ['ts' => $ts[1] ?? null, 'trap' => (bool)preg_match('~name="hp_url"~', $html)];
}

echo "-- регистрация\n";
[$c, $html] = http('/register/');
$g = guard($html);
check('форма регистрации несёт время показа и ловушку', $g['ts'] && $g['trap'], json_encode($g));
$registration = ['componentAction' => 'save', 'user_users[u_name]' => MAILBOX, 'user_users[u_fullname]' => MARK];
$cases = [
    'заполненная ловушка' => ['hp_url' => 'x', 'form_ts' => time() - 60],
    'форма отправлена сразу после показа' => ['hp_url' => '', 'form_ts' => time()],
];
foreach ($cases as $label => $extra) {
    $before = (int)scalar('SELECT COUNT(*) FROM user_users');
    [$c, $body] = http('/register/save-new-user/', $registration + $extra);
    check("регистрация: $label — отказ", $c == 200 && clean($body) && $spam !== "" && str_contains($body, $spam), $body);
    check("регистрация: $label — пользователь не создан", (int)scalar('SELECT COUNT(*) FROM user_users') === $before);
}

done('antispam');
