<?php
/**
 * @file
 * BlogPostEditor
 *
 * It contains the definition to:
 * @code
class BlogPostEditor;
@endcode
 *
 * @author sign
 *
 * @version 1.1.0
 */
namespace Energine\blog\components;

use Energine\share\components\Grid,
    Energine\share\gears\QAL;

/**
 * Editor of blog posts for administrators.
 *
 * @code
class BlogPostEditor;
@endcode
 */
class BlogPostEditor extends Grid {
    /**
     * @copydoc Grid::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('blog_post');
        $this->setOrder(['post_created' => QAL::DESC]);
        $this->setTitle($this->translate('TXT_BLOG_POST_EDITOR'));
    }

    /**
     * @copydoc Grid::add
     */
    // a new post is dated now
    protected function add() {
        parent::add();
        if ($f = $this->getData()->getFieldByName('post_created')) {
            $f->setData(date('Y-m-d H:i:s'), true);
        }
    }
}
