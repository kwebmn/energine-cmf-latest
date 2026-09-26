<?php
// Anonymous comments on a news page (they needed the captcha before): markup stripped, nick required, shown on the page.
require __DIR__ . '/testlib.php';

const NEWS_URL = '/news/1--dobro-pozhalovaty/';
$cleanup = fn() => q("DELETE FROM apps_news_comment WHERE comment_nick LIKE 'claude-test%' OR comment_name LIKE 'claude-test%'");
$cleanup();
$GLOBALS['jar'] = __DIR__ . '/cookies-comments.txt';
@unlink($GLOBALS['jar']);
try {
    [$c, $html] = http(NEWS_URL);
    $single = singleTemplate($html, 'commentsForm');
    check('news page with the comment form, no captcha', $c == 200 && clean($html) && $single && str_contains($html, 'name="comment_nick"')
        && stripos($html, 'captcha') === false, $html);
    $newsId = (int)scalar("SELECT news_id FROM apps_news WHERE news_segment = 'dobro-pozhalovaty'");

    [$c, $j, $raw] = json($single . 'save-comment/', http_build_query(['target_id' => $newsId, 'comment_name' => 'claude-test без ника']));
    // сообщение приходит переведённым, поэтому сверяем со справочником, а не с именем константы
    $nickErr = translation('TXT_COMMENT_NICK_IS_REQUIRED');
    check('nick is required for guests', empty($j['result']) && $nickErr && str_contains($raw, json_encode($nickErr, JSON_UNESCAPED_SLASHES))
        && !scalar("SELECT COUNT(*) FROM apps_news_comment WHERE comment_name LIKE 'claude-test%'"), $raw);

    [$c, $j, $raw] = json($single . 'save-comment/', http_build_query(['target_id' => $newsId, 'comment_nick' => 'claude-test <i>гость</i>',
        'comment_name' => 'claude-test <b>анонимный</b> комментарий <script>alert(1)</script>']));
    $row = q("SELECT * FROM apps_news_comment WHERE comment_nick LIKE 'claude-test%'")->fetch();
    check('anonymous comment saved', !empty($j['result']) && $row, $raw);
    // premoderated=1 (the default of the news page) is written into comment_approved as is
    check('markup stripped, no user', $row && $row['comment_nick'] === 'claude-test гость'
        && $row['comment_name'] === 'claude-test анонимный комментарий alert(1)' && $row['u_id'] === null, json_encode($row, JSON_UNESCAPED_UNICODE));
    [$c, $html] = http(NEWS_URL);
    check('comment shown on the news page without markup', $c == 200 && clean($html) && str_contains($html, 'claude-test анонимный комментарий alert(1)')
        && !str_contains($html, '<script>alert(1)'), $html);

    login();
    [$c, $j, $raw] = json('/admin/comments-editor/single/commentsEdit/get-data/');
    check('comment in the comments editor', $c == 200 && str_contains($raw, 'claude-test'), $raw);
} finally {
    $cleanup();
    @unlink($GLOBALS['jar']);
}
done('comments');
