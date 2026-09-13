<?php
/**
 * @file
 * BlogEditor
 *
 * It contains the definition to:
 * @code
class BlogEditor;
@endcode
 *
 * @author sign
 *
 * @version 1.1.0
 */
namespace Energine\blog\components;

use Energine\share\components\Grid;

/**
 * Editor of blogs: name and owner. The owner writes posts on the blogs page.
 *
 * @code
class BlogEditor;
@endcode
 */
class BlogEditor extends Grid {
    /**
     * @copydoc Grid::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('blog_title');
        $this->setTitle($this->translate('TXT_BLOG_EDITOR'));
    }
}
