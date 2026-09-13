<?php

namespace Energine\mail\components;

use Energine\share\components\Grid;
use Energine\share\gears\FieldDescription;
use Energine\share\gears\QAL;
use Energine\mail\components\UsersLookup;
use Energine\share\gears\SystemException;


class MailSubscriptionEmailEditor extends Grid {

    public function __construct($name, ?array $params = NULL) {
        parent::__construct($name, $params);
        $this->setTableName('mail_email2subscriptions');

        if (is_numeric($this->getParam('subscriptionID'))) {
            $filter = sprintf(' (subscription_id = %s) ', $this->getParam('subscriptionID'));
        } else {
            // e-mails of a subscription that is not saved yet, see MailSubscriptionEditor::saveData()
            $filter = sprintf(' (subscription_id IS NULL and session_id=%s) ', $this->dbh->quote(session_id()));
        }

        $this->setFilter($filter);
    }

    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'subscriptionID' => false,
            ]
        );
    }

    public function add() {
        parent::add();
        $data = $this->getData();
        if ($subscription_id = $this->getParam('subscriptionID')) {
            $f = $data->getFieldByName('subscription_id');
            $f->setRowData(0, $subscription_id);
        }
        $data->getFieldByName('session_id')->setRowData(0, session_id());
    }

    protected function createDataDescription() {
        $result = parent::createDataDescription();

        if (in_array($this->getState(), ['add'])) {

            $fd = $result->getFieldDescriptionByName('subscription_id');
            $fd->setType(FieldDescription::FIELD_TYPE_HIDDEN);

            $fd = $result->getFieldDescriptionByName('session_id');
            $fd->setType(FieldDescription::FIELD_TYPE_HIDDEN);
        }

        return $result;
    }

    protected function saveData() {
        $subscribersTable = 'mail_email_subscribers';
        if (!isset($_POST[$subscribersTable]['me_name']) || !$_POST[$subscribersTable]['me_name']) {
            throw new SystemException('ERR_NO_DATA', SystemException::ERR_CRITICAL);
        }
        $email = trim($_POST[$subscribersTable]['me_name']);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new SystemException('ERR_BAD_EMAIL', SystemException::ERR_WARNING);
        }

        if (!($id = $this->dbh->getScalar($subscribersTable, 'me_id', ['me_name' => $email]))) {
            $id = $this->dbh->modify(QAL::INSERT, $subscribersTable, ['me_date' => date('Y-m-d H:i:s'), 'me_name' => $email]);
        }
        unset($_POST[$subscribersTable]);

        // the address may already be subscribed to other newsletters: look for a link to this one only
        $link = ['me_id' => $id];
        if (is_numeric($this->getParam('subscriptionID'))) {
            $link['subscription_id'] = $this->getParam('subscriptionID');
        } else {
            $link['subscription_id'] = NULL;
            $link['session_id'] = session_id();
        }
        if (!($result = $this->dbh->getScalar($this->getTableName(), 'mes_id', $link))) {
            $_POST[$this->getTableName()]['me_id'] = $id;
            $result = parent::saveData();
        }

        return $result;
    }

}