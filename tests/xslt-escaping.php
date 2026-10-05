<?php
// Экранирование в шаблонах XSLT (UI-подпроект 4):
//  1. каждое disable-output-escaping в шаблонах помечено комментарием «d-o-e: причина» строкой выше — разметка там
//     по замыслу (текст блока, описание раздела, константы с разметкой); новое без пометки — провал;
//  2. разметка в подписи поля, заголовке поля «только чтение», заголовке страницы, названии родительского раздела,
//     подписи и сегменте в форме раздела выводится текстом;
//  3. перевод с апострофом и </script> в форме раздела не попадает в код скрипта и не ломает его.
// XML страниц — с площадки (?debug, site.debug включён), разметка подставляется в документ здесь.
require __DIR__ . '/testlib.php';

// 1. пометки
$files = array_merge(glob(ROOT . '/core/modules/*/transformers/*.xslt'), glob(ROOT . '/site/modules/*/transformers/*.xslt'));
$bad = [];
foreach ($files as $f) {
    $lines = file($f);
    foreach ($lines as $i => $l) {
        if (!str_contains($l, 'disable-output-escaping')) continue;
        if (!($i > 0 && str_contains($lines[$i - 1], 'd-o-e:')) && !str_contains($l, 'd-o-e:')) $bad[] = str_replace(ROOT . '/', '', $f) . ':' . ($i + 1);
    }
}
check('disable-output-escaping только с пометкой «d-o-e: причина»', !$bad, implode(' ', $bad));

function render(DOMDocument $d): string {
    $x = new DOMDocument('1.0', 'UTF-8');
    $x->load(ROOT . '/site/modules/main/transformers/main.xslt');
    $p = new XSLTProcessor();
    $p->importStylesheet($x);
    return (string)$p->transformToXml($d);
}
function page(string $url): DOMDocument {
    [$code, $body] = http($url . '?debug');
    $d = new DOMDocument('1.0', 'UTF-8');
    if ($code != 200 || !@$d->loadXML($body)) { check("XML страницы $url", false, $code); done('escaping'); }
    return $d;
}
const RAW = '~<b>t\d</b>~';
// текстом: в выводе есть «&lt;b&gt;tN», нет «<b>tN»
function asText(string $html, string $n): bool { return str_contains($html, "&lt;b&gt;t$n") && !str_contains($html, "<b>t$n</b>"); }

login();
$user = (int)scalar('SELECT u_id FROM user_users ORDER BY u_id LIMIT 1');
$d = page("/admin/users/single/userEditor/$user/edit/");
$xp = new DOMXPath($d);
$fields = $xp->query('//component[@type="form"]//field[@type="string" or @type="email"]');
$fields->item(0)->setAttribute('title', '<b>t1</b>');
$ro = $fields->item(1);
$ro->setAttribute('mode', '1');
$ro->setAttribute('title', '<b>t2</b>');
$ro->nodeValue = '<b>t8</b>';
$html = render($d);
check('подпись поля формы — текстом', asText($html, '1'));
check('подпись и значение поля «только чтение» — текстом', asText($html, '2') && asText($html, '8'));

$d = page('/info/quick-start/');
(new DOMXPath($d))->query('//properties/property[@name="title"]')->item(0)->nodeValue = '<b>t3</b>';
check('заголовок страницы (h1) — текстом', asText(render($d), '3'));

$page = (int)scalar("SELECT q.smap_id FROM share_sitemap q JOIN share_sitemap i ON i.smap_id = q.smap_pid
    WHERE q.smap_segment = 'quick-start' AND i.smap_segment = 'info'");
$d = page("/admin/structure/single/divEditor/$page/edit/");
$xp = new DOMXPath($d);
$pid = $xp->query('//field[@name="smap_pid"]')->item(0);
$pid->setAttribute('data_name', '<b>t4</b>');
$pid->setAttribute('title', '<b>t6</b>');
$seg = $xp->query('//field[@name="smap_segment"]')->item(0);
$seg->setAttribute('mode', '1');
$seg->nodeValue = '<b>t5</b>';
$tr = $xp->query('//translation[@const="ERR_NO_DIV_NAME"]')->item(0);
$tr->nodeValue = "a'b</script><b>t7</b>";
$html = render($d);
check('форма раздела: родительский раздел, подпись, сегмент — текстом', asText($html, '4') && asText($html, '6') && asText($html, '5'));
$scripts = '';
if (preg_match_all('~<script\b[^>]*>(.*?)</script>~s', $html, $m)) $scripts = implode("\n", $m[1]);
check('форма раздела: перевод с апострофом и </script> не попадает в код скрипта', !str_contains($scripts, "a'b") && !str_contains($html, '<b>t7</b>')
    && str_contains($html, '&lt;/script&gt;&lt;b&gt;t7'), substr($scripts, 0, 300));
logout();
done('escaping');
