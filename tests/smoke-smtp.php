<?php
// Почта через SMTP (этап 5б): Mail и SmtpTransport против поддельного сервера (tools/fake-smtp.php) во всех
// режимах и против postfix этой машины — с доставкой в локальный ящик MAILBOX. Конфиг площадки не
// трогается: mail.smtp задаётся в памяти процесса. Наружу письма не уходят: поддельный сервер ничего не
// пересылает, настоящему письмо идёт только на локальный ящик. Запускается в почтовом разделе regression.sh.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\Mail;
use Energine\share\gears\Primitive;
use Energine\share\gears\SmtpTransport;

const FROM = 'noreply@simple.energine.org';
const SUBJECT = 'Проверка SMTP: тема — UTF-8';
const TEXT = "Первая строка\n.\n.точка в начале\nпоследняя";

// без транспорта Mail с mail.smtp пошёл бы через mail(): тест останавливается до любой отправки
if (!class_exists(SmtpTransport::class)) {
    check('класс SmtpTransport есть', false);
    done('smtp');
}
// все адреса — локальные: даже при ошибке реализации письмо не выйдет за пределы машины
const TO1 = MAILBOX;
const TO2 = 'root@localhost';

$dir = sys_get_temp_dir() . '/smtp-test-' . getmypid();
mkdir($dir, 0700);
register_shutdown_function(function () use ($dir) { exec('rm -rf ' . escapeshellarg($dir)); });
exec('openssl req -x509 -newkey rsa:2048 -nodes -keyout ' . escapeshellarg("$dir/key.pem") . ' -out ' . escapeshellarg("$dir/cert.pem")
    . ' -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1 2>/dev/null', $out, $rc);
check('самоподписанный сертификат для поддельного сервера', $rc === 0 && is_file("$dir/cert.pem"));

// поддельный сервер в фоне: [port, log, proc]
function fake($mode, array $opts = []) {
    static $n = 0;
    global $dir;
    $n++;
    $portFile = "$dir/port$n";
    $log = "$dir/log$n";
    $cmd = array_merge([PHP_BINARY, ROOT . '/tests/tools/fake-smtp.php', $portFile, $log, $mode],
        $opts, ["cert=$dir/cert.pem", "key=$dir/key.pem"]);
    $proc = proc_open($cmd, [['file', '/dev/null', 'r'], ['file', "$dir/out$n", 'w'], ['file', "$dir/err$n", 'w']], $pipes);
    for ($i = 0; $i < 50 && !(@filesize($portFile)); $i++) {
        usleep(100000);
        clearstatcache();
    }
    return ['port' => (int)@file_get_contents($portFile), 'log' => $log, 'proc' => $proc];
}
// дождаться конца разговора и вернуть журнал
function finish($f) {
    for ($i = 0; $i < 50 && proc_get_status($f['proc'])['running']; $i++) usleep(100000);
    proc_terminate($f['proc']);
    proc_close($f['proc']);
    return (string)@file_get_contents($f['log']);
}
function smtp(array $smtp) {
    Primitive::setConfig(['mail' => ['from' => FROM, 'smtp' => $smtp], 'site' => ['domain' => 'simple.energine.org']]);
}
function message($to) {
    $m = new Mail();
    $m->setFrom(FROM, 'Сайт «Тест»')->setSubject(SUBJECT)->setText(TEXT)->setHtmlText('<p>HTML <b>часть</b></p>');
    foreach ((array)$to as $t) $m->addTo($t);
    return $m;
}
// заголовок письма, раскодированный
function header_of($eml, $name) {
    $head = explode("\n\n", str_replace("\r\n", "\n", $eml), 2)[0];
    $head = preg_replace("/\n[ \t]+/", ' ', $head);
    return preg_match('/^' . preg_quote($name, '/') . ':\s*(.*)$/mi', $head, $m) ? iconv_mime_decode($m[1], 0, 'UTF-8') : null;
}
$fails = function (callable $f) {
    try {
        $f();
        return null;
    } catch (\Throwable $e) {
        return $e;
    }
};

