<?php
// Ловушка для ботов и минимальное время заполнения (этап 5а, FormGuard): обратная связь и регистрация
// отклоняют отправку с заполненным скрытым полем hp_url, без времени показа формы form_ts и раньше
// чем через 3 секунды после показа. Отказ возвращает форму с введённым и текстом ERR_FORM_SPAM.
// Проверяются только отказы; удачные отправки (с письмами) — в smoke-mail.php. Запросы составлены так,
// чтобы и без защиты письмо не ушло наружу: у обратной связи нет получателя и e-mail посетителя,
// регистрация идёт на локальный ящик (его убирает cleanup-mail.php).
require __DIR__ . '/testlib.php';

const MARK = 'claude-antispam';
$spam = (string)translation('ERR_FORM_SPAM');
check('перевод ERR_FORM_SPAM есть', $spam !== '');
$cleanup = function () {
    q('DELETE FROM apps_feedback WHERE feed_theme = ?', [MARK]);
};
$cleanup();
register_shutdown_function($cleanup);

// поля формы со страницы: время показа и ловушка
function guard($html) {
    preg_match('~name="form_ts" value="(\d+)"~', $html, $ts);
    return ['ts' => $ts[1] ?? null, 'trap' => (bool)preg_match('~name="hp_url"~', $html)];
}

echo "-- обратная связь\n";
[$c, $html] = http('/contacts/');
$g = guard($html);
check('форма несёт время показа и ловушку', $g['ts'] && $g['trap'], json_encode($g));
$feedback = ['componentAction' => 'send', 'apps_feedback[feed_author]' => MARK . '-author', 'apps_feedback[feed_theme]' => MARK,
    'apps_feedback[feed_text]' => MARK . ' text'];
$cases = [
    'заполненная ловушка' => ['hp_url' => 'https://spam.example/', 'form_ts' => time() - 60],
    'форма отправлена сразу после показа' => ['hp_url' => '', 'form_ts' => time()],
    'без времени показа' => ['hp_url' => ''],
];
foreach ($cases as $label => $extra) {
    [$c, $body] = http('/contacts/send/', $feedback + $extra);
    check("обратная связь: $label — отказ", $c == 200 && clean($body) && $spam !== "" && str_contains($body, $spam), $body);
    check("обратная связь: $label — введённое вернулось в форму", str_contains($body, MARK . ' text'), $body);
}
check('обратная связь: ничего не сохранено', (int)scalar('SELECT COUNT(*) FROM apps_feedback WHERE feed_theme = ?', [MARK]) === 0);

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
