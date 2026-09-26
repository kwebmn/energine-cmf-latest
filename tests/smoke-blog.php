<?php
// Blog module end-to-end: admin editors, public lists/post/calendar/pager, post form of the blog owner, comments.
// Test data: user claude-blog@loki.kweb.biz and blogs "claude-test ..." (removed at the end).
require __DIR__ . '/testlib.php';
date_default_timezone_set('Europe/Kyiv');

const USER = 'claude-blog@loki.kweb.biz';
const PASSWORD = 'claude-test-password';
$useJar = function ($name) { $GLOBALS['jar'] = __DIR__ . "/cookies-blog-$name.txt"; };
$B = '/admin/blogs/single/blogEditor/';
$P = '/admin/blogs/posts/single/blogPostEditor/';

$cleanup = function () {
    q("DELETE FROM blog_title WHERE blog_name LIKE 'claude-test%'");
    q('DELETE FROM user_users WHERE u_name = ?', [USER]);
};
$cleanup();
q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)', [USER, password_hash(PASSWORD, PASSWORD_DEFAULT), 'Автор Блога']);
$uid = (int)pdo()->lastInsertId();
q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, 4)', [$uid]);

try {
    // ------------------------------------------------------------------ admin: blogs and posts
    $useJar('admin');
    login();
    [$c, $html] = http($B . 'add/');
    check('blog add form', $c == 200 && clean($html) && str_contains($html, 'name="blog_title[u_id]"'), $html);
    [$c, $j, $raw] = json($B . 'save', formData($html, ['blog_title[blog_name]' => 'claude-test Блог автора', 'blog_title[u_id]' => (string)$uid]));
    $blogId = (int)($j['data'] ?? 0);
    check("blog saved ($blogId)", !empty($j['result']) && $blogId, $raw);
    [$c, $html] = http($B . 'add/');
    [$c, $j, $raw] = json($B . 'save', formData($html, ['blog_title[blog_name]' => 'claude-test Блог администратора', 'blog_title[u_id]' => '22']));
    $adminBlogId = (int)($j['data'] ?? 0);
    check("second blog saved ($adminBlogId)", !empty($j['result']) && $adminBlogId, $raw);
    [$c, $j, $raw] = json($B . 'get-data/');
    check('blogs grid', count(array_filter($j['data'] ?? [], fn($r) => str_starts_with($r['blog_name'], 'claude-test'))) == 2, $raw);

    [$c, $html] = http($P . 'add/');
    check('post add form: date prefilled', $c == 200 && clean($html) && preg_match('~<input[^>]*(name="blog_post\[post_created\]"[^>]*value="' . date('Y-m-d') . '|value="' . date('Y-m-d') . '[^"]*"[^>]*name="blog_post\[post_created\]")~', $html), $html);
    [$c, $j, $raw] = json($P . 'save', formData($html, ['blog_post[blog_id]' => (string)$adminBlogId, 'blog_post[post_created]' => $adminPostDate = date('Y-m-d H:i:s', max(strtotime('today'), time() - 3600)),
        'blog_post[post_name]' => 'claude-test запись администратора', 'blog_post[post_text_rtf]' => '<p>Текст записи администратора</p>']));
    $adminPostId = (int)($j['data'] ?? 0);
    check("post saved in the admin ($adminPostId)", !empty($j['result']) && $adminPostId, $raw);
    [$c, $html] = http($P . "$adminPostId/edit/");
    [$c, $j, $raw] = json($P . 'save', formData($html, ['blog_post[post_name]' => 'claude-test запись администратора (ред.)']));
    check('post edited in the admin', !empty($j['result']) && scalar('SELECT post_name FROM blog_post WHERE post_id = ?', [$adminPostId]) === 'claude-test запись администратора (ред.)', $raw);
    $future = date('Y-m-d H:i:s', time() + 86400 * 3);
    q('INSERT INTO blog_post (blog_id, post_created, post_name, post_text_rtf) VALUES (?, ?, ?, ?)', [$adminBlogId, $future, 'claude-test запись из будущего', '<p>future</p>']);
    $futurePostId = (int)pdo()->lastInsertId();

    // ------------------------------------------------------------------ guest: lists, post, calendar, pager
    $useJar('guest');
    @unlink($GLOBALS['jar']);
    [$c, $html] = http('/blogs/');
    check('blogs page lists the post', $c == 200 && clean($html) && str_contains($html, 'claude-test запись администратора (ред.)')
        && str_contains($html, 'claude-test Блог администратора') && str_contains($html, 'Admin'), $html);
    check('future post hidden', !str_contains($html, 'claude-test запись из будущего'), $html);
    check('no "new post" link for guests', !str_contains($html, 'post/create/'), $html);
    $day = date('Y/n/j', strtotime($adminPostDate));
    check('calendar with a link to the day of the post', str_contains($html, 'class="calendar"') && str_contains($html, 'href="' . BASE . '/blogs/' . $day . '/"'), $html);
    [$c, $html] = http('/blogs/' . $day . '/');
    check('posts of the day', $c == 200 && clean($html) && str_contains($html, 'claude-test запись администратора'), $html);
    [$c, $html] = http('/blogs/2001/1/');
    check('empty month', $c == 200 && clean($html) && str_contains($html, 'Записей пока нет'), $html);
    [$c] = http('/blogs/abc/');
    check("bad date is 404 ($c)", $c == 404);
    [$c, $html] = http("/blogs/blog/$adminBlogId/");
    check('posts of a blog', $c == 200 && clean($html) && str_contains($html, '<title>claude-test Блог администратора') && str_contains($html, 'claude-test запись администратора'), $html);
    [$c, $html] = http("/blogs/post/$adminPostId/");
    check('post page', $c == 200 && clean($html) && str_contains($html, 'Текст записи администратора') && !str_contains($html, '/edit/"'), $html);
    [$c] = http("/blogs/post/$futurePostId/");
    check("future post is 404 ($c)", $c == 404);
    [$c] = http("/blogs/post/$adminPostId/edit/");
    check("guest cannot edit ($c)", $c == 403);
    [$c] = http('/ua/blogs/');
    check("ukrainian version ($c)", $c == 200);

    $values = [];
    for ($i = 1; $i <= 11; $i++) {
        $values[] = sprintf("(%d, NOW() - INTERVAL %d MINUTE, 'claude-test пейджер %02d', '<p>page</p>')", $adminBlogId, 120 + $i, $i);
    }
    q('INSERT INTO blog_post (blog_id, post_created, post_name, post_text_rtf) VALUES ' . implode(',', $values));
    [$c, $html] = http("/blogs/blog/$adminBlogId/");
    check('pager on the blog list', str_contains($html, 'href="' . BASE . "/blogs/blog/$adminBlogId/page-2/\"") && !str_contains($html, 'claude-test пейджер 11'), $html);
    [$c, $html] = http("/blogs/blog/$adminBlogId/page-2/");
    check('second page', $c == 200 && clean($html) && str_contains($html, 'claude-test пейджер 11'), $html);
    q("DELETE FROM blog_post WHERE post_name LIKE 'claude-test пейджер%'");

    // ------------------------------------------------------------------ blog owner: new post, edit, access, comments
    $useJar('user');
    @unlink($GLOBALS['jar']);
    http('/login/');
    http('/auth.php', ['user' => ['login' => 1, 'username' => USER, 'password' => PASSWORD]], [], BASE . '/login/');
    [$c, $html] = http('/blogs/');
    check('"new post" link for the blog owner', $c == 200 && str_contains($html, 'href="' . BASE . '/blogs/post/create/"'), $html);
    [$c, $html] = http('/blogs/post/create/');
    check('post form', $c == 200 && clean($html) && str_contains($html, 'name="blog_post[post_name]"') && str_contains($html, 'class="richEditor"') && str_contains($html, 'BlogForm'), $html);
    $form = formData($html, ['blog_post[post_name]' => 'claude-test запись автора <b>',
        'blog_post[post_text_rtf]' => '<p onclick="alert(1)">Текст <strong>автора</strong></p><script>alert(2)</script><a href="javascript:alert(3)">ссылка</a>']);
    [$c, $body] = http('/blogs/post/save/', $form);
    $postId = (int)scalar("SELECT post_id FROM blog_post WHERE blog_id = ? AND post_name LIKE 'claude-test запись автора%'", [$blogId]);
    check("post saved by the owner ($postId, HTTP $c)", $postId && $c == 302, $body);
    $text = (string)scalar('SELECT post_text_rtf FROM blog_post WHERE post_id = ?', [$postId]);
    check('post HTML cleaned: ' . $text, str_contains($text, '<strong>автора</strong>') && !preg_match('~onclick|<script|javascript:~i', $text)
        && scalar('SELECT post_name FROM blog_post WHERE post_id = ?', [$postId]) === 'claude-test запись автора');
    [$c, $html] = http("/blogs/post/$postId/");
    check('own post with edit link', $c == 200 && clean($html) && str_contains($html, "blogs/post/$postId/edit/"), $html);
    [$c, $html] = http("/blogs/post/$postId/edit/");
    check('edit form of own post', $c == 200 && clean($html) && str_contains($html, 'claude-test запись автора'), $html);
    [$c, $body] = http("/blogs/post/$postId/save/", formData($html, ['blog_post[post_name]' => 'claude-test запись автора (ред.)']));
    check("own post edited (HTTP $c)", $c == 302 && scalar('SELECT post_name FROM blog_post WHERE post_id = ?', [$postId]) === 'claude-test запись автора (ред.)', $body);
    [$c] = http("/blogs/post/$adminPostId/edit/");
    check("someone else's post cannot be edited ($c)", $c == 403);
    [$c] = http("/blogs/post/$adminPostId/save/", ['blog_post' => ['post_name' => 'hacked', 'post_text_rtf' => 'hacked']]);
    check("someone else's post cannot be saved ($c)", $c == 403 && scalar('SELECT post_name FROM blog_post WHERE post_id = ?', [$adminPostId]) !== 'hacked');

    [$c, $html] = http("/blogs/post/$adminPostId/");
    check('comment form under the post', $c == 200 && str_contains($html, 'save-comment') || str_contains($html, 'name="comment_name"'), $html);
    $single = singleTemplate($html, 'commentsForm');
    [$c, $j, $raw] = json(($single ?: BASE . '/blogs/single/commentsForm/') . 'save-comment/', http_build_query(['target_id' => $adminPostId, 'comment_name' => 'claude-test комментарий']));
    check('comment saved', !empty($j['result']) && scalar('SELECT COUNT(*) FROM blog_post_comment WHERE target_id = ? AND u_id = ?', [$adminPostId, $uid]) == 1, $raw);
    [$c, $html] = http("/blogs/post/$adminPostId/");
    check('comment shown under the post', str_contains($html, 'claude-test комментарий'), $html);
    [$c, $html] = http('/blogs/');
    check('comment count in the list', (bool)preg_match('~post/' . $adminPostId . '/#comments">[^<]*: 1</a>~', $html), $html);

    // ------------------------------------------------------------------ admin: any post, comments editor
    $useJar('admin');
    [$c, $html] = http("/blogs/post/$postId/");
    check("admin sees edit link on any post", str_contains($html, "blogs/post/$postId/edit/"), $html);
    [$c, $j, $raw] = json('/admin/blogs/comments/single/commentsEdit/get-data/');
    check('comment in the comments editor', in_array('claude-test комментарий', array_column($j['data'] ?? [], 'comment_name')), $raw);
    [$c, $j, $raw] = json($P . 'get-data/');
    check('posts grid', count(array_filter($j['data'] ?? [], fn($r) => str_starts_with($r['post_name'], 'claude-test'))) >= 3, $raw);
    [$c, $j, $raw] = json($B . "$adminBlogId/delete/");
    check('blog deleted with posts and comments', !empty($j['result']) && !scalar('SELECT COUNT(*) FROM blog_post WHERE blog_id = ?', [$adminBlogId])
        && !scalar('SELECT COUNT(*) FROM blog_post_comment WHERE target_id = ?', [$adminPostId]), $raw);
} finally {
    $cleanup();
    foreach (glob(__DIR__ . '/cookies-blog-*.txt') as $f) unlink($f);
}
done('blog');
