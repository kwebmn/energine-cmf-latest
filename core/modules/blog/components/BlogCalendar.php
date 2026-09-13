<?php
/**
 * @file
 * BlogCalendar
 *
 * It contains the definition to:
 * @code
class BlogCalendar;
@endcode
 *
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 *
 * @version 1.1.0
 */
namespace Energine\blog\components;

use Energine\calendar\components\Calendar,
    Energine\calendar\gears\CalendarObject,
    Energine\share\gears\SystemException;

/**
 * Calendar of blog posts: days with posts are links to the posts of the day.
 *
 * Posts dated in the future are not marked.
 *
 * @code
class BlogCalendar;
@endcode
 */
class BlogCalendar extends Calendar {
    /**
     * @copydoc Calendar::__construct
     */
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setCalendar(new CalendarObject($this->getParam('month'), $this->getParam('year')));

        $range = $this->calendar->getRange();
        $conditions = [
            'post_created >= ' . $range->start->format('"Y-m-d"') . ' AND post_created < ' . $range->end->format('"Y-m-d"') . ' + INTERVAL 1 DAY',
            'post_created <= NOW()',
        ];
        if ($blogID = (int)$this->getParam('blog_id')) {
            $conditions['blog_id'] = $blogID;
        }
        $existingDates = $this->dbh->getColumn(
            'SELECT DISTINCT DATE_FORMAT(post_created, "%Y-%c-%e") FROM blog_post' . $this->dbh->buildWhereCondition($conditions)
        );
        foreach ((array)$existingDates as $date) {
            if ($item = $this->calendar->getItemByDate(\DateTime::createFromFormat('Y-n-j', $date))) {
                $item->setProperty('selected', 'selected');
            }
        }
        if (($date = $this->getParam('date')) && ($item = $this->calendar->getItemByDate($date))) {
            $item->setProperty('marked', 'marked');
        }
    }

    /**
     * @copydoc Calendar::defineParams
     */
    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            [
                'month' => false,
                'year' => false,
                'date' => false,
                'blog_id' => false,
                // URL of the posts list relative to the site root, the calendar adds year/month/day/
                'template' => '',
            ]
        );
    }

    /**
     * @copydoc Calendar::setParam
     *
     * @throws SystemException 'ERR_404'
     */
    protected function setParam($name, $value) {
        if (($name == 'year') && ($value !== false) && (!is_numeric($value) || ($value < 1970) || ($value > date('Y') + 1))) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        if (($name == 'month') && ($value !== false) && (!is_numeric($value) || ($value < 1) || ($value > 12))) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        parent::setParam($name, $value);
    }
}
