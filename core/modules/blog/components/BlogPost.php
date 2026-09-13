<?php
/**
 * @file
 * BlogPost
 *
 * It contains the definition to:
 * @code
class BlogPost;
@endcode
 *
 * @author sign
 *
 * @version 1.1.0
 */
namespace Energine\blog\components;

use Energine\share\components\DBDataSet,
    Energine\share\components\DataSet,
    Energine\share\gears\FieldDescription,
    Energine\share\gears\QAL,
    Energine\share\gears\Request,
    Energine\share\gears\SystemException,
    Energine\comments\gears\Comments;

/**
 * Blog posts: the latest posts of all blogs, the posts of one blog, a post, the post form of the blog owner.
 *
 * Posts dated in the future are not shown. Links are built from the URL of the page, its segment is free.
 * Comments of a post are shown by a CommentsForm component bound to this one (state "view").
 *
 * @code
class BlogPost;
@endcode
 */
class BlogPost extends DBDataSet {
    /**
     * Markup allowed in a post written on the site.
     */
    const ALLOWED_TAGS = '<p><br><b><strong><i><em><u><s><ul><ol><li><blockquote><a><img><h2><h3><h4><pre><code><table><thead><tbody><tr><th><td><span><div><hr>';

    /**
     * Calendar of posts.
     * @var BlogCalendar $calendar
     */
    private $calendar;

    /**
     * Parameters of the calendar.
     * @var array $calendarParams
     */
    private $calendarParams = [];

    /**
     * Part of the pager links after the page URL (blog, date).
     * @var string $pagerURL
     */
    private $pagerURL = '';

