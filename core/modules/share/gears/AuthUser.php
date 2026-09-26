<?php
/**
 * @file
 * AuthUser.
 *
 * It contains the definition to:
 * @code
class AuthUser;
 * @endcode
 *
 * @author d.pavka
 * @copyright Energine 2011
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;

/**
 * Authenticated user.
 *
 * @code
class AuthUser;
 * @endcode
 */
class AuthUser extends User {
    /**
     * Лимит попыток входа: окно (секунд) и сколько неудач в нём допускается на один логин и с одного IP.
     * Следующая попытка отклоняется без проверки пароля.
     */
    const LOGIN_WINDOW = 900;
    const LOGIN_FAILURES_PER_LOGIN = 5;
    const LOGIN_FAILURES_PER_IP = 20;

    //todo VZ: Why not to use 0 as the default user id?
    /**
     * Constructor.
     * The parameter is used for preventing "strict" error.
     *
     * @param bool|int $id
     *
     * @todo избавиться от hardcoded имен полей формы?
     */
    public function __construct($id = false) {
        if(isset($_SESSION['UID'])){
            $id = $_SESSION['UID'];
        }
        parent::__construct($id);
    }

    /**
     * Check if the user authenticated.
     *
     * The return value mean:
     *   - true - the user is successfully authenticated;
     *   - false - the user is guest.
     *
     * @return boolean
     */
    public function isAuthenticated() {
        return (bool)$this->getID();
    }


    /**
     * Authenticate user by his name and password
     *
     * @param string $username User name.
     * @param string $password SHA-1 hash code.
     * @return bool|int
     */
    public static function authenticate($username, $password) {
        // заблокированный пользователь не входит (раньше входил и получал права гостя)
        $res = E()->getDB()->query('SELECT u_id, u_password FROM user_users WHERE u_name = %s AND u_is_active = 1', $username);
        $result = false;
        while ($row = $res->fetch(\PDO::FETCH_ASSOC)) {
            if (password_verify($password, $row['u_password'])) {
                $result = $row['u_id'];
                unset($row, $res);
                break;
            }
        }

        return $result;

    }

    /**
     * Попытки входа исчерпаны: для этого логина или с этого IP за окно было слишком много неудач.
     *
     * @param string $login
     * @param string $ip
     * @return bool
     */
    public static function isThrottled($login, $ip) {
        $since = time() - self::LOGIN_WINDOW;
        $db = E()->getDB();

        return $db->getScalar('SELECT COUNT(*) FROM user_login_attempts WHERE la_login = %s AND la_date > %s',
                self::attemptLogin($login), $since) >= self::LOGIN_FAILURES_PER_LOGIN
            || $db->getScalar('SELECT COUNT(*) FROM user_login_attempts WHERE la_ip = %s AND la_date > %s',
                $ip, $since) >= self::LOGIN_FAILURES_PER_IP;
    }

    /**
     * Записать неудачную попытку; записи старше окна удаляются тут же.
     *
     * @param string $login
     * @param string $ip
     */
    public static function registerFailure($login, $ip) {
        $db = E()->getDB();
        $db->modify('DELETE FROM user_login_attempts WHERE la_date <= %s', time() - self::LOGIN_WINDOW);
        $db->modify(QAL::INSERT, 'user_login_attempts',
            ['la_ip' => (string)$ip, 'la_login' => self::attemptLogin($login), 'la_date' => time()]);
    }

    /**
     * Удачный вход: неудачи этого логина забываются (неудачи IP остаются).
     *
     * @param string $login
     */
    public static function clearFailures($login) {
        E()->getDB()->modify(QAL::DELETE, 'user_login_attempts', null, ['la_login' => self::attemptLogin($login)]);
    }

    /**
     * Логин в журнале попыток: без пробелов по краям и не длиннее колонки.
     *
     * @param string $login
     * @return string
     */
    private static function attemptLogin($login) {
        return mb_substr(trim((string)$login), 0, 250);
    }
}
