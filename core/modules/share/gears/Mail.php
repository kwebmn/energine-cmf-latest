<?php

namespace Energine\share\gears;

final class Mail extends Primitive {

    /**
     * End Of Line.
     * @var string EOL
     */
    const EOL = "\n";

    /**
     * Mime boundary.
     * @var string $MIMEBoundary
     */
    private $MIMEBoundary;

    /**
     * Message subject.
     * @var string $subject
     */
    private $subject = false;

    /**
     * Sender address.
     * Format: User name <email\@address.ua>
     * @var string $sender
     */
    private $sender;

    /**
     * Адрес отправителя без имени — для конверта SMTP и проверки.
     * @var string
     */
    private $senderAddress;

    /**
     * Set of recipients.
     * @var array $to
     */
    private $to = array();

    /**
     * Message text.
     * @var string $text
     */
    private $text = false;

    /**
     * Message HTML text.
     * @var bool
     */
    private $html_text = false;

    /**
     * Message header.
     * @var array $headers
     */
    private $headers = array();

    /**
     * Reply-to.
     * @var string $replyTo
     */
    private $replyTo = array();

    /**
     * Set of attachments.
     * @var array $attachments
     */
    private $attachments = array();

    public function __construct() {
        $this->sender = $this->senderAddress = (string)$this->getConfigValue('mail.from');
    }

    /**
     * Set "from" attribute.
     *
     * @param string $email Email address.
     * @param string|bool $name Name.
     * @return Mail
     */

    public function setFrom($email, $name = false) {
        $this->senderAddress = (string)$email;
        $this->sender = ($name)?'=?UTF-8?B?'.base64_encode($name).'?= <'.$email.'>':$email;
        return $this;
    }

    /**
     * Set message subject.
     *
     * @param string $subject Subject text.
     * @return Mail
     */
    public function setSubject($subject) {
        $this->subject = '=?UTF-8?B?'.base64_encode(strip_tags($subject)).'?=';
        return $this;
    }

    /**
     * Add recipient.
     *
     * @param string $email Email address.
     * @param string|bool $name Name.
     * @return Mail
     */
    public function addTo($email, $name = false) {
        $email = trim($email);
        $this->to[$email] = ($name)?'=?UTF-8?B?'.base64_encode($name).'?= <'.$email.'>':$email;
        return $this;
    }

    /**
     * Clear recipient list.
     *
     * @return Mail
     */
    public function clearRecipientList(){
        $this->to = array();

        return $this;
    }

    /**
     * Add recipient to Reply-to
     *
     * @param string $email Email address.
     * @param string|bool $name Name.
     * @return Mail
     */
    public function addReplyTo($email, $name = false) {
        $this->replyTo[$email] = ($name)?'=?UTF-8?B?'.base64_encode($name).'?= <'.$email.'>':$email;
        return $this;
    }

    /**
     * Set message text.
     *
     * @param string $text Text.
     * @return Mail
     */
    public function setText($text) {
        $this->text = $text;
        return $this;
    }

    /**
     * Get message text.
     *
     * @return string
     */
    public function getText() {
        return $this->text;
    }

    /**
     * Set message html text.
     *
     * @param string $html_text Text.
     * @return Mail
     */
    public function setHtmlText($html_text) {
        $this->html_text = $html_text;
        return $this;
    }

    /**
     * Get message html text.
     *
     * @return string
     */
    public function getHtmlText() {
        return $this->html_text;
    }

    /**
     * Add attachment.
     *
     * @param mixed $file File.
     * @param string|bool $fileName Filename.
     * @return Mail
     */
    public function addAttachment($file, $fileName = false) {
        if (file_exists($file)) {
            $fileContent = base64_encode((file_get_contents($file)));
            $fileName = (!$fileName)?basename($file):$fileName;
            $this->attachments[$fileName] = $fileContent;
        }

        return $this;
    }


