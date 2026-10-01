<?php
// Помощник editors.js: читает, подменяет и возвращает тексты, которые тест меняет через редакторы.
//   php8.5 editors-db.php page-id                 — id раздела демо features/content
//   php8.5 editors-db.php page-get ID             — описание раздела (русское), JSON-строка
//   php8.5 editors-db.php page-snap ID            — все переводы раздела (все языки и поля), JSON
//   php8.5 editors-db.php page-restore ID JSON    — вернуть переводы из page-snap
//   php8.5 editors-db.php page-rtf ID JSON        — описание раздела на всех языках — эта разметка
//   php8.5 editors-db.php tb-home                 — id текстового блока textBlock_1 главной
//   php8.5 editors-db.php tb-get ID               — текстовый блок (русский), JSON-строка
//   php8.5 editors-db.php tb-set ID JSON          — текстовый блок (русский) — эта разметка
//   php8.5 editors-db.php tb-snap ID              — блок на всех языках, JSON
//   php8.5 editors-db.php tb-restore ID JSON      — вернуть блок из tb-snap
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'page-id':
        echo scalar("SELECT c.smap_id FROM share_sitemap c JOIN share_sitemap f ON f.smap_id = c.smap_pid
            WHERE c.smap_segment = 'content' AND f.smap_segment = 'features'
            AND f.smap_pid = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL)");
        break;
    case 'page-get':
        echo json_encode(scalar('SELECT smap_description_rtf FROM share_sitemap_translation WHERE smap_id = ? AND lang_id = 1', [(int)$argv[2]]), JSON_UNESCAPED_UNICODE);
        break;
    case 'page-snap':
        echo json_encode(q('SELECT * FROM share_sitemap_translation WHERE smap_id = ? ORDER BY lang_id', [(int)$argv[2]])->fetchAll(), JSON_UNESCAPED_UNICODE);
        break;
    case 'page-restore':
        foreach (json_decode($argv[3], true) as $r) {
            q('UPDATE share_sitemap_translation SET smap_name = ?, smap_title = ?, smap_description_rtf = ?, smap_html_title = ?,
                smap_meta_keywords = ?, smap_meta_description = ?, smap_is_disabled = ? WHERE smap_id = ? AND lang_id = ?',
                [$r['smap_name'], $r['smap_title'], $r['smap_description_rtf'], $r['smap_html_title'], $r['smap_meta_keywords'],
                    $r['smap_meta_description'], $r['smap_is_disabled'], (int)$argv[2], $r['lang_id']]);
        }
        break;
    case 'page-rtf':
        q('UPDATE share_sitemap_translation SET smap_description_rtf = ? WHERE smap_id = ?', [json_decode($argv[3]), (int)$argv[2]]);
        break;
    case 'tb-home':
        echo scalar("SELECT tb_id FROM share_textblocks WHERE smap_id = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL) AND tb_num = '1'");
        break;
    case 'tb-get':
        echo json_encode(scalar('SELECT tb_content FROM share_textblocks_translation WHERE tb_id = ? AND lang_id = 1', [(int)$argv[2]]), JSON_UNESCAPED_UNICODE);
        break;
    case 'tb-set':
        q('UPDATE share_textblocks_translation SET tb_content = ? WHERE tb_id = ? AND lang_id = 1', [json_decode($argv[3]), (int)$argv[2]]);
        break;
    case 'tb-snap':
        echo json_encode(q('SELECT lang_id, tb_content FROM share_textblocks_translation WHERE tb_id = ? ORDER BY lang_id', [(int)$argv[2]])->fetchAll(), JSON_UNESCAPED_UNICODE);
        break;
    case 'tb-restore':
        // блок мог быть удалён сохранением пустого текста: строки возвращаются заново
        q('INSERT IGNORE INTO share_textblocks (tb_id, smap_id, tb_num) SELECT ?, smap_id, ? FROM share_sitemap WHERE smap_pid IS NULL',
            [(int)$argv[2], '1']);
        q('DELETE FROM share_textblocks_translation WHERE tb_id = ?', [(int)$argv[2]]);
        foreach (json_decode($argv[3], true) as $r) {
            q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [(int)$argv[2], $r['lang_id'], $r['tb_content']]);
        }
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
