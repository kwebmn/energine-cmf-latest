<?php
ob_start();

define('CHARSET', 'UTF-8');

require_once('bootstrap.php');

// установщик запускается только из CLI (bootstrap.php подключает его при PHP_SAPI === 'cli'):
// php index.php setup ДЕЙСТВИЕ [АРГУМЕНТЫ…]; без действия — install
$args = array_slice($argv, 2);
$action = $args ? array_shift($args) : 'install';
// аргументы действия нумеруются с 1, как их ждёт Setup::execute()
$additionalArgs = $args ? array_combine(range(1, count($args)), $args) : array();


// код выхода: 0 — сделано, 1 — ошибка (сценарии установки проверяют его)
$failed = false;
try {
    require_once('Setup.php');
    $setup = new Setup();
    $setup->execute($action, $additionalArgs);


    //Ну вроде как все проверили
    //на этот момент у нас есть вся необходимая информация
    //как для инсталляции так и для линкера

    //Запускаем одноименную функцию
    //Тут позволили себе использваоть переменное имя функции поскольку все равно это точно одно из приемлимых значений
    //впрочем наверное возможны варианты

}
catch (\Exception $e) {
    $failed = true;
    // что успело выполниться, остаётся в выводе: по нему видно, на каком шаге остановились
    echo PHP_EOL, 'Ошибка: ', $e->getMessage();
}

$data = ob_get_contents();
if(ob_get_length())ob_end_clean();

echo PHP_EOL, $data, PHP_EOL, PHP_EOL;
exit($failed ? 1 : 0);
