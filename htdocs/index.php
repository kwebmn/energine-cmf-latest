<?php
/**
 * Три... Два... Один... Запуск!
 *
 * @package energine
 * @author pavka
 * @copyright Energine 2011
 */

try {
    require_once('bootstrap.php');

    E()->UserSession->init();

    E()->getController()->run();

    E()->getResponse()->commit();
} catch (\LogicException $bootstrapException) {
    //Все исключения перехваченные здесь произошли в bootstrap'e
    //И ориентироваться на наличие DEBUG здесь нельзя
    //Поэтому выводим как есть
    header('Content-Type: text/plain; charset=utf-8');
    echo $bootstrapException->getMessage();
} catch (\Throwable $generalException) {
    // сюда попадают и ошибки PHP (TypeError и подобные): без отладки посетитель не видит ничего, кроме кода ответа
    if (defined('DEBUG') && DEBUG) {
        header('Content-Type: text/plain; charset=utf-8');
        try {
            var_dump($generalException);
        } catch (\Throwable $e) {
            echo (string)$e->getMessage();
        }
    }
    else {
        error_log('Energine: ' . get_class($generalException) . ': ' . $generalException->getMessage() . ' @ '
            . $generalException->getFile() . ':' . $generalException->getLine());
        http_response_code(500);
    }
    exit;
}
