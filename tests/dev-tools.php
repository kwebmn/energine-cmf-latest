<?php
// Удобство разработчика (этап 2):
//  1. в XML страницы компонент можно указать коротким именем (class="TextBlock"); неизвестное имя — ошибка
//     разработчика с этим именем;
//  2. текстовый блок секции задаётся именем секции (param section=hero): номер блока и образец — из TextBlock.
// Временные страницы со своим XML создаются и удаляются здесь.
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function stand(string $segment, string $xml): int {
    global $root, $info;
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_content_xml, smap_pid, smap_segment, smap_in_menu, smap_order_num)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, ?, 0, 999)", [$xml, $root, $segment]);
    $id = (int)pdo()->lastInsertId();
    foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l)
        q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l, 'Стенд']);
    q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
    return $id;
}
function unstand(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment LIKE 'claude-dev-%'")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
unstand();
register_shutdown_function('unstand');

stand('claude-dev-short', '<content><container name="s" section="hero"><component name="tbShort" class="TextBlock">'
    . '<params><param name="section">hero</param></params></component></container>'
    . '<component name="tbFull" class="Energine\share\components\TextBlock"><params><param name="num">1</param></params></component></content>');
stand('claude-dev-bad', '<content><component name="x" class="NoSuchThing"/></content>');

login();
[$code, $xml] = http('/claude-dev-short/?debug');
$d = new DOMDocument();
$ok = $code == 200 && @$d->loadXML($xml);
$xp = $ok ? new DOMXPath($d) : null;
$short = $xp ? $xp->query('//component[@name="tbShort"]')->item(0) : null;
$full = $xp ? $xp->query('//component[@name="tbFull"]')->item(0) : null;
check('короткое имя class="TextBlock" — компонент TextBlock', $short && $short->getAttribute('sample') === 'TextBlock', "HTTP $code");
check('полное имя по-прежнему работает', $full && $full->getAttribute('sample') === 'TextBlock' && $full->getAttribute('num') === '1');
check('секция по имени: section=hero → номер 11', $short && $short->getAttribute('num') === '11'
    && $short->getAttribute('section') === 'hero',
    $short ? 'num=' . $short->getAttribute('num') . ' section=' . $short->getAttribute('section') : 'нет');
[$code, $body] = http('/claude-dev-bad/');
check('неизвестное короткое имя — ошибка разработчика с этим именем (в отладке)', str_contains($body, 'NoSuchThing')
    && str_contains($body, 'ERR_DEV_NO_COMPONENT_CLASS'), "HTTP $code " . substr(strip_tags($body), 0, 200));
logout();

// 3. setup translations: недостающие константы из файла добавляются, повторный запуск ничего не меняет, правленый в
//    базе перевод не перезаписывается
$owner = posix_getpwuid(fileowner(WEB))['name'];
$setup = fn(string ...$a) => shell_exec('cd ' . escapeshellarg(WEB) . ' && runuser -u ' . escapeshellarg($owner) . ' -- php8.5 index.php setup '
    . implode(' ', array_map('escapeshellarg', $a)) . ' 2>&1');
$tmp = sys_get_temp_dir() . '/claude-translations-' . getmypid() . '.php';
file_put_contents($tmp, "<?php return ['CLAUDE_TEST_CONST' => ['ru' => 'Проба', 'ua' => 'Проба ua']];\n");
chmod($tmp, 0644);
$tr = fn() => q("SELECT l.lang_abbr, tr.ltag_value_rtf FROM share_lang_tags t JOIN share_lang_tags_translation tr USING (ltag_id)
    JOIN share_languages l USING (lang_id) WHERE t.ltag_name = 'CLAUDE_TEST_CONST' ORDER BY 1")->fetchAll(PDO::FETCH_KEY_PAIR);
register_shutdown_function(function () use ($tmp) {
    @unlink($tmp);
    q("DELETE tr FROM share_lang_tags_translation tr JOIN share_lang_tags t USING (ltag_id) WHERE t.ltag_name = 'CLAUDE_TEST_CONST'");
    q("DELETE FROM share_lang_tags WHERE ltag_name = 'CLAUDE_TEST_CONST'");
});
$out1 = $setup('translations', "--file=$tmp");
check('setup translations добавляет константу из файла на всех языках', $tr() == ['ru' => 'Проба', 'ua' => 'Проба ua'], $out1);
q("UPDATE share_lang_tags_translation tr JOIN share_lang_tags t USING (ltag_id) SET tr.ltag_value_rtf = 'Правка' WHERE t.ltag_name = 'CLAUDE_TEST_CONST' AND tr.lang_id = 1");
$out2 = $setup('translations', "--file=$tmp");
check('повторный запуск не перезаписывает правленый перевод', ($tr()['ru'] ?? '') === 'Правка' && preg_match('~добавлено: 0~iu', (string)$out2), $out2);
$site = include ROOT . '/site/modules/main/translations.php';
check('переводы сайта в site/modules/main/translations.php: шаблоны страниц и образцы секций',
    is_array($site) && isset($site['CONTENT_LANDING']['ru'], $site['TXT_SECTION_SAMPLE_HERO']['ua']));
// 4. setup page: шаблон страницы из секций — файл, название в translations.php и в базе, связан в web/templates;
//    плохое имя, неизвестная секция, существующий файл — отказ, ничего не создано
$trFile = ROOT . '/site/modules/main/translations.php';
$trOrig = file_get_contents($trFile);
$tpl = ROOT . '/site/modules/main/templates/content/claude_page.content.xml';
register_shutdown_function(function () use ($trFile, $trOrig, $tpl, $setup) {
    @unlink($tpl);
    file_put_contents($trFile, $trOrig);
    q("DELETE tr FROM share_lang_tags_translation tr JOIN share_lang_tags t USING (ltag_id) WHERE t.ltag_name = 'CONTENT_CLAUDE_PAGE'");
    q("DELETE FROM share_lang_tags WHERE ltag_name = 'CONTENT_CLAUDE_PAGE'");
    $setup('linker');
});
$out = $setup('page', '--name=claude_page', '--title=Проба страницы', '--sections=hero,cta');
$x = is_file($tpl) ? simplexml_load_file($tpl) : null;
$secs = $x ? array_map('strval', $x->xpath('//component[@class="TextBlock"]/params/param[@name="section"]')) : [];
check('setup page: файл шаблона с секциями hero, cta (короткие имена, section)', $secs === ['hero', 'cta'], $out);
check('setup page: название CONTENT_CLAUDE_PAGE — в translations.php и в базе', str_contains(file_get_contents($trFile), "'CONTENT_CLAUDE_PAGE'")
    && scalar("SELECT COUNT(*) FROM share_lang_tags WHERE ltag_name = 'CONTENT_CLAUDE_PAGE'") == 1);
check('setup page: шаблон связан в web/templates/content/main', is_file(WEB . '/templates/content/main/claude_page.content.xml'));
$before = [file_get_contents($trFile), glob(ROOT . '/site/modules/main/templates/content/*.xml')];
foreach ([['--name=../x', '--title=X', '--sections=hero'], ['--name=Bad Name', '--title=X', '--sections=hero'],
          ['--name=claude_page2', '--title=X', '--sections=hero,nope'], ['--name=claude_page', '--title=X', '--sections=hero'],
          ['--name=claude_page3', '--sections=hero']] as $bad) {
    $o = $setup('page', ...$bad);
    check('setup page ' . implode(' ', $bad) . ' — отказ, ничего не создано',
        $before === [file_get_contents($trFile), glob(ROOT . '/site/modules/main/templates/content/*.xml')] && preg_match('~ошибка|Error|отказ|нельзя|нет|неизвест~iu', (string)$o),
        substr((string)$o, -200));
}
done('dev-tools');
