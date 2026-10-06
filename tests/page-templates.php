<?php
// Шаблон новой страницы (идея xsight): в форме добавления страницы в раздел заранее выбран шаблон, который чаще всего
// у подстраниц раздела (один такой, без ничьей), и самый частый у них макет; у корня служебные страницы (admin, login…)
// не считаются; раздел без подстраниц, ничья, выключенный вариант («уникальный» шаблон уже занят) — текстовая страница
// и базовый макет. Варианта без файла (висячая ссылка в web/templates) в списке нет. У шаблонов — подсказка (data-hint).
// Стенд: разделы claude-pt (две «Услуги», одна «Текстовая»), claude-pt-empty, claude-pt-tie («Услуга» и «Контакты»),
// claude-pt-u (подстраница с шаблоном robots.txt), claude-pt-seg (подстраница с шаблоном с постоянным сегментом —
// временный шаблон сайта claude_pt_seg), висячая ссылка claude_pt_gone; всё удаляется в конце.
require __DIR__ . '/testlib.php';

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
$gone = WEB . '/templates/content/main/claude_pt_gone.content.xml';
$segTpl = ROOT . '/site/modules/main/templates/content/claude_pt_seg.content.xml';
$segLink = WEB . '/templates/content/main/claude_pt_seg.content.xml';

// выбранные варианты списков шаблона и макета, выключенные варианты и подсказки в форме добавления страницы в раздел $pid
function addForm(int $pid): array {
    [$c, $html] = http('/admin/structure/single/divEditor/add/' . $pid . '/');
    $d = new DOMDocument();
    @$d->loadHTML('<?xml encoding="UTF-8">' . $html);
    $x = new DOMXPath($d);
    $selected = function (string $id) use ($x): ?string {
        $o = $x->query("//select[@id='$id']/option[@selected]")->item(0);
        return $o ? $o->getAttribute('value') : null;
    };
    $hints = $disabled = [];
    foreach ($x->query("//select[@id='smap_content']/option") as $o) {
        $hints[$o->getAttribute('value')] = $o->getAttribute('data-hint');
        if ($o->hasAttribute('disabled')) {
            $disabled[] = $o->getAttribute('value');
        }
    }
    return ['code' => $c, 'content' => $selected('smap_content'), 'layout' => $selected('smap_layout'), 'hints' => $hints, 'disabled' => $disabled];
}

