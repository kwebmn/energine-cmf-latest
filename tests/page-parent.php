<?php
// Цикл в дереве страниц (надёжность 6, находка сравнения с xSight): сохранение страницы отказывает
// (ERR_DIV_PARENT_LOOP), если новый родитель — сама страница или её потомок любой глубины. Раньше защита была только
// в окне выбора родителя: страница-родитель самой себе роняла загрузку дерева на каждом запросе (весь сайт), цикл
// длиннее молча прятал поддерево. Перенос в другой раздел и новая страница — как прежде.
// Стенд: claude-pp → claude-pp/a → claude-pp/a/b и claude-pp2; удаляется в конце (петля сначала разрывается).
// Случай «родитель — сама страница» проверяется, только если отказ для внука уже работает: без защиты такая запись
// уронила бы живой сайт.
require __DIR__ . '/testlib.php';

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
$loopText = (string)translation('ERR_DIV_PARENT_LOOP');
$pidOf = fn(int $id) => (int)scalar('SELECT smap_pid FROM share_sitemap WHERE smap_id = ?', [$id]);
// отказ сохранения: страница не сохранена, в ответе текст константы
$refused = function (?int $saved) use ($loopText): bool {
    $json = json_encode($GLOBALS['lastSave']['json'] ?? null, JSON_UNESCAPED_UNICODE);
    return $saved === null && $loopText !== '' && $loopText !== 'ERR_DIV_PARENT_LOOP' && str_contains((string)$json, $loopText);
};

try {
    login();
    $pp = savePage(null, $ROOT, 'claude-pp');
    $a = $pp ? savePage(null, $pp, 'a') : null;
    $b = $a ? savePage(null, $a, 'b') : null;
    $pp2 = savePage(null, $ROOT, 'claude-pp2');
    if (!check('стенд: claude-pp → a → b и claude-pp2', $pp && $a && $b && $pp2)) {
        throw new RuntimeException('стенд не создан');
    }

    // 1. родитель — внук: отказ, база прежняя (без защиты — петля pp → a → b → pp, стенд пропал бы из дерева)
    ob_start();
    $r = savePage($pp, $b, 'claude-pp');
    ob_end_clean();
    $grand = $refused($r) && $pidOf($pp) === $ROOT;
    check('родитель — внук страницы: отказ с текстом ERR_DIV_PARENT_LOOP, родитель прежний', $grand,
        'родитель сейчас: ' . $pidOf($pp) . ' | ' . json_encode($GLOBALS['lastSave']['json'] ?? null, JSON_UNESCAPED_UNICODE));
    if ($pidOf($pp) !== $ROOT) {
        q('UPDATE share_sitemap SET smap_pid = ? WHERE smap_id = ?', [$ROOT, $pp]); // разорвать петлю сразу
    }

    // 2. родитель — сама страница: только при работающей защите (иначе запись уронила бы сайт)
    if ($grand) {
        ob_start();
        $r = savePage($pp, $pp, 'claude-pp');
        ob_end_clean();
        check('родитель — сама страница: отказ, родитель прежний', $refused($r) && $pidOf($pp) === $ROOT, 'родитель сейчас: ' . $pidOf($pp));
        if ($pidOf($pp) !== $ROOT) {
            q('UPDATE share_sitemap SET smap_pid = ? WHERE smap_id = ?', [$ROOT, $pp]);
        }
    } else {
        check('родитель — сама страница: отказ (не проверено: без защиты от цикла запись уронила бы сайт)', false);
    }

    // 3. перенос в другой раздел и новая страница в глубине — как прежде
    $moved = savePage($a, $pp2, 'a');
    check('перенос подраздела в другой раздел сохраняется', $moved === $a && $pidOf($a) === $pp2, 'родитель a: ' . $pidOf($a));
    $c = savePage(null, $b, 'c');
    check('новая страница в глубине раздела сохраняется', $c !== null && $pidOf($c) === $b);
    logout();
    [$code] = http('/');
    check('главная после всех попыток отвечает 200', $code == 200, "HTTP $code");
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    // 4. по коду — по HTTP не наблюдаемо без сбоя базы посреди записи: сохранение страницы — транзакция с откатом при
    //    ошибке (иначе открытая транзакция до конца запроса), обмен номерами порядка — в одной транзакции
    $src = (string)file_get_contents(ROOT . '/core/modules/share/components/DivisionEditor.php');
    preg_match('~protected function save\(\).*?\n    }~s', $src, $save);
    preg_match('~protected function changeOrder\(.*?\n    }~s', $src, $swap);
    check('по коду: сохранение страницы — транзакция с откатом при ошибке', isset($save[0]) && str_contains($save[0], '->rollback()')
        && str_contains($save[0], 'catch (\\Throwable'));
    check('по коду: смена порядка — оба обновления в одной транзакции', isset($swap[0]) && str_contains($swap[0], '->transaction('));
    // петля (если осталась) — разорвать до удаления: каскад по кругу
    q("UPDATE share_sitemap SET smap_pid = ? WHERE smap_pid IS NOT NULL AND smap_segment IN ('claude-pp', 'claude-pp2')", [$ROOT]);
    q("DELETE FROM share_sitemap WHERE smap_pid = ? AND smap_segment IN ('claude-pp', 'claude-pp2')", [$ROOT]);
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('page-parent');
