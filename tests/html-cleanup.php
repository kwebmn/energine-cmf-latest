<?php
// Очистка HTML без tidy (надёжность 6, находка сравнения с xSight): расширения tidy на сервере нет — «агрессивная
// очистка» (site.aggressive_cleanup) молча не работала. HtmlCleaner (Dom\HTMLDocument) убирает только мусор
// Office/Word: комментарии (и условные), <style> с mso-, <meta>, <link>, <xml>, <title>, элементы и атрибуты с
// двоеточием (o:p, w:…, v:… — содержимое элементов остаётся), классы Mso…, объявления mso-… в style, <font>
// (содержимое остаётся). Текст без признаков Office — байт в байт: iframe, script, значки, ссылки владельца целы.
// Стенд: страница claude-hc с текстовым блоком (в базе напрямую, без сдвига порядка); удаляется в конце.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

$owner = '<p>Карта: <iframe src="https://www.openstreetmap.org/export/embed.html" width="400"></iframe></p><script>window.claudeX = 1;</script>'
    . '<p><i class="fa fa-phone"></i> <a href="https://example.com" target="_blank">ссылка</a> &amp; &nbsp; <b>жирный</b><br /></p>';
$word = '<!--[if gte mso 9]><xml><o:OfficeDocumentSettings><o:AllowPNG/></o:OfficeDocumentSettings></xml><![endif]-->'
    . '<style>p.MsoNormal {mso-style-parent:""; margin:0cm;}</style><meta name="Generator" content="Microsoft Word 15">'
    . '<p class="MsoNormal" style="margin-bottom:0cm;mso-line-height-alt:12pt"><b><span lang="EN-US" style="font-size:12pt;mso-bidi-font-weight:bold">Жирный</span></b>'
    . ' текст <a href="https://example.com/doc">ссылка</a><o:p></o:p></p>'
    . '<p class="MsoNormal"><o:p>&nbsp;</o:p></p>'
    . '<ul><li class="MsoListParagraph" style="mso-list:l0 level1 lfo1">пункт</li></ul>'
    . '<table class="MsoTableGrid"><tbody><tr><td style="width:100pt;mso-border-alt:solid windowtext .5pt">ячейка<o:p></o:p></td></tr></tbody></table>'
    . '<p><font face="Arial">шрифт</font> <w:Sdt>поле</w:Sdt> <v:shape id="x" o:spid="y">фигура</v:shape></p>';