    /**
     * Send message.
     *
     * @return boolean
     */
    public function send() {
        $MIMEBoundary1 = md5(time()).rand(1000,9999);
        $MIMEBoundary2 = md5(time()).rand(1000,9999);

        $this->headers = array('X-Mailer: PHP v'.phpversion());
        $this->headers[] = 'MIME-Version: 1.0';

        # Common Headers
        $this->headers[] = 'From: '.$this->sender;
        $this->headers[] = (!empty($this->replyTo))?'Reply-To: '.implode(',', $this->replyTo):'Reply-To: '.$this->sender;
        $this->headers[] = 'Return-Path: '.$this->sender;
        $this->headers[] = "Content-Type: multipart/mixed;
        boundary=\"".$MIMEBoundary1."\"".self::EOL;

        $message = "This is a multi-part message in MIME format.".self::EOL.self::EOL;
        $message .= "--".$MIMEBoundary1.self::EOL;

        $message .= "Content-Type: multipart/alternative;
        boundary=\"".$MIMEBoundary2."\"".self::EOL.self::EOL;

        # Text Version
        $message .= "--".$MIMEBoundary2.self::EOL;
        $message .= "Content-Type: text/plain; charset=UTF-8".self::EOL;
        $message .= "Content-Transfer-Encoding: quoted-printable".self::EOL.self::EOL;
        $message .= self::quotedPrintable($this->text) .self::EOL.self::EOL;

        # HTML Version
        $message .= "--".$MIMEBoundary2.self::EOL;
        $message .= "Content-Type: text/html; charset=UTF-8".self::EOL;
        $message .= "Content-Transfer-Encoding: quoted-printable".self::EOL.self::EOL;
        if (strpos($this->html_text, '<html') === false) {
            $message .= self::quotedPrintable('<HTML><HEAD><meta http-equiv="Content-Type" content="text/html; charset=utf-8"></HEAD><BODY>' . $this->html_text . '</BODY></HTML>') . self::EOL . self::EOL;
        } else {
            $message .= self::quotedPrintable($this->html_text) . self::EOL . self::EOL;
        }

        # Finished
        $message .= "--".$MIMEBoundary2."--".self::EOL.self::EOL;  // finish with two eol's for better security. see Injection.
        if (!empty($this->attachments)) {
            foreach ($this->attachments as $attachName => $attach) {
                $message .= "--".$MIMEBoundary1.self::EOL;
                $message .= "Content-Type: application/octet-stream; name=\"".$attachName."\"".self::EOL;
                $message .= "Content-Transfer-Encoding: base64".self::EOL;
                $message .= "Content-Disposition: attachment;".self::EOL;
                $message .= "       filename=\"".$attachName."\"".self::EOL.self::EOL;
                $message .= chunk_split($attach).self::EOL;
            }
        }

        $message .= "--".$MIMEBoundary1."--";

        if (empty($this->to)) {
            return false;
        }
        try {
            // перевод строки в адресе дописал бы свой заголовок (или команду SMTP): такое письмо не уходит
            foreach (array_merge([$this->senderAddress], array_keys($this->to), array_keys($this->replyTo)) as $address) {
                if (preg_match('/[\r\n]/', $address)) {
                    throw new \InvalidArgumentException('line break in an address');
                }
            }
            $smtp = $this->getConfigValue('mail.smtp');
            if (is_array($smtp) && !empty($smtp['host'])) {
                // через SMTP письмо целиком: заголовки, которые mail() и почтовый сервер добавили бы сами
                // хост сайта без порта: в Message-ID двоеточие недопустимо
                $domain = Site::hostOf((string)$this->getConfigValue('site.domain')) ?: (gethostname() ?: 'localhost');
                $headers = array_map('rtrim', $this->headers);
                $headers[] = 'To: ' . implode(', ', $this->to);
                $headers[] = 'Subject: ' . $this->subject;
                $headers[] = 'Date: ' . date('r');
                $headers[] = 'Message-ID: <' . bin2hex(random_bytes(16)) . '@' . $domain . '>';
                // в конверте — только адреса: без имени («Сайт <адрес>») и по одному из списка через запятую
                $recipients = [];
                foreach (array_keys($this->to) as $to) {
                    $recipients = array_merge($recipients, self::envelopeAddresses($to));
                }
                (new SmtpTransport($smtp + ['helo' => $domain]))
                    ->send(self::envelopeAddresses($this->senderAddress)[0] ?? '', array_values(array_unique($recipients)),
                        implode("\r\n", $headers) . "\r\n\r\n" . $message);
                $result = true;
            } else {
                $result = mail(implode(',', $this->to), $this->subject, $message, implode(self::EOL, $this->headers));
            }
        } catch (\Exception $e) {
            // как у mail(): письмо не ушло — false; причина — в журнал ошибок PHP
            error_log('Mail: ' . $e->getMessage());
            $result = false;
        }

        return $result;
    }

    /**
     * Тело части в quoted-printable: только ASCII и строки не длиннее 76 символов — письмо проходит любой
     * сервер (RFC 5321: строка не длиннее 998 октетов), а переводы строк остаются переводами строк.
     *
     * @param string $text
     * @return string
     */
    private static function quotedPrintable($text) {
        // перевод строки — только CRLF: одиночный LF quoted_printable_encode записал бы как =0A
        $encoded = quoted_printable_encode(preg_replace("/\r\n|\r|\n/", "\r\n", (string)$text));

        return str_replace("\r\n", self::EOL, $encoded);
    }

    /**
     * Адреса для конверта SMTP: из «Имя <адрес>» — только адрес, список через запятую — по одному
     * (запятая внутри кавычек имени список не делит).
     *
     * @param string $value
     * @return string[]
     */
    private static function envelopeAddresses($value) {
        $result = [];
        foreach (preg_split('/,(?=(?:[^"]*"[^"]*")*[^"]*$)/', (string)$value) as $item) {
            $item = trim($item);
            if (preg_match('/<([^<>]*)>$/', $item, $m)) {
                $item = trim($m[1]);
            }
            if ($item !== '') {
                $result[] = $item;
            }
        }

        return $result;
    }
}