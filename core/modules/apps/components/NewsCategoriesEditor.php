<?php
/**
 * @file
 * News categories editor.
 *
 * It contains the definition to:
 * @code
class NewsCategoriesEditor;
@endcode
 */

namespace Energine\apps\components;

use Energine\share\components\Grid;

/**
 * Sections that hold news.
 *
 * A shortcut for editors: the site structure editor shows every page of the site,
 * while news are usually kept in one or two sections whose names and descriptions
 * are edited far more often than the tree itself.
 *
 * Only sections that already contain news are listed; creating and deleting
 * sections stays the job of the structure editor.
 *
 * @code
class NewsCategoriesEditor;
@endcode
 */
class NewsCategoriesEditor extends Grid {

    public function __construct($name, ?array $params = NULL) {
        parent::__construct($name, $params);
        $this->setTableName('share_sitemap');

        $ids = $this->dbh->getColumn('SELECT DISTINCT smap_id FROM apps_news');
        // Грид джойнит таблицу переводов, где тоже есть smap_id, поэтому колонку
        // указываем с именем таблицы. Пустой список означал бы «без фильтра»,
        // подставляем заведомо несуществующий идентификатор.
        $this->setFilter(['share_sitemap.smap_id' => $ids ?: [0]]);
    }
}
