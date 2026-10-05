<?php
// Мёртвый код JS/XSLT, удалённый на этапе 2 надёжности, не возвращается: имена ниже не встречаются в core/, site/
// и tests/ (js, xslt, xml, php, css — кроме чужого jodit и собранных стилей). Каждое имя было подтверждено grep-ом
// как неиспользуемое перед удалением (журнал этапа); появление любого из них — либо возврат мёртвого кода, либо новая
// функция, которой нужны свой тест и запись здесь. Тесты проверяются тоже: аудит гридов звал Toolbar.getElement().
$root = dirname(__DIR__);
$dead = [
    'singleMode'               => 'Energine.singleMode — флаг никто не читал (и document.xslt его задавал)',
    'forceJSON'                => 'Energine.forceJSON — всегда false',
    'supportContentEdit'       => 'Energine.supportContentEdit — только объявление',
    'request.request'          => 'Energine.request.request — псевдоним для MooTools',
    'resize: function'         => 'Energine.resize — ресайзер картинок из JS, без вызовов',
    'getMetadata'              => 'Grid.getMetadata — без вызовов',
    'headOff'                  => 'Grid.headOff — скрытый thead прячет разметка (list.xslt)',
    'fitGridHeightToLeftCol'   => 'ветка fitGridHeightToLeftCol — класса нет ни в одной разметке',
    'Toolbar.File'             => 'кнопка-файл панели — ни одного control type="file"',
    'uploadZip'                => 'загрузка zip (JS, PHP, XML) — недоделана и закомментирована',
    'javascript/variable'      => 'переменные JS из конфига компонента — ни одного <variable> в конфигах',
    "createElement('variable')" => 'DataSet::buildJS — ветка переменных',
    "querySelectorAll('.pane')" => 'Form.js — класса .pane нет в разметке',
    'nodeInfo.nodeType'        => 'TreeView.Node из готового li — узлы создаются только из описания',
    'csv('                     => 'Grid.csv — удалено раньше',
    'getElement('              => 'Toolbar/PageList getElement — удалено раньше',
];
$files = [];
foreach (['core', 'site', 'tests'] as $dir) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator("$root/$dir", FilesystemIterator::SKIP_DOTS));
    foreach ($it as $f) {
        $p = $f->getPathname();
        if (!preg_match('/\.(js|xslt|xml|php|css)$/', $p) || str_contains($p, '/scripts/jodit/')
            || preg_match('~/stylesheets/(main|admin)\.css$~', $p) || $p === __FILE__) continue;
        $files[$p] = file_get_contents($p);
    }
}
$fail = 0;
foreach ($dead as $needle => $why) {
    $hits = [];
    foreach ($files as $p => $src) {
        if (str_contains($src, $needle)) $hits[] = substr($p, strlen($root) + 1);
    }
    echo ($hits ? 'FAIL ' : 'OK   ') . "«{$needle}» ({$why})" . ($hits ? ': ' . implode(', ', array_slice($hits, 0, 4)) : '') . PHP_EOL;
    if ($hits) $fail++;
}
echo "== js-dead failures: $fail\n";
exit($fail ? 1 : 0);