echo "-- без шифрования, без AUTH\n";
$f = fake('plain');
smtp(['host' => '127.0.0.1', 'port' => $f['port'], 'encryption' => '', 'timeout' => 10]);
$sent = message([TO1, TO2])->send();
$log = finish($f);
$eml = (string)@file_get_contents($f['log'] . '.eml');
$data = (string)@file_get_contents($f['log'] . '.data');
check('письмо принято', $sent === true && str_contains($log, 'DATA'), $log);
check('конверт: отправитель и оба получателя', str_contains($log, 'MAIL FROM:<' . FROM . '>')
    && str_contains($log, 'RCPT TO:<' . TO1 . '>') && str_contains($log, 'RCPT TO:<' . TO2 . '>'), $log);
check('заголовки: тема и отправитель в UTF-8, получатели, дата, Message-ID', header_of($eml, 'Subject') === SUBJECT
    && header_of($eml, 'From') === 'Сайт «Тест» <' . FROM . '>' && str_contains((string)header_of($eml, 'To'), TO2)
    && header_of($eml, 'Date') && preg_match('/^<[^@>]+@simple\.energine\.org>$/', (string)header_of($eml, 'Message-ID')), $eml);
check('строки из точки удвоены в разговоре и восстановлены в письме', preg_match('/^\.\.$/m', $data)
    && preg_match('/^\.\.точка в начале$/m', $data) && str_contains(str_replace("\r\n", "\n", $eml), TEXT), $data);
check('HTML-часть на месте', str_contains($eml, '<p>HTML <b>часть</b></p>'), $eml);

echo "-- STARTTLS и AUTH LOGIN\n";
$f = fake('starttls', ['auth=LOGIN', 'password=s3cret-login']);
smtp(['host' => 'localhost', 'port' => $f['port'], 'encryption' => 'tls', 'username' => 'claude', 'password' => 's3cret-login',
    'cafile' => "$dir/cert.pem", 'timeout' => 10]);
$sent = message(TO1)->send();
$log = finish($f);
check('письмо принято после STARTTLS и AUTH LOGIN', $sent === true && preg_match('/STARTTLS\n(EHLO|HELO)/', $log)
    && str_contains($log, 'AUTH LOGIN ***') && str_contains($log, 'MAIL FROM'), $log);

echo "-- SSL и AUTH PLAIN\n";
$f = fake('ssl', ['auth=PLAIN', 'password=s3cret-plain']);
smtp(['host' => 'localhost', 'port' => $f['port'], 'encryption' => 'ssl', 'username' => 'claude', 'password' => 's3cret-plain',
    'cafile' => "$dir/cert.pem", 'timeout' => 10]);
$sent = message(TO1)->send();
$log = finish($f);
check('письмо принято по SSL после AUTH PLAIN', $sent === true && str_contains($log, 'AUTH PLAIN ***') && str_contains($log, 'MAIL FROM'), $log);

echo "-- отказы\n";
$f = fake('plain', ['auth=PLAIN', 'password=right-one']);
$e = $fails(function () use ($f) {
    (new SmtpTransport(['host' => '127.0.0.1', 'port' => $f['port'], 'encryption' => '', 'username' => 'claude',
        'password' => 'wrong-one-123', 'timeout' => 10]))->send(FROM, [TO1], "Subject: x\r\n\r\nx");
});
$log = finish($f);
check('неверный пароль — исключение с ответом сервера, пароля в тексте нет', $e && str_contains($e->getMessage(), '535')
    && !str_contains($e->getMessage(), 'wrong-one-123') && !str_contains($log, 'MAIL FROM'), $e ? $e->getMessage() : 'нет исключения');
