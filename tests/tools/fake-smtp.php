<?php
// Поддельный сервер SMTP для smoke-smtp.php: одно соединение на 127.0.0.1, ничего никуда не отправляет.
// Разговор (команды клиента, данные AUTH скрыты) пишется в <журнал>, принятое письмо — в <журнал>.eml
// (точки в начале строк уже сняты), строки DATA как пришли — в <журнал>.data.
//   php8.5 fake-smtp.php <файл-порт> <журнал> <режим> [auth=PLAIN,LOGIN] [password=…] [cert=… key=…]
// Режимы: plain — без шифрования; starttls — предлагает STARTTLS; nostarttls — не предлагает;
// ssl — TLS сразу при соединении. С password=… почта принимается только после AUTH с этим паролем.
[, $portFile, $log, $mode] = $argv + [null, null, null, 'plain'];
$opt = [];
foreach (array_slice($argv, 4) as $a) {
    [$k, $v] = explode('=', $a, 2) + [null, ''];
    $opt[$k] = $v;
}
$auth = array_filter(explode(',', $opt['auth'] ?? ''));
$password = $opt['password'] ?? null;
$tls = stream_context_create(['ssl' => ['local_cert' => $opt['cert'] ?? '', 'local_pk' => $opt['key'] ?? '',
    'verify_peer' => false, 'allow_self_signed' => true]]);

$server = stream_socket_server(($mode === 'ssl' ? 'ssl' : 'tcp') . '://127.0.0.1:0', $errno, $error,
    STREAM_SERVER_BIND | STREAM_SERVER_LISTEN, $tls);
if (!$server) {
    fwrite(STDERR, "fake-smtp: $error\n");
    exit(2);
}
file_put_contents($portFile, parse_url('tcp://' . stream_socket_get_name($server, false), PHP_URL_PORT));
$conn = @stream_socket_accept($server, 20);
if (!$conn) {
    exit(0);   // клиент не пришёл (например, отказался до соединения)
}
stream_set_timeout($conn, 20);
$record = fn($line) => file_put_contents($log, $line . "\n", FILE_APPEND);
$say = function ($line) use ($conn) { fwrite($conn, $line . "\r\n"); };
$read = function () use ($conn) {
    $line = fgets($conn);
    return $line === false ? false : rtrim($line, "\r\n");
};
$secure = ($mode === 'ssl');
$authed = false;
$check = function ($user, $pass) use ($password) { return $password === null || $pass === $password; };

$say('220 fake.test ESMTP');
while (($line = $read()) !== false) {
    $verb = strtoupper(strtok($line, ' '));
    $record(preg_match('/^AUTH /i', $line) ? preg_replace('/^(AUTH \S+).*/i', '$1 ***', $line) : $line);
    switch ($verb) {
        case 'EHLO':
            $caps = ['fake.test'];
            if ($mode === 'starttls' && !$secure) $caps[] = 'STARTTLS';
            if ($auth && ($secure || $mode === 'plain')) $caps[] = 'AUTH ' . implode(' ', $auth);
            $caps[] = '8BITMIME';
            foreach ($caps as $i => $c) $say('250' . ($i === count($caps) - 1 ? ' ' : '-') . $c);
            break;
        case 'STARTTLS':
            if ($mode !== 'starttls' || $secure) { $say('502 5.5.1 not offered'); break; }
            $say('220 2.0.0 go ahead');
            $secure = stream_socket_enable_crypto($conn, true, STREAM_CRYPTO_METHOD_TLS_SERVER);
            if (!$secure) exit(1);
            break;
        case 'AUTH':
            $parts = explode(' ', $line);
            $method = strtoupper($parts[1] ?? '');
            if (!in_array($method, $auth, true)) { $say('504 5.5.4 not supported'); break; }
            if ($method === 'PLAIN') {
                $data = $parts[2] ?? null;
                if ($data === null) { $say('334 '); $data = $read(); $record('***'); }
                [, $user, $pass] = explode("\0", (string)base64_decode((string)$data)) + [null, '', ''];
            } else {
                $say('334 ' . base64_encode('Username:'));
                $user = base64_decode((string)$read()); $record('***');
                $say('334 ' . base64_encode('Password:'));
                $pass = base64_decode((string)$read()); $record('***');
            }
            if ($check($user, $pass)) { $authed = true; $say('235 2.7.0 Authentication successful'); }
            else $say('535 5.7.8 Error: authentication failed');
            break;
        case 'MAIL':
            if ($password !== null && !$authed) { $say('530 5.7.0 Authentication required'); break; }
            $say('250 2.1.0 Ok');
            break;
        case 'RCPT':
            $say('250 2.1.5 Ok');
            break;
        case 'DATA':
            $say('354 End data with <CR><LF>.<CR><LF>');
            $raw = [];
            while (($d = $read()) !== false && $d !== '.') $raw[] = $d;
            file_put_contents($log . '.data', implode("\n", $raw));
            file_put_contents($log . '.eml', implode("\n", array_map(fn($l) => str_starts_with($l, '.') ? substr($l, 1) : $l, $raw)));
            $say('250 2.0.0 Ok: queued');
            break;
        case 'RSET':
        case 'NOOP':
            $say('250 2.0.0 Ok');
            break;
        case 'QUIT':
            $say('221 2.0.0 Bye');
            exit(0);
        default:
            $say('500 5.5.2 unknown command');
    }
}
