<?php
/**
 * @file
 * UserProfile
 *
 * It contains the definition to:
 * @code
class UserProfile;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\user\components;

use Energine\share\components\DBDataSet, Energine\share\gears\SystemException, Energine\share\gears\DataDescription, Energine\share\gears\Data, Energine\share\gears\FieldDescription, Energine\share\gears\Field;

/**
 * form to edit user profile.
 *
 * @code
class UserProfile;
 * @endcode
 */
class UserProfile extends DBDataSet {
    /**
     * @copydoc DBDataSet::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('user_users');
        $this->setType(self::COMPONENT_TYPE_FORM_ALTER);
    }


    /**
     * @copydoc DBDataSet::main
     *
     * @throws SystemException 'ERR_DEV_NO_AUTH_USER'
     */
    protected function main() {
        if (!$this->document->user->isAuthenticated()) {
            throw new SystemException('ERR_DEV_NO_AUTH_USER', SystemException::ERR_DEVELOPER);
        }
        $this->setFilter($this->document->user->getID());

        $this->setAction('save-user');
        $this->setTitle($this->translate('TXT_USER_PROFILE'));
        $this->prepare();

    }

    protected function edit() {
        if (!$this->document->user->isAuthenticated()) {
            throw new SystemException('ERR_DEV_NO_AUTH_USER', SystemException::ERR_DEVELOPER);
        }
        $this->setFilter($this->document->user->getID());

        $this->setAction('save-user');
        $this->setTitle($this->translate('TXT_USER_PROFILE_EDIT'));
        $this->prepare();
    }

    protected function changepassword() {
        if (!$this->document->user->isAuthenticated()) {
            throw new SystemException('ERR_DEV_NO_AUTH_USER', SystemException::ERR_DEVELOPER);
        }
        $this->setFilter($this->document->user->getID());

        $this->setAction('save-password');
        $this->setTitle($this->translate('TXT_CHANGE_PASSWORD'));
        $this->prepare();
    }

    /**
     * @copydoc DBDataSet::defineParams
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
     * Save.
     * Сохраняются только поля формы (без ключа и служебных колонок). Пароль меняется, только если задан
     * новый: он должен совпасть с повтором, а текущий пароль — быть верным. Раньше проверка сравнивала
     * хэш из базы с новым паролем, всегда отказывала, и профиль не сохранялся вовсе.
     */
    protected function save() {
        $user = $this->document->user;
        if (!$user->isAuthenticated()) {
            throw new SystemException('ERR_DEV_NO_AUTH_USER', SystemException::ERR_DEVELOPER);
        }
        $this->setFilter($user->getID());
        $this->prepare();
        $posted = (array)($_POST[$this->getTableName()] ?? []);

        $data = [];
        foreach ($this->getDataDescription() as $name => $fd) {
            if ($fd->getPropertyValue('customField') || $fd->getPropertyValue('key') === true
                || !array_key_exists($name, $posted) || !is_scalar($posted[$name])) {
                continue;
            }
            $data[$name] = (string)$posted[$name];
        }

        $newPassword = $data['u_password'] ?? '';
        unset($data['u_password']);
        if ($newPassword !== '') {
            if ($newPassword !== (string)($_POST['u_password2'] ?? '')) {
                $this->fail('ERR_PWD_MISMATCH');
            }
            if (!password_verify((string)($_POST['u_password_current'] ?? ''), (string)$user->getValue('u_password'))) {
                $this->fail('TXT_USER_PROFILE_WRONG_PWD');
            }
            // хэширует User::update
            $data['u_password'] = $newPassword;
        }
        // логин (e-mail) другого пользователя не занимается
        if (isset($data['u_name']) && $data['u_name'] !== (string)$user->getValue('u_name')
            && $this->dbh->getScalar('user_users', 'COUNT(*)', ['u_name' => $data['u_name']])) {
            $this->fail('ERR_USER_EXISTS');
        }

        try {
            $user->update($data);
            $_SESSION['saved'] = true;
            $this->response->redirectToCurrentSection('success/');
        } catch (SystemException $e) {
            // например, обязательное поле пустое: причина — в журнал, посетителю — общий текст
            error_log('UserProfile: ' . $e->getMessage());
            $this->fail('ERR_DATABASE_ERROR');
        }
    }

    protected function savepassword()
    {
        $this->save();
    }

