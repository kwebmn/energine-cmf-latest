<?php
/**
 * @file
 * RestorePassword
 *
 * It contains the definition to:
 * @code
class RestorePassword;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\user\components;

use Energine\share\components\DataSet,
    Energine\share\gears\User,
    Energine\share\gears\QAL,
    Energine\share\gears\Field,
    Energine\share\gears\FieldDescription,
    Energine\share\gears\Request,
    Energine\share\gears\MailTemplate,
    Energine\share\gears\Mail;

/**
 * Восстановление пароля по одноразовой ссылке.
 *
 * Запрос по e-mail (send) пароль не меняет: на адрес уходит ссылка со случайным токеном, в базе хранятся
 * только его хэш и срок. Ответ на запрос один для любого адреса — по нему не узнать, зарегистрирован ли
 * адрес. Переход по ссылке (reset) открывает форму нового пароля, её отправка (change) меняет пароль,
 * стирает токен и закрывает сессии пользователя.
 *
 * @code
class RestorePassword;
 * @endcode
 */
class RestorePassword extends DataSet {
    /**
     * Срок ссылки, секунд.
     */
    const LINK_TTL = 3600;

    /**
     * Не чаще одного письма на адрес за этот промежуток, секунд: форма не должна быть рассыльщиком.
     */
    const RESEND_PAUSE = 300;

    /**
     * @copydoc DataSet::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setAction('send');
    }

    /**
     * @copydoc DataSet::defineParams
     */
    // Переопределен параметр active
    protected function defineParams() {
        $result = array_merge(parent::defineParams(),
            array(
                'active' => true,
            ));
        return $result;
    }

    /**
     * Запрос ссылки для смены пароля.
     */
    protected function send() {
        $this->beforeStep();
        $uName = trim((string)($_POST['u_name'] ?? ''));
        $message = $this->translate('MSG_RESTORE_LINK_SENT');
        $user = ($uName === '') ? false
            : $this->dbh->getRow('SELECT u_id, u_restore_until FROM user_users WHERE u_name = %s AND u_is_active = 1', $uName);
        if ($user && (empty($user['u_restore_until'])
                || strtotime($user['u_restore_until']) <= time() + self::LINK_TTL - self::RESEND_PAUSE)) {
            $token = bin2hex(random_bytes(32));
            $this->dbh->modify(QAL::UPDATE, 'user_users', [
                'u_restore_hash' => hash('sha256', $token),
                'u_restore_until' => date('Y-m-d H:i:s', time() + self::LINK_TTL),
            ], ['u_id' => $user['u_id']]);
            try {
                $this->mailLink($user['u_id'], $uName, $token);
            } catch (\Exception $e) {
                $message = $e->getMessage();
            }
        }
        $this->showResult($message);
    }

    /**
     * Переход по ссылке: форма нового пароля.
     */
    protected function reset() {
        $this->beforeStep();
        $token = $this->token();
        if (!$this->userByToken($token)) {
            $this->showResult($this->translate('ERR_RESTORE_LINK'));
            return;
        }
        $this->passwordForm($token);
    }

    /**
     * Новый пароль из формы: не пустой и совпадает с подтверждением, как при смене пароля в профиле.
     */
    protected function change() {
        $this->beforeStep();
        $token = $this->token();
        if (!($UID = $this->userByToken($token))) {
            $this->showResult($this->translate('ERR_RESTORE_LINK'));
            return;
        }
        $password = (string)($_POST['u_password'] ?? '');
        if ($password === '' || $password !== (string)($_POST['u_password2'] ?? '')) {
            $this->passwordForm($token, $this->translate('ERR_PWD_MISMATCH'));
            return;
        }
        // QAL пишет null пустой строкой, а datetime её не принимает — поэтому запрос целиком
        $this->dbh->modify('UPDATE user_users SET u_password = %s, u_restore_hash = NULL, u_restore_until = NULL WHERE u_id = %s',
            password_hash($password, PASSWORD_DEFAULT), $UID);
        // сессии, открытые со старым паролем, закрываются
        $this->dbh->modify(QAL::DELETE, 'share_session', null, ['u_id' => $UID]);
        $this->showResult($this->translate('MSG_PASSWORD_CHANGED'));
    }

