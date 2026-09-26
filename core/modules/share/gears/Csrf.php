<?php
/**
 * @file
 * Csrf.
 *
 * It contains the definition to:
 * @code
final class Csrf;
 * @endcode
 *
 * @copyright Energine 2026
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;

/**
 * Токен против подделки запросов с чужих сайтов (CSRF).
 *
 * Токен один на посетителя: хэш ключа, которого нет у чужого сайта. Для вошедшего пользователя
 * ключ — идентификатор сессии, для гостя — случайное значение cookie nrgn_csrf (ставится при первом
 * обращении). Каждый POST обязан принести токен в поле csrf_token или в заголовке X-CSRF-Token;
 * если браузер прислал Origin, его хост должен совпадать с хостом запроса.
 *
 * Токен выводят документ (свойство csrf: meta и Energine.csrf) и шаблоны форм (скрытое поле),
 * проверку делают DocumentController::run и auth.php. Действия, меняющие данные (Component::CHANGING_STATES),
 * принимаются только POST-ом: запрошенные иначе, они отклоняются тем же ответом (refuse).
 *
 * @code
final class Csrf;
 * @endcode
 */
final class Csrf {
    /** Поле формы. */
    const FIELD = 'csrf_token';
    /** Заголовок запросов из JS. */
    const HEADER = 'X-CSRF-Token';
    /** Cookie гостя. */
    const COOKIE = 'nrgn_csrf';

    /**
     * Токен текущего посетителя. Гостю без cookie она создаётся.
     *
     * @return string
     */
    public static function token() {
        return self::hash(self::key(true));
    }

    /**
     * Был ли отказ refuse() в этом запросе.
     * @var bool
     */
    private static $refused = false;

    /**
     * Запрос пришёл POST-ом (только у него verify проверяет токен).
     *
     * @return bool
     */
    public static function isPost() {
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST';
    }

    /**
     * Отказать: действие, меняющее данные, запрошено не POST-ом (ссылкой, картинкой, переходом с чужого сайта).
     * Ответ тот же, что при неверном токене: код 422 (его ставит DocumentController) и текст ERR_CSRF.
     *
     * @throws SystemException
     */
    public static function refuse() {
        self::$refused = true;
        throw new SystemException('ERR_CSRF', SystemException::ERR_403);
    }

    /**
     * @return bool был ли отказ refuse()
     */
    public static function refused() {
        return self::$refused;
    }

    /**
     * Проверка запроса: не POST — проходит; POST — нужен свой Origin (если он есть) и верный токен.
     *
     * @return bool
     */
    public static function verify() {
        if (!self::isPost()) {
            return true;
        }
        if (!self::sameOrigin()) {
            return false;
        }
        if (!($key = self::key(false))) {
            return false;
        }
        $expected = self::hash($key);
        foreach ([$_POST[self::FIELD] ?? null, $_SERVER['HTTP_X_CSRF_TOKEN'] ?? null] as $given) {
            if (is_string($given) && $given !== '' && hash_equals($expected, $given)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param string $key
     * @return string
     */
    private static function hash($key) {
        return hash('sha256', 'energine-csrf|' . $key);
    }

    /**
     * Ключ токена: сессия вошедшего пользователя или cookie гостя.
     *
     * @param bool $create создать cookie гостя, если её нет
     * @return string|null
     */
    private static function key($create) {
        if (session_status() === PHP_SESSION_ACTIVE && session_id() !== '') {
            return 'session|' . session_id();
        }
        $value = $_COOKIE[self::COOKIE] ?? '';
        if (!is_string($value) || !preg_match('/^[0-9a-f]{64}$/', $value)) {
            if (!$create) {
                return null;
            }
            $value = bin2hex(random_bytes(32));
            E()->getResponse()->addCookie(self::COOKIE, $value, 0, false, '/', true);
        }

        return 'guest|' . $value;
    }

    /**
     * Origin запроса (если браузер его прислал) указывает на тот же хост.
     *
     * @return bool
     */
    private static function sameOrigin() {
        if (!isset($_SERVER['HTTP_ORIGIN'])) {
            return true;
        }
        $origin = parse_url($_SERVER['HTTP_ORIGIN'], PHP_URL_HOST);
        $host = preg_replace('/:\d+$/', '', (string)($_SERVER['HTTP_HOST'] ?? ''));

        return is_string($origin) && $host !== '' && strcasecmp($origin, $host) === 0;
    }
}
