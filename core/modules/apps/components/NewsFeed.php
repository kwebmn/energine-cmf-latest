<?php
/**
 * @file
 * NewsFeed
 *
 * It contains the definition to:
 * @code
class NewsFeed;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2007
 *
 * @version 1.0.0
 */
namespace Energine\apps\components;
use Energine\share\gears\QAL, Energine\share\gears\SystemException, Energine\share\gears\AttachmentManager, Energine\share\gears\FieldDescription, Energine\share\gears\SimpleBuilder, Energine\share\gears\Data;
/**
 * News line.
 *
 * @code
class NewsFeed;
 * @endcode
 */
class NewsFeed extends ExtendedFeed {
    /**
     * @copydoc ExtendedFeed::__construct
     */
    // Жестко привязываемя к таблице новостей
    public function __construct($name,  ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName('apps_news');
        $this->setOrder(array('news_date' => QAL::DESC));
        if ($this->document->getRights() < ACCESS_EDIT) {
            $this->addFilterCondition(array('news_is_active' => true));
        }
    }

    /**
     * @copydoc \Energine\apps\components\ExtendedFeed::createBuilder
     */
    protected function createBuilder() {
        return new SimpleBuilder();
    }

    /**
     * @copydoc ExtendedFeed::createData
     */
    // Все новости которые имеют будущую дату выводятся только админам
    protected function createData() {
        if ($this->document->getRights() < ACCESS_EDIT) {
            $this->addFilterCondition(
                'news_date <= NOW()'
            );
        }

        $res = parent::createData();
        return $res;
    }

    /**
     * @copydoc ExtendedFeed::main
     */
    /*
     * Перед вызовом родителя добавляем ограничения
     * После вызова - добавляем в пейджер
     */
    protected function main() {
        $ap = $this->getStateParams(true);

        foreach ($dateArr = array(
            'year' => 'YEAR(%s)',
            'month' => 'MONTH(%s)',
            'day' => 'DAY(%s)'
        ) as $parameterName => $SQLFuncName) {
            if (isset($ap[$parameterName])) {
                $this->addFilterCondition(
                    array(
                        sprintf($SQLFuncName, 'news_date') => $ap[$parameterName]
                    )
                );
            }
        }
        parent::main();
        if ($this->pager) {
            $additionalURL = array();
            foreach (array_keys($dateArr) as $parameterName) {
                if (isset($ap[$parameterName])) {
                    array_push($additionalURL, $ap[$parameterName]);
                } else {
                    break;
                }
            }
            if ($additionalURL) {
                unset($ap['pageNumber']);
                $pageTitle = $this->translate('TXT_NEWS_BY_DATE') . ': ' . implode('/', array_reverse($ap));
                $breadCrumbs = E()->getDocument()->componentManager->getBlockByName('breadCrumbs');
                if ($breadCrumbs) {
                    $breadCrumbs->addCrumb(null, $pageTitle);
                }
                E()->getDocument()->setProperty('title', $pageTitle);
                $additionalURL = implode('/', $additionalURL) . '/';
                $this->pager->setProperty('additional_url', $additionalURL);
            }
        }
    }


    /**
     * @copydoc ExtendedFeed::view
     *
     * @throws SystemException 'ERR_404'
     */
    // Переписан под специфический сегмент УРЛ
    protected function view() {
        $ap = $this->getStateParams(true);

        $this->addFilterCondition(
            array(
                $this->getTableName() . '.' . $this->getPK() => $ap['id'],
                'news_segment' => $ap['segment'],
            )
        );
        $this->setType(self::COMPONENT_TYPE_FORM);
        $this->setDataDescription($this->createDataDescription());
        $this->setBuilder($this->createBuilder());
        $this->createPager();
        $this->setData($this->createData());
        if (!$this->getData()->isEmpty()) {
            list($newsTitle) = $this->getData()->getFieldByName('news_title')->getData();
            $breadCrumbs = E()->getDocument()->componentManager->getBlockByName('breadCrumbs');
            if ($breadCrumbs) {
                $breadCrumbs->addCrumb('', $newsTitle);
            }

            if ($f = $this->getData()->getFieldByName('smap_id')) {
                foreach ($f as $key => $value) {
                    $site = E()->getSiteManager()->getSiteByPage($value);
                    $f->setRowProperty($key, 'url', E()->getMap($site->id)->getURLByID($value));
                    $f->setRowProperty($key, 'base', $site->base);
                }
            }

        } else {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }

        $this->addToolbar($this->loadToolbar());
        $this->js = $this->buildJS();

        foreach ($this->getDataDescription() as $fieldDescription) {
            $fieldDescription->setMode(FieldDescription::FIELD_MODE_READ);
        }
        $am = new AttachmentManager($this->getDataDescription(), $this->getData(), $this->getTableName(), true);
        $am->createFieldDescription();
        $am->createField();
    }

    /**
     * Show news that correspond to specific tag.
     *
     * @note If tag is not exist then clean all previously received data.
     */
    protected function tag() {
        $tagID = $this->getStateParams(true);
        $tagID = (int)$tagID['tagID'];
        $newsIDs = $this->dbh->select($this->dbh->getTagsTablename($this->getTableName()), 'news_id', array('tag_id' => $tagID));
        if (is_array($newsIDs)) {
            $newsIDs = array_keys(convertDBResult($newsIDs, 'news_id', true));
            $this->addFilterCondition(array($this->getTableName() . '.news_id' => $newsIDs));
            $tagName = $this->dbh->getScalar('SELECT tag_name FROM share_tags LEFT JOIN share_tags_translation USING(tag_id) WHERE (lang_id = %s) AND (tag_id = %s)', $this->document->getLang(), $tagID);
            $pageTitle = $this->translate('TXT_NEWS_BY_TAG') . ': ' . $tagName;
            E()->getDocument()->componentManager->getBlockByName('breadCrumbs')->addCrumb(null, $pageTitle);
            E()->getDocument()->setProperty('title', $pageTitle);
        }
        $this->main();
        if ($newsIDs === true) {
            $this->setData(new Data());
        }
        if ($this->pager) {
            $this->pager->setProperty('additional_url', 'tag/' . $tagID . '/');
        }
    }
}