    /**
     * Общее для шагов: крошка и без текстового блока-пояснения страницы.
     */
    private function beforeStep() {
        if ($crumbComponent = $this->document->componentManager->getBlockByName('breadCrumbs')) {
            $crumbComponent->addCrumb();
        }
        if ($component = $this->document->componentManager->getBlockByName('textBlockRestorePassword')) {
            $component->disable();
        }
    }

    /**
     * Токен из адреса.
     *
     * @return string
     */
    private function token() {
        $params = $this->getStateParams(true);

        return (string)($params['token'] ?? '');
    }

    /**
     * Пользователь, которому выдана эта ссылка, если она ещё действует.
     *
     * @param string $token
     * @return int|false
     */
    private function userByToken($token) {
        if (!preg_match('/^[0-9a-f]{64}$/', $token)) {
            return false;
        }

        return $this->dbh->getScalar(
            'SELECT u_id FROM user_users WHERE u_restore_hash = %s AND u_restore_until > %s AND u_is_active = 1',
            hash('sha256', $token), date('Y-m-d H:i:s')
        ) ?: false;
    }

    /**
     * Форма нового пароля; при ошибке — сообщение над полями.
     *
     * @param string $token
     * @param string|null $error
     */
    private function passwordForm($token, $error = null) {
        $this->getConfig()->setCurrentState('reset');
        $this->setAction('change/' . $token . '/');
        $this->setTitle($this->translate('TXT_NEW_PASSWORD'));
        $this->prepare();
        if ($error) {
            $fd = new FieldDescription('restore_password_result');
            $fd->setType(FieldDescription::FIELD_TYPE_STRING);
            $fd->setMode(FieldDescription::FIELD_MODE_READ);
            $this->getDataDescription()->addFieldDescription($fd);
            $field = new Field('restore_password_result');
            $field->setData($error);
            $this->getData()->addField($field);
        }
    }

    /**
     * Итог шага — одно сообщение.
     *
     * @param string $message
     */
    private function showResult($message) {
        $this->getConfig()->setCurrentState('send');
        $this->prepare();
        $messageField = new Field('restore_password_result');
        $messageField->setData($message);
        $this->getData()->addField($messageField);
    }

    /**
     * Письмо со ссылкой на форму нового пароля (на языке страницы, с которой пришёл запрос).
     *
     * @param int $UID
     * @param string $login
     * @param string $token
     */
    private function mailLink($UID, $login, $token) {
        $user = new User($UID);
        $sex = $user->getValue('u_sex');
        $sex = $this->translate(($sex == 'M') ? 'TXT_EMAIL_SUFFIX_SEX_M'
            : (($sex == 'F') ? 'TXT_EMAIL_SUFFIX_SEX_F' : 'TXT_EMAIL_SUFFIX_SEX_UNKNOWN'));
        $site = E()->getSiteManager()->getCurrentSite();
        $request = E()->getRequest();
        $template = new MailTemplate('user_restore_password', [
            'user_login' => $login,
            'user_name' => $user->getValue('u_fullname'),
            'restore_link' => $site->base . $request->getLangSegment() . $request->getPath(Request::PATH_TEMPLATE, true)
                . 'reset/' . $token . '/',
            'site_url' => $site->base,
            'site_name' => $site->name,
            'sex_suffix_hello' => $sex
        ]);

        $mailer = new Mail();
        $mailer
            ->setFrom($this->getConfigValue('mail.from'))
            ->setSubject($template->getSubject())
            ->setText($template->getBody())
            ->setHtmlText($template->getHTMLBody())
            ->addTo($login)
            ->send();
    }
}
