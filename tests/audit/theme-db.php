<?php
// Помощник theme.js: временный посетитель для страницы профиля (группа зарегистрированных, как после
// регистрации) и его удаление.
//   php8.5 theme-db.php user-add       — создать, вывести {"login": …, "password": …}
//   php8.5 theme-db.php user-remove    — удалить всех посетителей теста
//   php8.5 theme-db.php attempts-remove ЛОГИН — убрать неудачные попытки входа этого логина
//   php8.5 theme-db.php menu-child on|off — «Возможности / Структура и тексты» в меню (подпункт меню)
//   php8.5 theme-db.php sections-add    — стенды секций визиток: claude-sections (все восемь секций с текстом образцов,
//                                         у первого экрана картинка) и claude-sections-edge (без картинки, одна услуга
//                                         с длинным словом, таблица в FAQ); скрыты из меню
//   php8.5 theme-db.php sections-remove — удалить стенды с текстами
//   php8.5 theme-db.php sections-empty NUM — у стенда claude-sections убрать текст секции NUM (пустая секция)
//   php8.5 theme-db.php sections-get NUM   — текст секции NUM стенда claude-sections (JSON; false — блока нет)
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'user-add':
        $login = 'claude-theme-' . getmypid() . '@localhost';
        $password = bin2hex(random_bytes(8));
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude Theme']);
        $uid = pdo()->lastInsertId();
        // та же группа, что у зарегистрированного посетителя (Register)
        q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, 4)', [$uid]);
        echo json_encode(['login' => $login, 'password' => $password]);
        break;
    case 'user-remove':
        q("DELETE FROM user_users WHERE u_name LIKE 'claude-theme-%'");
        break;
    case 'attempts-remove':
        // неудачные попытки входа теста (проверка сообщения о неудаче): иначе они остаются в журнале попыток
        q('DELETE FROM user_login_attempts WHERE la_login = ?', [$argv[2] ?? '']);
        break;
    case 'menu-child':
        q("UPDATE share_sitemap s JOIN share_sitemap p ON p.smap_id = s.smap_pid SET s.smap_in_menu = ?
           WHERE p.smap_segment = 'features' AND s.smap_segment = 'content'", [($argv[2] ?? '') === 'on' ? 1 : 0]);
        break;
    case 'sections-add':
        sectionsRemove();
        $root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
        $names = ['hero' => 11, 'services' => 12, 'prices' => 13, 'reviews' => 14, 'gallery' => 15, 'faq' => 16, 'contacts' => 17, 'cta' => 18];
        $xml = '<content>';
        foreach ($names as $n => $num) $xml .= "<container name=\"$n\" section=\"$n\"><component name=\"section_$n\" "
            . "class=\"Energine\\share\\components\\TextBlock\"><params><param name=\"num\">$num</param><param name=\"section_sample\">"
            . 'TXT_SECTION_SAMPLE_' . strtoupper($n) . '</param></params></component></container>';
        $xml .= '</content>';
        $img = scalar("SELECT upl_path FROM share_uploads WHERE upl_mime_type LIKE 'image/%' ORDER BY upl_id LIMIT 1");
        $sample = fn($n) => scalar("SELECT tr.ltag_value_rtf FROM share_lang_tags t JOIN share_lang_tags_translation tr USING (ltag_id)
            JOIN share_languages l USING (lang_id) WHERE t.ltag_name = ? AND l.lang_default = 1", ['TXT_SECTION_SAMPLE_' . strtoupper($n)]);
        $stands = [
            'claude-sections' => fn($n) => ($n === 'hero' && $img ? '<p><img src="' . $img . '" alt=""></p>' : '')
                . ($n === 'gallery' && $img ? $sample($n) . str_repeat('<p><img src="' . $img . '" alt="Картинка"></p>', 3) : $sample($n)),
            'claude-sections-edge' => fn($n) => match ($n) {
                'services' => '<h2>Услуги</h2><ul><li><strong>Единственная</strong> Сверхдлинноесловобезпробеловпроверкапереносастрокнаузкомэкране</li></ul>',
                'faq' => $sample($n) . '<table><tr><th>Колонка один</th><th>Колонка два</th><th>Колонка три</th><th>Колонка четыре</th></tr>'
                    . '<tr><td>значение</td><td>значение</td><td>значение</td><td>значение</td></tr></table>',
                default => $sample($n),
            },
        ];
        $lang = (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 1');
        foreach ($stands as $segment => $text) {
            q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_content_xml, smap_pid, smap_segment, smap_in_menu, smap_order_num)
               VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, ?, 0, 999)", [$xml, $root, $segment]);
            $id = (int)pdo()->lastInsertId();
            foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l)
                q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l, 'Стенд секций']);
            q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?',
                [$id, (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root])]);
            foreach ($names as $n => $num) {
                q('INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, ?)', [$id, $num]);
                q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [pdo()->lastInsertId(), $lang, $text($n)]);
            }
        }
        echo json_encode(array_keys($stands));
        break;
    case 'sections-empty':
        q("DELETE t FROM share_textblocks t JOIN share_sitemap s USING (smap_id) WHERE s.smap_segment = 'claude-sections' AND t.tb_num = ?",
            [(string)(int)($argv[2] ?? 0)]);
        break;
    case 'sections-get':
        echo json_encode(scalar("SELECT tt.tb_content FROM share_textblocks t JOIN share_sitemap s USING (smap_id)
            JOIN share_textblocks_translation tt ON tt.tb_id = t.tb_id AND tt.lang_id = 1
            WHERE s.smap_segment = 'claude-sections' AND t.tb_num = ?", [(string)(int)($argv[2] ?? 0)]), JSON_UNESCAPED_UNICODE);
        break;
    case 'sections-remove':
        sectionsRemove();
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}

// стенды секций и всё их: тексты, права, переводы
function sectionsRemove(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment IN ('claude-sections', 'claude-sections-edge')")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        q('DELETE tt FROM share_textblocks_translation tt JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ?', [$id]);
        q('DELETE FROM share_textblocks WHERE smap_id = ?', [$id]);
        q('DELETE FROM share_access_level WHERE smap_id = ?', [$id]);
        q('DELETE FROM share_sitemap_translation WHERE smap_id = ?', [$id]);
        q('DELETE FROM share_sitemap WHERE smap_id = ?', [$id]);
    }
}
