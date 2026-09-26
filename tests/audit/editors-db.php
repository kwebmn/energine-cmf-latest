<?php
// Помощник editors.js: читает и возвращает тексты, которые тест меняет через редакторы.
//   php8.5 editors-db.php news-id                 — id первой демо-новости
//   php8.5 editors-db.php news-get ID             — текст новости (русский), JSON-строка
//   php8.5 editors-db.php news-set ID JSON        — вернуть текст новости
//   php8.5 editors-db.php tb-get ID               — текстовый блок (русский), JSON-строка
//   php8.5 editors-db.php tb-set ID JSON          — вернуть текстовый блок
//   php8.5 editors-db.php tb-home                 — id текстового блока textBlock_1 главной
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'news-id':
        echo scalar("SELECT MIN(news_id) FROM apps_news WHERE news_segment NOT LIKE 'claude-test%'");
        break;
    case 'news-get':
        echo json_encode(scalar('SELECT news_text_rtf FROM apps_news_translation WHERE news_id = ? AND lang_id = 1', [(int)$argv[2]]), JSON_UNESCAPED_UNICODE);
        break;
    case 'news-set':
        q('UPDATE apps_news_translation SET news_text_rtf = ? WHERE news_id = ? AND lang_id = 1', [json_decode($argv[3]), (int)$argv[2]]);
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
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