login();
try {
    // шаблон со своим постоянным сегментом (как robots.txt, но не «уникальный») — в разделе он бывает только раз
    file_put_contents($segTpl, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<content segment=\"claude-seg.xml\">\n"
        . "    <container name=\"c\" block=\"alfa\"/>\n</content>\n");
    @chown($segTpl, SITE_USER);
    symlink($segTpl, $segLink);
    @lchown($segLink, SITE_USER);
    $section = savePage(null, $ROOT, 'claude-pt', ['content' => 'childs.content.xml']);
    $empty = savePage(null, $ROOT, 'claude-pt-empty', ['content' => 'childs.content.xml']);
    $tie = savePage(null, $ROOT, 'claude-pt-tie', ['content' => 'childs.content.xml']);
    $uniq = savePage(null, $ROOT, 'claude-pt-u', ['content' => 'childs.content.xml']);
    $seg = savePage(null, $ROOT, 'claude-pt-seg', ['content' => 'childs.content.xml']);
    $kids = $section && $tie && $uniq && $seg ? [
        savePage(null, $section, 'one', ['content' => 'main/service.content.xml']),
        savePage(null, $section, 'two', ['content' => 'main/service.content.xml']),
        savePage(null, $section, 'three'),
        savePage(null, $tie, 'a', ['content' => 'main/service.content.xml']),
        savePage(null, $tie, 'b', ['content' => 'main/contacts.content.xml']),
        savePage(null, $uniq, 'r', ['content' => 'robots_txt.content.xml', 'layout' => 'empty.layout.xml']),
        savePage(null, $seg, 'claude-seg.xml', ['content' => 'main/claude_pt_seg.content.xml']),
    ] : [];
    if (!check('стенд: разделы с подстраницами, пустой раздел, ничья, раздел с «уникальным» шаблоном и с шаблоном с сегментом',
        $section && $empty && $tie && $uniq && $seg && count(array_filter($kids)) === 7)) {
        throw new RuntimeException('стенд не создан');
    }
    // как после удаления шаблона из site/modules без setup linker: ссылка ведёт в каталог шаблонов сайта, файла нет
    symlink(ROOT . '/site/modules/main/templates/content/claude_pt_gone.content.xml', $gone);
    @lchown($gone, SITE_USER);
    // страница, чей шаблон стал такой висячей ссылкой (в разделе с подстраницами: «Услуга» там по-прежнему чаще)
    $gonePage = savePage(null, $section, 'gone', ['content' => 'main/claude_pt_gone.content.xml']);

    $f = addForm($section);
    check('раздел с подстраницами: заранее выбран самый частый шаблон подстраниц — «Услуга», и его макет',
        $f['content'] === 'main/service.content.xml' && $f['layout'] === 'default.layout.xml', $f['content'] . ' | ' . $f['layout']);
    $f = addForm($empty);
    check('раздел без подстраниц: текстовая страница и базовый макет', $f['content'] === 'textblock.content.xml' && $f['layout'] === 'default.layout.xml',
        $f['content'] . ' | ' . $f['layout']);
    $f = addForm($tie);
    check('ничья («Услуга» и «Контакты» по одной): текстовая страница и базовый макет',
        $f['content'] === 'textblock.content.xml' && $f['layout'] === 'default.layout.xml', $f['content'] . ' | ' . $f['layout']);
    $f = addForm($uniq);
    check('самый частый шаблон выключен в списке («уникальный» robots.txt уже занят): не выбран — текстовая страница и базовый макет',
        in_array('robots_txt.content.xml', $f['disabled'], true) && $f['content'] === 'textblock.content.xml' && $f['layout'] === 'default.layout.xml',
        $f['content'] . ' | ' . $f['layout'] . ' | выключены: ' . implode(', ', $f['disabled']));
    $f = addForm($seg);
    check('шаблон со своим постоянным сегментом в списке есть, но заранее не выбран (сегмент уже занят) — текстовая страница',
        array_key_exists('main/claude_pt_seg.content.xml', $f['hints']) && !in_array('main/claude_pt_seg.content.xml', $f['disabled'], true)
        && $f['content'] === 'textblock.content.xml' && $f['layout'] === 'default.layout.xml', $f['content'] . ' | ' . $f['layout']);

    // корень: те же правила по живым данным, служебные страницы (как DivisionEditor::SYSTEM_SEGMENTS) не считаются
    $system = ['admin', 'login', 'register', 'restore-password', 'profile', 'sitemap', 'google-sitemap', 'robots.txt'];
    $counts = q('SELECT smap_content, COUNT(*) n FROM share_sitemap WHERE smap_pid = ? AND smap_segment NOT IN ('
        . implode(',', array_fill(0, count($system), '?')) . ") AND smap_segment NOT LIKE 'claude-pt%' GROUP BY smap_content ORDER BY n DESC",
        array_merge([$ROOT], $system))->fetchAll(PDO::FETCH_KEY_PAIR);
    $top = array_keys($counts, $counts ? max($counts) : -1);
    $want = count($top) === 1 ? $top[0] : 'textblock.content.xml';
    $f = addForm($ROOT);
    check("страница верхнего уровня: самый частый шаблон страниц сайта без служебных — $want", $f['content'] === $want,
        $f['content'] . ' | ' . json_encode($counts, JSON_UNESCAPED_UNICODE));
    check('заранее выбранный вариант не выключен', $f['content'] !== null && !in_array($f['content'], $f['disabled'], true), (string)$f['content']);
    check('шаблона без файла (висячая ссылка в web/templates) в списке нет', !array_key_exists('main/claude_pt_gone.content.xml', $f['hints']),
        implode(', ', array_keys($f['hints'])));
    // ревью этапа: в форме правки страницы с таким шаблоном он остаётся в списке выбранным (выключенным) — иначе браузер
    // выбрал бы первый вариант, и «Сохранить» молча сменило бы шаблон
    [$c, $html] = http("/admin/structure/single/divEditor/$gonePage/edit/");
    $d = new DOMDocument();
    @$d->loadHTML('<?xml encoding="UTF-8">' . $html);
    $opt = (new DOMXPath($d))->query("//select[@id='smap_content']/option[@value='main/claude_pt_gone.content.xml']")->item(0);
    check('форма правки страницы с шаблоном без файла: её шаблон в списке и выбран', $c == 200 && $opt && $opt->hasAttribute('selected'),
        "HTTP $c " . ($opt ? 'вариант есть, selected: ' . var_export($opt->hasAttribute('selected'), true) : 'варианта нет'));
    foreach (['main/landing.content.xml', 'main/service.content.xml', 'main/contacts.content.xml', 'textblock.content.xml', 'childs.content.xml',
                 'map.content.xml', 'main.content.xml'] as $tpl) {
        $hint = $f['hints'][$tpl] ?? '';
        check("подсказка шаблона $tpl — текст, а не имя константы", $hint !== '' && !str_starts_with($hint, 'HINT_'), $hint);
    }
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    foreach ([$gone, $segLink, $segTpl] as $file) {
        if (is_link($file) || is_file($file)) {
            unlink($file);
        }
    }
    // подстраницы, переводы, права удаляются каскадом
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment IN ('claude-pt', 'claude-pt-empty', 'claude-pt-tie', 'claude-pt-u', 'claude-pt-seg')", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('page-templates');
