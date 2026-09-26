<?php
/**
 * @file
 * SmtpTransport.
 *
 * It contains the definition to:
 * @code
final class SmtpTransport;
 * @endcode
 *
 * @copyright Energine 2026
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;

/**
 * Отправка письма через SMTP-сервер — свой клиент, без сторонних библиотек.
 *
 * Шифрование: ssl — TLS сразу при соединении (обычно порт 465), tls — STARTTLS (порт 587 или 25),
 * пусто — без шифрования. Вход — AUTH PLAIN или LOGIN, смотря что предлагает сервер. Сертификат
 * сервера проверяется по имени хоста; свой центр сертификации задаётся в cafile. Если при tls сервер
 * не предлагает STARTTLS, письмо не уходит: открытым текстом оно не отправляется.
 *
 * Любой неожиданный ответ сервера — \RuntimeException с командой, кодом и текстом ответа. Данные
 * входа (логин и пароль) в текст исключения не попадают.
 *
 * @code
final class SmtpTransport;
 * @endcode
 */
final class SmtpTransport {
    /**
     * host, port, encryption (ssl|tls|''), username, password, timeout, cafile, helo.
     * @var array
     */
    private $config;

    /**
     * @var resource|null
     */
    private $socket;

    /**
     * Возможности сервера из ответа на EHLO (STARTTLS, AUTH …), в верхнем регистре.
     * @var string[]
     */
    private $capabilities = [];

    /**
     * @param array $config настройки mail.smtp
     */
    public function __construct(array $config) {
        $this->config = $config + ['host' => '', 'port' => 25, 'encryption' => '', 'username' => '', 'password' => '',
                'timeout' => 15, 'cafile' => '', 'helo' => ''];
    }

    /**
     * Отправить готовое письмо (заголовки и тело).
     *
     * @param string $from адрес отправителя для конверта
     * @param string[] $to адреса получателей
     * @param string $message письмо целиком
     * @throws \RuntimeException
     */
    public function send($from, array $to, $message) {
        try {
            $this->connect();
            $this->expect('connect', [220]);
            $this->ehlo();
            if ($this->config['encryption'] === 'tls') {
                if (!in_array('STARTTLS', $this->capabilities, true)) {
                    throw new \RuntimeException('SMTP: the server does not offer STARTTLS, the mail is not sent in clear text');
                }
                $this->command('STARTTLS', [220]);
                if (!@stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new \RuntimeException('SMTP: TLS negotiation failed (certificate of ' . $this->config['host'] . '?)');
                }
                $this->ehlo();
            }
            if ((string)$this->config['username'] !== '') {
                $this->login();
            }
            $this->command('MAIL FROM:<' . $from . '>', [250]);
            foreach ($to as $address) {
                $this->command('RCPT TO:<' . $address . '>', [250, 251]);
            }
            $this->command('DATA', [354]);
            // строки CRLF, строка, начинающаяся с точки, получает вторую (иначе одна точка — конец письма)
            $message = preg_replace('/^\./m', '..', preg_replace("/\r\n|\r|\n/", "\r\n", rtrim($message, "\r\n")));
            $this->write($message . "\r\n.");
            $this->expect('DATA', [250]);
            try {
                $this->command('QUIT', [221]);
            } catch (\RuntimeException $e) {
                // письмо уже принято: ответ на QUIT ничего не меняет
            }
        } finally {
            if ($this->socket) {
                fclose($this->socket);
                $this->socket = null;
            }
        }
    }

    /**
     * Соединение: ssl:// сразу с TLS, иначе tcp://. Сертификат проверяется в обоих случаях (для tls — при STARTTLS).
     */
    private function connect() {
        $ssl = ['verify_peer' => true, 'verify_peer_name' => true, 'peer_name' => $this->config['host'],
            'allow_self_signed' => false];
        if ($this->config['cafile']) {
            $ssl['cafile'] = $this->config['cafile'];
        }
        $address = (($this->config['encryption'] === 'ssl') ? 'ssl://' : 'tcp://') . $this->config['host'] . ':' . (int)$this->config['port'];
        $this->socket = @stream_socket_client($address, $errno, $error, (float)$this->config['timeout'],
            STREAM_CLIENT_CONNECT, stream_context_create(['ssl' => $ssl]));
        if (!$this->socket) {
            throw new \RuntimeException('SMTP: cannot connect to ' . $this->config['host'] . ':' . (int)$this->config['port']
                . ($error ? ' — ' . $error : ''));
        }
        stream_set_timeout($this->socket, (int)$this->config['timeout']);
    }

    /**
     * EHLO и возможности сервера.
     */
    private function ehlo() {
        $helo = $this->config['helo'] ?: (gethostname() ?: 'localhost');
        $lines = $this->command('EHLO ' . $helo, [250]);
        $this->capabilities = array_map(function ($line) {
            return strtoupper(trim($line));
        }, array_slice($lines, 1));
    }

    /**
     * Вход: PLAIN, если сервер его предлагает, иначе LOGIN.
     */
    private function login() {
        $methods = [];
        foreach ($this->capabilities as $capability) {
            if (preg_match('/^AUTH[ =](.+)$/', $capability, $m)) {
                $methods = array_merge($methods, preg_split('/\s+/', trim($m[1])));
            }
        }
        $user = (string)$this->config['username'];
        $password = (string)$this->config['password'];
        if (in_array('PLAIN', $methods, true)) {
            $this->command('AUTH PLAIN ' . base64_encode("\0" . $user . "\0" . $password), [235], 'AUTH PLAIN');
        } elseif (in_array('LOGIN', $methods, true)) {
            $this->command('AUTH LOGIN', [334]);
            $this->command(base64_encode($user), [334], 'AUTH LOGIN (user)');
            $this->command(base64_encode($password), [235], 'AUTH LOGIN (password)');
        } else {
            throw new \RuntimeException('SMTP: the server offers neither AUTH PLAIN nor AUTH LOGIN');
        }
    }

    /**
     * Команда и ожидаемые коды ответа.
     *
     * @param string $line
     * @param int[] $codes
     * @param string|null $label как команда называется в тексте ошибки (данные входа не показываются)
     * @return string[] строки ответа без кода
     */
    private function command($line, array $codes, $label = null) {
        if (preg_match('/[\r\n]/', $line)) {
            throw new \RuntimeException('SMTP: line break in a command');
        }
        $this->write($line);

        return $this->expect($label ?? $line, $codes);
    }

    /**
     * @param string $data
     */
    private function write($data) {
        if (@fwrite($this->socket, $data . "\r\n") === false) {
            throw new \RuntimeException('SMTP: connection lost');
        }
    }

    /**
     * Ответ сервера (многострочный — до строки «код пробел»); код не из ожидаемых — исключение.
     *
     * @param string $what
     * @param int[] $codes
     * @return string[]
     */
    private function expect($what, array $codes) {
        $lines = [];
        do {
            $line = fgets($this->socket, 1024);
            if ($line === false) {
                $timedOut = stream_get_meta_data($this->socket)['timed_out'] ?? false;
                throw new \RuntimeException('SMTP: ' . $what . ' — ' . ($timedOut ? 'no answer (timeout)' : 'connection closed'));
            }
            $code = (int)substr($line, 0, 3);
            $lines[] = rtrim(substr($line, 4), "\r\n");
        } while (isset($line[3]) && $line[3] === '-');
        if (!in_array($code, $codes, true)) {
            throw new \RuntimeException('SMTP: ' . $what . ' — ' . $code . ' ' . implode(' ', $lines));
        }

        return $lines;
    }
}
