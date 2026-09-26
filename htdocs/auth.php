<?php
use Energine\share\gears\UserSession;

//на всякий пожарный проверяем реферрера
if (!isset($_SERVER['HTTP_REFERER']) /*&& (!isset($_GET['return']))*/) {
    //не местных  - в сад
    exit;
}
//подключаем bootstrap
require_once('bootstrap.php');

$response = E()->getResponse();
$response->disableCache();

if (isset($_POST['user']['login']) &&
    isset($_POST['user']['username']) &&
    isset($_POST['user']['password'])
) {
    if ($UID = Energine\share\gears\AuthUser::authenticate(
        $_POST['user']['username'],
        $_POST['user']['password']
    )
    ) {
        E()->UserSession->start($UID);
    } else {
        $response->addCookie(UserSession::FAILED_LOGIN_COOKIE_NAME, E()->Utils->translate('ERR_BAD_AUTH'), time() + 60);
    }
    //о том прошла ли аутентификация успешноыны LoginForm узнает из куков
} elseif (isset($_POST['user']['logout']) || isset($_GET['logout'])) {
    $_GET['return'] = '/';

    E()->UserSession->kill();
}
$response->goBack();
