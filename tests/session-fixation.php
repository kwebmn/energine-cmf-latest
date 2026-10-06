<?php
// Новый номер сессии при входе (надёжность 6, находка сравнения с xSight): вход с уже существующей сессией (cookie
// NRGNSID с номером живой сессии гостя) получает новый номер — прежний больше не действует (фиксация сессии: номер,
// подложенный злоумышленником, не становится номером сессии вошедшего). Данные сессии и вход сохраняются, выход
// работает. Случайный пароль при регистрации — random_int, а не mt_rand.
// Стенд: строка гостевой сессии с известным номером (claudefx…); удаляется в конце.
require __DIR__ . '/testlib.php';

$planted = 'claudefx' . bin2hex(random_bytes(16)); // 40 знаков, как session_native_id
$rowOf = fn(string $native) => q('SELECT session_id, u_id FROM share_session WHERE session_native_id = ?', [$native])->fetch();
// запрос только с этой cookie сессии (без банки): код ответа админки — 200 вошедшему, иначе 404
function adminCodeWith(string $native): int {
    $ch = curl_init(BASE . '/admin/');
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 60, CURLOPT_COOKIE => 'NRGNSID=' . $native]);
    curl_exec($ch);
    return (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
}
register_shutdown_function(fn() => q('DELETE FROM share_session WHERE session_native_id = ?', [$planted]));

// 1. живая сессия гостя с известным номером
q('INSERT INTO share_session (session_native_id, session_last_impression, session_created, session_expires, session_data)
   VALUES (?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + 3600, ?)', [$planted, '']);
check('стенд: гостевая сессия с известным номером', (bool)$rowOf($planted));

// 2. вход в браузере, где уже лежит этот номер (как login(), но банка с подложенной cookie)
@unlink($GLOBALS['jar']);
$host = (string)parse_url(BASE, PHP_URL_HOST);
file_put_contents($GLOBALS['jar'], "# Netscape HTTP Cookie File\n#HttpOnly_$host\tFALSE\t/\tTRUE\t0\tNRGNSID\t$planted\n");
http('/login/');
http('/auth.php', ['user' => ['login' => 1, 'username' => $GLOBALS['E']['ADMIN_EMAIL'], 'password' => $GLOBALS['E']['ADMIN_PASSWORD']]], [], BASE . '/login/');
$now = (string)cookie('NRGNSID');
[$c] = http('/admin/');
check('вход выполнен (админка открывается)', $c == 200, "HTTP $c");
check('после входа номер сессии другой', $now !== '' && $now !== $planted, $now === $planted ? 'номер прежний' : 'cookie нет');
$old = $rowOf($planted);
check('строки с прежним номером нет (или она без пользователя)', !$old || $old['u_id'] === null, json_encode($old));
$new = $now !== '' ? $rowOf($now) : false;
check('новая сессия принадлежит вошедшему', $new && (int)$new['u_id'] > 0, json_encode($new));
check('с прежним номером админка не открывается (гость)', adminCodeWith($planted) == 404, 'HTTP ' . adminCodeWith($planted));

// 3. выход работает
logout();
[$c] = http('/admin/');
check('после выхода админка закрыта', $c == 404, "HTTP $c");

// 4. случайный пароль регистрации — криптостойкий генератор
$src = (string)file_get_contents(ROOT . '/core/modules/share/gears/User.php');
check('User::generatePassword — random_int, без mt_rand', preg_match('~function generatePassword.*?\n    }~s', $src, $m)
    && str_contains($m[0], 'random_int') && !str_contains($m[0], 'mt_rand'));
done('session-fixation');
