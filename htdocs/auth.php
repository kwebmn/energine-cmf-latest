<?php
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
    if ($UID = Energine\share\gears\AuthUser::authenticate(
        $_POST['user']['username'],
        $_POST['user']['password']
    )
    ) {
        E()->UserSession->start($UID);
    } else {
        $response->addCookie(UserSession::FAILED_LOGIN_COOKIE_NAME, 'ERR_BAD_AUTH', time() + 60, false, '/', true);
    }
    // о неудаче LoginForm узнаёт из cookie: там имя константы, текст переводится на языке страницы
} elseif (isset($_POST['user']['logout'])) {
    $_GET['return'] = '/';

    E()->UserSession->kill();
}
$response->goBack();
