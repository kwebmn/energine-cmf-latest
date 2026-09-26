<?php
// Помощник editors.js: читает, подменяет и возвращает тексты, которые тест меняет через редакторы.
//   php8.5 editors-db.php news-id                 — id первой демо-новости
//   php8.5 editors-db.php news-get ID             — текст новости (русский), JSON-строка
//   php8.5 editors-db.php news-snap ID            — все переводы новости (все языки и поля), JSON
//   php8.5 editors-db.php news-restore ID JSON    — вернуть переводы из news-snap
//   php8.5 editors-db.php news-rtf ID JSON        — анонс и текст новости на всех языках — эта разметка
//   php8.5 editors-db.php tb-home                 — id текстового блока textBlock_1 главной
//   php8.5 editors-db.php tb-get ID               — текстовый блок (русский), JSON-строка
//   php8.5 editors-db.php tb-set ID JSON          — текстовый блок (русский) — эта разметка
//   php8.5 editors-db.php tb-snap ID              — блок на всех языках, JSON
//   php8.5 editors-db.php tb-restore ID JSON      — вернуть блок из tb-snap
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'news-id':
        echo scalar("SELECT MIN(news_id) FROM apps_news WHERE news_segment NOT LIKE 'claude-test%'");
        break;
    case 'news-get':
        echo json_encode(scalar('SELECT news_text_rtf FROM apps_news_translation WHERE news_id = ? AND lang_id = 1', [(int)$argv[2]]), JSON_UNESCAPED_UNICODE);
        break;
    case 'news-snap':
        echo json_encode(q('SELECT * FROM apps_news_translation WHERE news_id = ? ORDER BY lang_id', [(int)$argv[2]])->fetchAll(), JSON_UNESCAPED_UNICODE);
        break;
    case 'news-restore':
        foreach (json_decode($argv[3], true) as $r) {
            q('UPDATE apps_news_translation SET news_title = ?, news_announce_rtf = ?, news_text_rtf = ? WHERE news_id = ? AND lang_id = ?',
                [$r['news_title'], $r['news_announce_rtf'], $r['news_text_rtf'], (int)$argv[2], $r['lang_id']]);
        }
        break;
    case 'news-rtf':
        $html = json_decode($argv[3]);
        q('UPDATE apps_news_translation SET news_announce_rtf = ?, news_text_rtf = ? WHERE news_id = ?', [$html, $html, (int)$argv[2]]);
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