    /**
     * @copydoc DBDataSet::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('blog_post');
        $this->setOrder(['post_created' => QAL::DESC]);
    }

    /**
     * @copydoc DBDataSet::defineParams
     */
    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'active' => true,
                'showCalendar' => 0,
                'recordsPerPage' => 10,
            ]
        );
    }

    /**
     * URL of the blogs page relative to the site root, without the language segment.
     *
     * @return string
     */
    private function getBlogsURL() {
        return $this->request->getPath(Request::PATH_TEMPLATE, true);
    }

    /**
     * Latest posts of all blogs, by date if the URL has one.
     */
    protected function main() {
        $this->applyListFilters();
        parent::main();
        $this->setProperty('blogs_url', $this->getBlogsURL());
    }

    /**
     * Posts of one blog.
     *
     * @throws SystemException 'ERR_404'
     */
    protected function viewBlog() {
        $blogID = (int)$this->getStateParams(true)['blogID'];
        if (!($blog = $this->getBlog($blogID))) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        $this->addFilterCondition([$this->getTableName() . '.blog_id' => $blogID]);
        $this->applyListFilters("blog/$blogID/");
        $this->prepare();
        $this->setProperty('blogs_url', $this->getBlogsURL());
        $this->setProperty('blog_id', $blogID);
        $this->setProperty('blog_name', $blog['blog_name']);
        $this->setProperty('blog_author', $blog['u_fullname']);
        $this->document->setProperty('title', $blog['blog_name']);
        if ($breadCrumbs = $this->document->componentManager->getBlockByName('breadCrumbs')) {
            $breadCrumbs->addCrumb('', $blog['blog_name']);
        }
    }

    /**
     * Post (its comments come from the bound CommentsForm).
     *
     * @throws SystemException 'ERR_404'
     */
    protected function view() {
        $this->addFilterCondition($this->getTableName() . '.post_created <= NOW()');
        parent::view();
        if ($this->getData()->isEmpty()) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        $this->setProperty('blogs_url', $this->getBlogsURL());
        list($postName) = $this->getData()->getFieldByName('post_name')->getData();
        $this->document->setProperty('title', $postName);
        if ($breadCrumbs = $this->document->componentManager->getBlockByName('breadCrumbs')) {
            $breadCrumbs->addCrumb('', $postName);
        }
    }

    /**
     * Form of a new post in the blog of the current user.
     * (Component::create() is the component factory, hence the name of the state.)
     *
     * @throws SystemException 'ERR_403'
     */
    protected function newPost() {
        if (!$this->getUserBlogID()) {
            throw new SystemException('ERR_403', SystemException::ERR_403);
        }
        $this->setType(self::COMPONENT_TYPE_FORM_ADD);
        $this->setAction('post/save/');
        $this->prepare();
        $this->setProperty('blogs_url', $this->getBlogsURL());
    }

    /**
     * Form of a post for the blog owner or an administrator.
     *
     * @throws SystemException 'ERR_404', 'ERR_403'
     */
    protected function edit() {
        $postID = (int)$this->getStateParams(true)['postID'];
        $this->checkAccess($this->getPostBlogID($postID));
        $this->setType(self::COMPONENT_TYPE_FORM_ALTER);
        $this->addFilterCondition([$this->getTableName() . '.post_id' => $postID]);
        $this->setAction("post/$postID/save/");
        $this->prepare();
        $this->setProperty('blogs_url', $this->getBlogsURL());
    }

    /**
     * Save the post form and go to the post.
     *
     * @throws SystemException 'ERR_404', 'ERR_403', 'ERR_NO_DATA'
     */
    protected function save() {
        if (!isset($_POST[$this->getTableName()]) || !is_array($_POST[$this->getTableName()])) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        $post = $_POST[$this->getTableName()];
        $params = $this->getStateParams(true);

        if (!empty($params['postID'])) {
            $postID = (int)$params['postID'];
            $this->checkAccess($this->getPostBlogID($postID));
        } else {
            $postID = 0;
            if (!($blogID = $this->getUserBlogID())) {
                throw new SystemException('ERR_403', SystemException::ERR_403);
            }
        }

        $data = [
            'post_name' => trim(strip_tags(is_string($post['post_name'] ?? null) ? $post['post_name'] : '')),
            'post_text_rtf' => self::cleanupPostHTML(is_string($post['post_text_rtf'] ?? null) ? $post['post_text_rtf'] : ''),
        ];
        if (($data['post_name'] === '') || (trim(strip_tags($data['post_text_rtf'], '<img>')) === '')) {
            throw new SystemException('ERR_NO_DATA', SystemException::ERR_WARNING);
        }

        if ($postID) {
            $this->dbh->modify(QAL::UPDATE, $this->getTableName(), $data, ['post_id' => $postID]);
        } else {
            $data['blog_id'] = $blogID;
            $data['post_created'] = date('Y-m-d H:i:s');
            $postID = $this->dbh->modify(QAL::INSERT, $this->getTableName(), $data);
        }
        $this->response->redirectToCurrentSection("post/$postID/");
    }

    /**
     * Remove markup that is dangerous in a post written on the site: scripts, event handlers, javascript: links.
     *
     * @param string $html
     * @return string
     */
    public static function cleanupPostHTML($html) {
        $html = preg_replace('~<(script|style|iframe|object|embed)\b[^>]*>.*?</\1\s*>~is', '', $html);
        $html = strip_tags($html, self::ALLOWED_TAGS);
        $html = preg_replace('~\s(?:on\w+|style)\s*=\s*(?:"[^"]*"|\'[^\']*\'|[^\s>]+)~i', '', $html);
        $html = preg_replace('~\s(href|src)\s*=\s*(["\']?)\s*(?:javascript|vbscript|data):[^"\'>\s]*\2~i', ' $1="#"', $html);
        return DataSet::cleanupHTML(trim($html));
    }

    /**
     * Lists: no posts from the future, the date from the URL, parameters of the calendar and the pager.
     *
     * @param string $listURL URL of the list relative to the page
     *
     * @throws SystemException 'ERR_404'
     */
    private function applyListFilters($listURL = '') {
        $this->addFilterCondition($this->getTableName() . '.post_created <= NOW()');
        $params = $this->getStateParams(true);
        // DataSet adds the trailing slash to the template parameter
        $this->calendarParams = ['template' => rtrim($this->getBlogsURL() . $listURL, '/')];
        $date = [];
        foreach (['year' => 'YEAR', 'month' => 'MONTH', 'day' => 'DAY'] as $part => $sqlFunction) {
            if (!isset($params[$part])) {
                break;
            }
            if (!ctype_digit((string)$params[$part])) {
                throw new SystemException('ERR_404', SystemException::ERR_404);
            }
            $date[$part] = (int)$params[$part];
            $this->addFilterCondition(sprintf('%s(%s.post_created) = %d', $sqlFunction, $this->getTableName(), $date[$part]));
        }
        if (isset($date['year'])) {
            $this->calendarParams['year'] = $date['year'];
            if (isset($date['month'])) {
                $this->calendarParams['month'] = $date['month'];
            }
            if (isset($date['day'])) {
                $this->calendarParams['date'] = \DateTime::createFromFormat('!Y-n-j', implode('-', $date));
            }
        }
        if (isset($params['blogID'])) {
            $this->calendarParams['blog_id'] = (int)$params['blogID'];
        }
        $this->pagerURL = $listURL . ($date ? implode('/', $date) . '/' : '');
    }

    /**
     * @copydoc DBDataSet::prepare
     */
    protected function prepare() {
        $user = $this->document->getUser();
        if ($user->isAuthenticated()) {
            $this->setProperty('curr_user_id', $user->getID());
            if ($blogID = $this->getUserBlogID()) {
                $this->setProperty('curr_user_blog_id', $blogID);
            }
        }
        if (in_array('1', $user->getGroups())) {
            $this->setProperty('curr_user_is_admin', '1');
        }
        parent::prepare();

        if ($this->pager && $this->pagerURL) {
            $this->pager->setProperty('additional_url', $this->pagerURL);
        }

        if ($this->getParam('showCalendar') && in_array($this->getState(), ['main', 'viewBlog'])) {
            $this->document->componentManager->addComponent(
                $this->calendar = $this->document->componentManager->createComponent(
                    'blogCalendar', 'Energine\blog\components\BlogCalendar', $this->calendarParams
                )
            );
            $this->calendar->run();
        }
    }

    /**
     * @copydoc DBDataSet::createDataDescription
     */
    protected function createDataDescription() {
        $result = parent::createDataDescription();
        if (in_array($this->getState(), ['newPost', 'edit'])) {
            if ($fd = $result->getFieldDescriptionByName('post_text_rtf')) {
                $fd->setType(FieldDescription::FIELD_TYPE_HTML_BLOCK);
            }
        } elseif ($fd = $result->getFieldDescriptionByName('blog_id')) {
            // the id for the links instead of the list of all blogs
            $fd->setType(FieldDescription::FIELD_TYPE_INT);
        }
        return $result;
    }

    /**
     * @copydoc DBDataSet::loadData
     */
    // blog, author and number of comments of every post
    protected function loadData() {
        $data = parent::loadData();
        if (!is_array($data) || !in_array($this->getState(), ['main', 'viewBlog', 'view'])) {
            return $data;
        }
        $blogs = [];
        foreach ($this->dbh->select(
            'SELECT b.blog_id, b.blog_name, u.u_id, u.u_fullname FROM blog_title b JOIN user_users u ON u.u_id = b.u_id WHERE b.blog_id IN (%s)',
            array_values(array_unique(array_column($data, 'blog_id')))
        ) as $row) {
            $blogs[$row['blog_id']] = $row;
        }
        $comments = ($this->dbh->tableExists($this->getTableName() . '_comment')) ?
            Comments::createInstanceFor($this->getTableName())->getCountByIds(array_column($data, 'post_id')) : [];
        foreach ($data as &$row) {
            $blog = $blogs[$row['blog_id']] ?? ['blog_name' => '', 'u_id' => '', 'u_fullname' => ''];
            $row['blog_name'] = $blog['blog_name'];
            $row['u_id'] = $blog['u_id'];
            $row['u_fullname'] = $blog['u_fullname'];
            $row['comments_num'] = $comments[$row['post_id']] ?? 0;
        }
        return $data;
    }

    /**
     * Blog of the current user.
     *
     * @return int|false
     */
    private function getUserBlogID() {
        $user = $this->document->getUser();
        if (!$user->isAuthenticated()) {
            return false;
        }
        // a user with several blogs writes into the first one
        return (int)$this->dbh->getScalar('blog_title', 'blog_id', ['u_id' => $user->getID()], ['blog_id' => QAL::ASC]) ?: false;
    }

    /**
     * Blog with the name of its owner.
     *
     * @param int $blogID
     * @return array|false
     */
    private function getBlog($blogID) {
        $blog = $this->dbh->select(
            'SELECT b.blog_id, b.blog_name, u.u_id, u.u_fullname FROM blog_title b JOIN user_users u ON u.u_id = b.u_id WHERE b.blog_id = %s',
            $blogID
        );
        return $blog ? $blog[0] : false;
    }

    /**
     * Blog of the post.
     *
     * @param int $postID
     * @return int
     *
     * @throws SystemException 'ERR_404'
     */
    private function getPostBlogID($postID) {
        if (!($blogID = $this->dbh->getScalar($this->getTableName(), 'blog_id', ['post_id' => $postID]))) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        return (int)$blogID;
    }

    /**
     * Posts are changed by the owner of the blog and by administrators.
     *
     * @param int $blogID
     *
     * @throws SystemException 'ERR_403'
     */
    private function checkAccess($blogID) {
        $user = $this->document->getUser();
        if (!$user->isAuthenticated() ||
            (($this->dbh->getScalar('blog_title', 'u_id', ['blog_id' => $blogID]) != $user->getID()) && !in_array('1', $user->getGroups()))
        ) {
            throw new SystemException('ERR_403', SystemException::ERR_403);
        }
    }
}
