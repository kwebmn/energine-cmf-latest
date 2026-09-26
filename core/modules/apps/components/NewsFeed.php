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

        // архив по датам: год, месяц и день — числа в своих пределах, иначе такого адреса нет
        // (иначе адрес вырезанной ленты RSS и любой мусор отдавали пустую ленту с кодом 200)
        foreach (['year' => [1, 9999], 'month' => [1, 12], 'day' => [1, 31]] as $parameterName => [$min, $max]) {
            if (isset($ap[$parameterName]) && (!ctype_digit((string)$ap[$parameterName])
                    || $ap[$parameterName] < $min || $ap[$parameterName] > $max)) {
                throw new SystemException('ERR_404', SystemException::ERR_404);
            }
        }

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
                    $f->setRowProperty($key, 'url', E()->getMap()->getURLByID($value));
                    $f->setRowProperty($key, 'base', E()->getSiteManager()->getCurrentSite()->base);
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
}