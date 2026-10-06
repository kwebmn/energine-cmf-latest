<?php
// Форма сохранения решается на сервере (надёжность 6, находка сравнения с xSight):
// - набор полей сохранения: ключ записи в форме — «правка», нет — «добавление», а не по componentAction из запроса
//   (у пользователя: повтор логина — понятный отказ ERR_USER_EXISTS, а не ошибка базы);
// - состояние компонента из POST (имя[state]) не принимается: интерфейс его не шлёт, а чужое имя роняло страницу;
// - проверка формы: необязательные поля с непустым значением проверяются (длина, шаблон), ошибки — все сразу.
// Стенд: временный пользователь claude-fs-…@example.com; удаляется в конце.
require __DIR__ . '/testlib.php';

$login = 'claude-fs-' . bin2hex(random_bytes(3)) . '@example.com';
register_shutdown_function(fn() => q('DELETE FROM user_users WHERE u_name = ?', [$login]));
$save = function (array $user, string $action) {
    $f = ['componentAction' => $action, 'group_id' => [4]];
    foreach ($user + ['u_id' => '', 'u_is_active' => '1', 'u_password' => '', 'u_fullname' => 'Claude', 'u_phone' => '',
                 'u_country' => '', 'u_city' => '', 'u_person_name' => '', 'u_address' => ''] as $k => $v) {
        $f["user_users[$k]"] = $v;
    }
    return json('/admin/users/single/userEditor/save', http_build_query($f));
};
$errors = fn($j) => json_encode($j['errors'] ?? null, JSON_UNESCAPED_UNICODE);
$label = fn(string $const) => ($t = (string)translation($const)) !== '' ? $t : $const;

login();
// 1. повтор логина с подменённой формой «правка» (ключа записи нет): понятный отказ, пользователь не создан
[$c, $j] = $save(['u_name' => $GLOBALS['E']['ADMIN_EMAIL'], 'u_password' => 'claude-pass-1'], 'edit');
check('«правка» без ключа записи — это добавление: повтор логина — ERR_USER_EXISTS, а не ошибка базы',
    is_array($j) && empty($j['result']) && str_contains($errors($j), $label('ERR_USER_EXISTS')), "HTTP $c " . $errors($j));

// 2. ошибки проверки — все сразу, и необязательное поле с непустым значением проверяется (имя длиннее колонки)
[$c, $j] = $save(['u_name' => $login, 'u_password' => 'claude-pass-1', 'u_fullname' => '', 'u_person_name' => str_repeat('я', 150)], 'add');
$e = $errors($j);
check('проверка формы: пустое ФИО и слишком длинное необязательное имя — обе ошибки сразу', is_array($j) && empty($j['result'])
    && str_contains($e, $label('FIELD_U_FULLNAME')) && str_contains($e, $label('FIELD_U_PERSON_NAME')), "HTTP $c $e");
check('с ошибками пользователь не создан', (int)scalar('SELECT COUNT(*) FROM user_users WHERE u_name = ?', [$login]) === 0);

// 3. обычное добавление и правка с пустым паролем — как прежде
[$c, $j] = $save(['u_name' => $login, 'u_password' => 'claude-pass-1', 'u_fullname' => 'Claude Form'], 'add');
$uid = (int)scalar('SELECT u_id FROM user_users WHERE u_name = ?', [$login]);
check('добавление пользователя сохраняется', !empty($j['result']) && $uid > 0, "HTTP $c " . $errors($j));
$hash = (string)scalar('SELECT u_password FROM user_users WHERE u_id = ?', [$uid]);
[$c, $j] = $save(['u_id' => (string)$uid, 'u_name' => $login, 'u_password' => '', 'u_fullname' => 'Claude Form 2'], 'edit');
check('правка с пустым паролем: ФИО сохранено, пароль прежний', !empty($j['result'])
    && scalar('SELECT u_fullname FROM user_users WHERE u_id = ?', [$uid]) === 'Claude Form 2'
    && (string)scalar('SELECT u_password FROM user_users WHERE u_id = ?', [$uid]) === $hash, "HTTP $c " . $errors($j));
logout();

// 4. состояние компонента из POST не принимается: главная как обычно
[$c, $b] = http('/', ['langSwitcher' => ['state' => 'claudeNope']]);
check('POST с чужим состоянием компонента (langSwitcher[state]) — обычная главная', $c == 200 && str_contains($b, 'lang_switcher_item'), "HTTP $c");
done('form-state');