    /**
     * Show message about successful saving data.
     *
     * @throws SystemException 'ERR_404'
     */
    protected function success() {
        //если в сессии нет переменной saved, значит этот метод пытаются дернуть напрямую. Не выйдет!
        if (!isset($_SESSION['saved'])) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        //Мавр сделал свое дело...
        unset($_SESSION['saved']);

        $this->setBuilder($this->createBuilder());

        $dd = new DataDescription();
        $this->setDataDescription($dd);

        $ddi = new FieldDescription('success_message');
        $ddi->setType(FieldDescription::FIELD_TYPE_TEXT);
        $ddi->setMode(FieldDescription::FIELD_MODE_READ);
        $ddi->removeProperty('title');
        $dd->addFieldDescription($ddi);

        $d = new Data();
        $this->setData($d);

        $di = new Field('success_message');
        $this->setTitle($this->translate('TXT_USER_PROFILE'));
        $di->setData($this->translate('TXT_USER_PROFILE_SAVED'));
        $d->addField($di);

        // wtf ?
        //$this->document->componentManager->getBlockByName('breadCrumbs')->addCrumb();
    }


    /**
     * Remember why saving failed and show it on the error state.
     *
     * @param string $messageConst Translation constant of the message.
     */
    private function fail($messageConst) {
        $_SESSION['error'] = $messageConst;
        $this->response->redirectToCurrentSection('error/');
    }

    /**
     * Show message about incorrect password.
     *
     * @throws SystemException 'ERR_404'
     */
    protected function error() {
        //если в сессии нет переменной error, значит этот метод пытаются дернуть напрямую. Не выйдет!
        if (!isset($_SESSION['error'])) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        // причина: константа перевода, положенная fail(); раньше сюда попадал только неверный пароль
        $messageConst = is_string($_SESSION['error']) ? $_SESSION['error'] : 'TXT_USER_PROFILE_WRONG_PWD';
        //Мавр сделал свое дело...
        unset($_SESSION['error']);

        $this->setBuilder($this->createBuilder());

        $dd = new DataDescription();
        $this->setDataDescription($dd);

        $ddi = new FieldDescription('error_message');
        $ddi->setType(FieldDescription::FIELD_TYPE_TEXT);
        $ddi->setMode(FieldDescription::FIELD_MODE_READ);
        $ddi->removeProperty('title');
        $dd->addFieldDescription($ddi);

        $d = new Data();
        $this->setData($d);

        $this->setTitle($this->translate('TXT_USER_PROFILE'));
        $this->addTranslation('TXT_USER_PROFILE');

        $di = new Field('error_message');
        $di->setData($this->translate($messageConst));
        $d->addField($di);

        $this->document->componentManager->getBlockByName('breadCrumbs')->addCrumb();
    }

    /**
     * @copydoc DBDataSet::createDataDescription
     */
    // Для метода success переопределен метод создания объекта метаданных
    protected function createDataDescription() {
        $result = parent::createdataDescription();
        // служебные колонки посетитель не видит и не меняет: активность, ссылка восстановления пароля
        foreach (['u_is_active', 'u_restore_hash', 'u_restore_until'] as $name) {
            if ($field = $result->getFieldDescriptionByName($name)) {
                $result->removeFieldDescription($field);
            }
        }

        // пароли не обязательны: пустой новый пароль — пароль не меняется
        $optional = function (FieldDescription $field) {
            $field->setProperty('nullable', true);
            $field->removeProperty('pattern');
            $field->removeProperty('message');

            return $field;
        };
        if ($field = $result->getFieldDescriptionByName('u_password')) {
            $field->setProperty('message2', $this->translate('ERR_PWD_MISMATCH'));
            $field->setProperty('title', 'FIELD_U_PASSWORD_NEW');
            $result->removeFieldDescription($field);
            if ($this->getState() !== 'save') {
                $current = new FieldDescription('u_password_current');
                $current->setType(FieldDescription::FIELD_TYPE_PWD);
                $current->setProperty('customField', true);
                $current->setProperty('title', 'FIELD_U_PASSWORD_CURRENT');
                $result->addFieldDescription($optional($current));
            }
            $result->addFieldDescription($optional($field));
        }

        if ($this->getState() !== 'save') {

            if ($result->getFieldDescriptionByName('u_password')) {
                $field = new FieldDescription('u_password2');
                $field->setProperty('message2', $this->translate('ERR_PWD_MISMATCH'));
                $field->setType(FieldDescription::FIELD_TYPE_PWD);
                $field->setProperty('customField', true);
                //$field->setProperty('title', $this->translate('FIELD_U_PASSWORD2'));
                $field->setProperty('title', 'FIELD_U_PASSWORD2');
                $result->addFieldDescription($optional($field));
            }
        }


        return $result;
    }

    /**
     * @copydoc DBDataSet::createData
     */
    // Для метода success создаем свой объект данных
    protected function createData() {
        $result = parent::createData();
        if ($field = $result->getFieldByName('u_password')) {
            $field->setData('');
        }
        return $result;
    }
}

