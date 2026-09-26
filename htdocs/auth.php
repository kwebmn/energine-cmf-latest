<?php
use Energine\share\gears\AuthUser;
use Energine\share\gears\Csrf;
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
// сессия вошедшего пользователя поднимается до проверки: токен выхода привязан к ней
E()->UserSession->init();

if (!Csrf::verify()) {
    // форма без токена посетителя или с чужого сайта: ни входа, ни выхода
    $response->addCookie(UserSession::FAILED_LOGIN_COOKIE_NAME, 'ERR_CSRF', time() + 60, false, '/', true);
} elseif (isset($_POST['user']['login']) &&
    isset($_POST['user']['username']) &&
    isset($_POST['user']['password'])
) {
    // лимит попыток: IP — адрес соединения (X-Forwarded-For подделывается)
    $login = (string)$_POST['user']['username'];
    $ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
    if (AuthUser::isThrottled($login, $ip)) {
        $response->addCookie(UserSession::FAILED_LOGIN_COOKIE_NAME, 'ERR_TOO_MANY_ATTEMPTS', time() + 60, false, '/', true);
    } elseif ($UID = AuthUser::authenticate($login, (string)$_POST['user']['password'])) {
        AuthUser::clearFailures($login, $ip);
        E()->UserSession->start($UID);
    } else {
        AuthUser::registerFailure($login, $ip);
        $response->addCookie(UserSession::FAILED_LOGIN_COOKIE_NAME, 'ERR_BAD_AUTH', time() + 60, false, '/', true);
    }
    // о неудаче LoginForm узнаёт из cookie: там имя константы, текст переводится на языке страницы
} elseif (isset($_POST['user']['logout'])) {
    $_GET['return'] = '/';

    E()->UserSession->kill();
}
$response->goBack();