// 1. консоль: сам очиститель
$cls = 'Energine\share\gears\HtmlCleaner';
if (check('класс HtmlCleaner есть', class_exists($cls))) {
    check('HTML владельца без признаков Office — байт в байт', $cls::clean($owner) === $owner, $cls::clean($owner));
    $out = $cls::clean($word);
    foreach (['mso-', 'Mso', '<o:', '<w:', '<v:', '<!--', '<style', '<meta', '<font', 'o:spid'] as $junk) {
        check("Word: нет «{$junk}»", stripos($out, $junk) === false, $out);
    }
    foreach (['<b>', 'Жирный', 'текст', '<a href="https://example.com/doc">ссылка</a>', '<ul>', 'пункт', '<table', 'ячейка', 'шрифт', 'поле',
                 'фигура', 'lang="EN-US"', 'font-size:12pt', 'margin-bottom:0cm'] as $keep) {
        check("Word: остаётся «{$keep}»", str_contains($out, $keep), $out);
    }
    check('Word: пустая строка (абзац с неразрывным пробелом) остаётся', (bool)preg_match('~<p>(&nbsp;|\x{00A0})</p>~u', $out), $out);
    // ревью этапа: кодировка, разметка владельца рядом с мусором Word, маркеры списков Word
    $out = $cls::clean('<meta charset="windows-1251"><p class="MsoNormal">Привет, мир</p>');
    check('<meta charset> не UTF-8 — кириллица цела (без кракозябр)', str_contains($out, 'Привет, мир') && !str_contains($out, 'Р'), $out);
    $owned = '<!--noindex--><p>Скрыто от Яндекса</p><!--/noindex-->'
        . '<svg viewBox="0 0 10 10"><title>Иконка</title><use xlink:href="#i-phone"></use></svg>'
        . '<button x-on:click="open = true" :class="{ on: open }">Меню</button><link rel="stylesheet" href="https://widget.example/w.css">';
    check('разметка владельца без признаков Office (noindex, svg, атрибуты виджетов, link) — байт в байт', $cls::clean($owned) === $owned);
    $out = $cls::clean('<p class="MsoNormal">из Word</p>' . $owned);
    check('рядом с мусором Word: комментарий noindex, title и xlink:href в svg, x-on:click и :class, link виджета — на месте',
        str_contains($out, '<!--noindex-->') && str_contains($out, '<!--/noindex-->') && str_contains($out, '<title>Иконка</title>')
        && str_contains($out, 'xlink:href="#i-phone"') && str_contains($out, 'x-on:click="open = true"') && str_contains($out, ':class=')
        && str_contains($out, 'href="https://widget.example/w.css"') && !str_contains($out, 'Mso'), $out);
    $out = $cls::clean('<link rel="File-List" href="file:///C:/x/filelist.xml"><meta name="ProgId" content="Word.Document">'
        . '<p class="MsoListParagraphCxSpFirst" style="text-indent:-18pt;mso-list:l0 level1 lfo1"><span style="font-family:Symbol;mso-list:Ignore">·'
        . '<span style="font:7.0pt Times New Roman">&nbsp;&nbsp;&nbsp;</span></span>первый пункт</p>');
    check('служебные link и meta Word убраны; маркер списка Word (mso-list:Ignore) убран целиком, текст пункта на месте',
        !str_contains($out, 'File-List') && !str_contains($out, 'ProgId') && !str_contains($out, '·') && str_contains($out, 'первый пункт'), $out);
    $mixed = $cls::clean('<p class="MsoNormal">из Word</p>' . $owner);
    check('смешанный текст: iframe, script, значок и ссылка владельца целы', str_contains($mixed, '<iframe src="https://www.openstreetmap.org/export/embed.html" width="400"></iframe>')
        && str_contains($mixed, '<script>window.claudeX = 1;</script>') && str_contains($mixed, '<i class="fa fa-phone"></i>')
        && str_contains($mixed, 'target="_blank"') && !str_contains($mixed, 'Mso'), $mixed);
}

// 2. через сайт: сохранение текстового блока — в базе без мусора Word (если очистка включена в конфиге площадки)
$siteConfig = include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php');
if (empty($siteConfig['site']['aggressive_cleanup'])) {
    echo "SKIP через сайт: site.aggressive_cleanup выключена в конфиге площадки\n";
    done('html-cleanup');
}
$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function unstand(): void {
    q("DELETE FROM share_sitemap WHERE smap_segment = 'claude-hc'");
}
unstand();
register_shutdown_function('unstand');
q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num)
   VALUES ('default.layout.xml', 'textblock.content.xml', ?, 'claude-hc', 0, 999)", [$root]);
$id = (int)pdo()->lastInsertId();
foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l) {
    q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l, 'Стенд очистки']);
}
q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
login();
[$c] = http('/claude-hc/single/textBlock_1/save-text', ['data' => $word, 'ID' => $id, 'num' => 1]);
$saved = (string)scalar('SELECT tt.tb_content FROM share_textblocks t JOIN share_textblocks_translation tt USING (tb_id)
    WHERE t.smap_id = ? AND t.tb_num = ? AND tt.lang_id = ?', [$id, '1', (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 1')]);
check('сохранение блока: в базе без мусора Word, текст и ссылка на месте', $c == 200 && $saved !== '' && stripos($saved, 'mso-') === false
    && !str_contains($saved, '<o:') && !str_contains($saved, '<!--') && str_contains($saved, 'Жирный') && str_contains($saved, 'ссылка'),
    "HTTP $c " . substr($saved, 0, 200));
logout();
done('html-cleanup');
