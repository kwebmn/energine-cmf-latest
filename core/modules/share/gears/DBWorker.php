<?php
/**
 * @file
 * DBWorker.
 *
 * @code
abstract class DBWorker;
 * @endcode
 *
 * @author 1m.dm
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * @property-read QAL $dbh
 *
 * @method string translate(string $const, int|null $langId = null)
 * @method string dateToString(int|string $year, int|string $month, int|string $day)
 *
 *
 * Class DBWorker
 * @package Energine\share\gears
 */
trait DBWorker {
    /**
     * @param $name
     * @param $args
     * @return mixed
     *
     * @throws \BadMethodCallException
     */
    public function __call($name, $args) {
        if (in_array($name, ['translate', 'dateToString'])) {
            return call_user_func_array($name, $args);
        }
        // несуществующий метод — ошибка, а не тихий false: опечатка в имени метода видна сразу
        throw new \BadMethodCallException(static::class . '::' . $name . '() не существует');
    }

    /**
     * @param string $name
     * @return QAL|null
     */
    public function __get($name) {
        if ($name == 'dbh') return E()->getDB();
        return null;
    }
}
