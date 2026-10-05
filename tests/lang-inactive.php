<?php
// Язык «в подготовке» (надёжность, этап 3): share_languages.lang_is_active = 0 — язык виден только редакторам
// (вошедшим с полными правами на корень): гостю его адреса дают 404, в переключателе языка его нет; администратор
// открывает и правит; язык по умолчанию выключить нельзя (ERR_LANG_DEFAULT_INACTIVE). Второй язык площадки
// выключается на время проверки и возвращается в конце (и при падении).
require __DIR__ . '/testlib.php';

if (!q("SHOW COLUMNS FROM share_languages LIKE 'lang_is_active'")->fetch()) {
    check('колонка share_languages.lang_is_active есть (sql/cut/stage16.sql)', false);
    done('lang-inactive');
}
$langs = q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_default DESC')->fetchAll();
[$def, $other] = [$langs[0], $langs[1] ?? null];
if (!$other) { check('на площадке два языка', false); done('lang-inactive'); }
$oid = (int)$other['lang_id'];
$abbr = $other['lang_abbr'];
function restoreLang(): void {
    q('UPDATE share_languages SET lang_is_active = 1');
}
register_shutdown_function('restoreLang');
q('UPDATE share_languages SET lang_is_active = 0 WHERE lang_id = ?', [$oid]);
$switcherLinks = function (string $body) use ($abbr): array {
    preg_match_all('~<li class="lang_switcher_item">.*?</li>~su', $body, $m);
    return $m[0];
};

// 1. гость: адреса выключенного языка — 404, в переключателе его нет
logout();
[$c] = http("/$abbr/info/quick-start/");
check("гость: /$abbr/info/quick-start/ — 404", $c == 404, "HTTP $c");
[$c] = http("/$abbr/");
check("гость: /$abbr/ — 404", $c == 404, "HTTP $c");
[$c, $b] = http('/');
$links = $switcherLinks($b);
check('гость: в переключателе языка нет выключенного', $c == 200 && !preg_grep("~href=\"(?:[^\"]*/)?$abbr/~", $links), implode(' | ', array_map('strip_tags', $links)));
[$c, $b] = http("/$abbr/google-sitemap/");
check("гость: карта сайта выключенного языка — 404", $c == 404, "HTTP $c");

// 2. администратор видит и правит
login();
[$c, $b] = http("/$abbr/info/quick-start/");
check("администратор: /$abbr/info/quick-start/ открывается", $c == 200 && str_contains($b, 'quick-start'), "HTTP $c");
[$c, $b] = http('/');
$links = $switcherLinks($b);
$mark = (string)translation('TXT_LANG_INACTIVE');
check('администратор: в переключателе выключенный язык с пометкой «в подготовке»',
    (bool)preg_grep("~href=\"(?:[^\"]*/)?$abbr/~", $links) && $mark !== '' && str_contains(implode(' ', $links), $mark), implode(' | ', array_map('strip_tags', $links)));
// переводы грида языков: флаг есть в данных
[$c, $j] = json('/admin/translations/languages/single/langEditor/get-data/', '');
check('грид языков отдаёт флаг lang_is_active', $c == 200 && isset($j['meta']['lang_is_active']) && isset($j['data'][0]['lang_is_active']), "HTTP $c " . substr(json_encode($j['meta'] ?? []), 0, 160));

// 3. язык по умолчанию выключить нельзя
$did = (int)$def['lang_id'];
[$c, $html] = http("/admin/translations/languages/single/langEditor/$did/edit/");
check('форма языка по умолчанию открывается', $c == 200 && str_contains($html, 'lang_is_active'), "HTTP $c");
[$c, $j, $raw] = json('/admin/translations/languages/single/langEditor/save/', formData($html, ['share_languages[lang_is_active]' => '0']));
check('выключение языка по умолчанию — отказ ERR_LANG_DEFAULT_INACTIVE, флаг не изменился',
    empty($j['result']) && str_contains(json_encode($j['errors'] ?? [], JSON_UNESCAPED_UNICODE), (string)translation('ERR_LANG_DEFAULT_INACTIVE'))
    && (int)scalar('SELECT lang_is_active FROM share_languages WHERE lang_id = ?', [$did]) === 1, "HTTP $c " . substr($raw, 0, 200));
// а второй язык включается обратно через форму
[$c, $html] = http("/admin/translations/languages/single/langEditor/$oid/edit/");
[$c, $j, $raw] = json('/admin/translations/languages/single/langEditor/save/', formData($html, ['share_languages[lang_is_active]' => '1']));
check('включение языка через форму сохраняется', !empty($j['result']) && (int)scalar('SELECT lang_is_active FROM share_languages WHERE lang_id = ?', [$oid]) === 1, "HTTP $c " . substr($raw, 0, 200));
logout();
[$c] = http("/$abbr/info/quick-start/");
check("язык включён — гостю снова доступен", $c == 200, "HTTP $c");
done('lang-inactive');
