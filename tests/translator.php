<?php
// Переводы одним запросом (надёжность, этап 4): Translator загружает все переводы языка одним запросом и дальше
// отвечает из памяти; неизвестная константа и пустой перевод — имя константы (как прежде); регистр имени не важен;
// другой язык — свой запрос; правка переводов в этом же процессе видна после forget(). Прямых PDO-запросов мимо Db
// в ядре не остаётся (getPDO()->… — только передача соединения LinkChecker).
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\Db;
use Energine\share\gears\Translator;

if (!class_exists(Translator::class)) {
    check('класс Energine\share\gears\Translator есть', false);
    done('translator');
}
$db = new Db(pdo());
$t = new Translator($db);
$ru = (string)scalar("SELECT tr.ltag_value_rtf FROM share_lang_tags l JOIN share_lang_tags_translation tr USING (ltag_id) WHERE l.ltag_name = 'BTN_HISTORY' AND tr.lang_id = 1");
$ua = (string)scalar("SELECT tr.ltag_value_rtf FROM share_lang_tags l JOIN share_lang_tags_translation tr USING (ltag_id) WHERE l.ltag_name = 'BTN_HISTORY' AND tr.lang_id = 2");
$n0 = $db->queryCount();
check('перевод константы — как в базе', $t->translate('BTN_HISTORY', 1) === $ru && $ru !== '', $t->translate('BTN_HISTORY', 1));
foreach (['BTN_RESTORE', 'BTN_VIEW', 'TXT_TEXT_HISTORY', 'FIELD_TBH_DATE', 'BTN_CLOSE', 'TXT_LANG_INACTIVE'] as $c) { $t->translate($c, 1); }
check('семь констант одного языка — один запрос', $db->queryCount() === $n0 + 1, $db->queryCount() - $n0);
check('регистр имени не важен', $t->translate('btn_history', 1) === $ru);
check('неизвестная константа — её имя', $t->translate('NO_SUCH_CONSTANT_CLAUDE', 1) === 'NO_SUCH_CONSTANT_CLAUDE' && $t->translate('', 1) === '');
check('другой язык — свой перевод и ещё один запрос', $t->translate('BTN_HISTORY', 2) === $ua && $ua !== $ru && $db->queryCount() === $n0 + 2, $t->translate('BTN_HISTORY', 2));
// правка переводов в этом же процессе: без forget() — старое из памяти, после — новое (внутри откатываемой транзакции)
pdo()->beginTransaction();
try {
    q("INSERT INTO share_lang_tags (ltag_name) VALUES ('CLAUDE_TRANSLATOR_TEST')");
    $id = (int)pdo()->lastInsertId();
    q('INSERT INTO share_lang_tags_translation (ltag_id, lang_id, ltag_value_rtf) VALUES (?, 1, ?), (?, 2, ?)', [$id, 'Проба', $id, '']);
    check('до forget() — имя (загружено раньше)', $t->translate('CLAUDE_TRANSLATOR_TEST', 1) === 'CLAUDE_TRANSLATOR_TEST');
    $t->forget();
    check('после forget() — новый перевод', $t->translate('CLAUDE_TRANSLATOR_TEST', 1) === 'Проба', $t->translate('CLAUDE_TRANSLATOR_TEST', 1));
    check('пустой перевод — имя константы (как прежде)', $t->translate('CLAUDE_TRANSLATOR_TEST', 2) === 'CLAUDE_TRANSLATOR_TEST', $t->translate('CLAUDE_TRANSLATOR_TEST', 2));
} finally {
    pdo()->rollBack();
}
// в ядре нет прямых запросов мимо Db
$raw = [];
foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator(ROOT . '/core', FilesystemIterator::SKIP_DOTS)) as $f) {
    if (!str_ends_with($f->getPathname(), '.php')) continue;
    foreach (file($f->getPathname()) as $i => $line) {
        if (preg_match('/getPDO\(\)->(prepare|query|exec)\(/', $line)) $raw[] = substr($f->getPathname(), strlen(ROOT) + 1) . ':' . ($i + 1);
    }
}
check('в ядре нет getPDO()->prepare/query/exec мимо Db (счётчик запросов честный)', !$raw, implode(', ', $raw));
done('translator');