$f = fake('plain', ['auth=PLAIN', 'password=right-one']);
smtp(['host' => '127.0.0.1', 'port' => $f['port'], 'encryption' => '', 'username' => 'claude', 'password' => 'wrong-one-123', 'timeout' => 10]);
check('Mail::send при отказе сервера возвращает false', message(TO1)->send() === false);
finish($f);

$port = (function () {
    $s = stream_socket_server('tcp://127.0.0.1:0');
    $p = (int)parse_url('tcp://' . stream_socket_get_name($s, false), PHP_URL_PORT);
    fclose($s);
    return $p;
})();
$e = $fails(function () use ($port) {
    (new SmtpTransport(['host' => '127.0.0.1', 'port' => $port, 'encryption' => '', 'timeout' => 5]))->send(FROM, [TO1], "x");
});
check('сервер недоступен — исключение', $e && $e->getMessage() !== '', $e ? $e->getMessage() : 'нет исключения');

$f = fake('nostarttls');
$e = $fails(function () use ($f, $dir) {
    (new SmtpTransport(['host' => 'localhost', 'port' => $f['port'], 'encryption' => 'tls', 'cafile' => "$dir/cert.pem", 'timeout' => 10]))
        ->send(FROM, [TO1], "Subject: x\r\n\r\nx");
});
$log = finish($f);
check('сервер без STARTTLS при encryption=tls — отказ, письмо открытым текстом не ушло', $e && !str_contains($log, 'MAIL FROM'),
    ($e ? $e->getMessage() : 'нет исключения') . ' | ' . $log);

$f = fake('starttls');
$e = $fails(function () use ($f) {
    (new SmtpTransport(['host' => 'localhost', 'port' => $f['port'], 'encryption' => 'tls', 'timeout' => 10]))
        ->send(FROM, [TO1], "Subject: x\r\n\r\nx");
});
$log = finish($f);
check('сертификат сервера проверяется (самоподписанный без cafile — отказ)', $e && !str_contains($log, 'MAIL FROM'),
    ($e ? $e->getMessage() : 'нет исключения') . ' | ' . $log);

$f = fake('plain');
smtp(['host' => '127.0.0.1', 'port' => $f['port'], 'encryption' => '', 'timeout' => 10]);
$sent = message(TO1 . "\r\nBcc: " . TO2)->send();
$log = finish($f);
check('перевод строки в адресе — отказ до соединения', $sent === false && $log === '', $log);
Primitive::setConfig(['mail' => ['from' => FROM], 'site' => ['domain' => 'simple.energine.org']]);
check('перевод строки в адресе — отказ и без SMTP (mail())', message(TO1 . "\nBcc: " . TO2)->send() === false);

// только через 127.0.0.1: на публичный адрес postfix отвечает на DATA «451 Try again later» (его политика
// для внешних соединений); TLS и проверка сертификата проверены выше поддельным сервером
echo "-- postfix этой машины, письмо в локальный ящик\n";
foreach ([['127.0.0.1', '']] as [$host, $enc]) {
    $marker = 'claude-smtp-' . getmypid() . '-' . ($enc ?: 'plain');
    $offset = is_file(MAILBOX_FILE) ? filesize(MAILBOX_FILE) : 0;
    smtp(['host' => $host, 'port' => 25, 'encryption' => $enc, 'timeout' => 20]);
    $m = new Mail();
    $sent = $m->setFrom(FROM)->setSubject("$marker тема")->setText("текст $marker")->setHtmlText("<p>$marker</p>")->addTo(MAILBOX)->send();
    $got = false;
    for ($i = 0; $i < 60 && !$got; $i++) {
        clearstatcache();
        $got = is_file(MAILBOX_FILE) && str_contains((string)file_get_contents(MAILBOX_FILE, false, null, $offset), "текст $marker");
        if (!$got) usleep(500000);
    }
    check("postfix $host" . ($enc ? " ($enc)" : '') . ': письмо доставлено в локальный ящик', $sent === true && $got);
}

done('smtp');
