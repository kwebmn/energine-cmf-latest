<?php
/**
 * @file
 * SiteManager.
 *
 * It contains the definition to:
 * @code
final class SiteManager;
 * @endcode
 *
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * Site manager.
 *
 * @code
final class SiteManager;
 * @endcode
 *
 * @final
 */
final class SiteManager extends Primitive implements \Iterator {
    use DBWorker;

    /*
     * Instance of the current class.
     *
     * @var SiteManager $instance
     */
    //private static $instance;

    /**
     * Data about all registered sites.
     * Array of Site's.
     * @var array $data
     */
    private $data;
    /**
     * Iteration index.
     * @var int $index
     */
    private static $index = 0;

    /**
     * Current site ID.
     * @var int $currentSiteID
     */
    private $currentSiteID = NULL;

    /**
     * Адрес сайта — из конфига (site.domain, site.root), схема — из запроса. Заголовок Host адреса не меняет.
     *
     * @throws SystemException 'ERR_NO_SITE' нет site.domain в конфиге или сайта в базе
     * @throws SystemException 'ERR_403' сайт не активен
     */
    public function __construct() {
        parent::__construct();
        $this->data = Site::load();
        if (!($domain = (string)$this->getConfigValue('site.domain')) || !$this->data) {
            throw new SystemException('ERR_NO_SITE', SystemException::ERR_DEVELOPER, 'site.domain');
        }
        $scheme = URI::create()->getScheme();
        foreach ($this->data as $siteID => $site) {
            $site->setAddress($scheme, $domain, $this->getConfigValue('site.root'));
            if ($site->isDefault == 1) {
                $this->currentSiteID = $siteID;
            }
        }
        if (is_null($this->currentSiteID)) {
            $this->currentSiteID = array_key_first($this->data);
        }
        //Если текущий сайт не активный
        if (!$this->data[$this->currentSiteID]->isActive) {
            throw new SystemException('ERR_403', SystemException::ERR_403);
        }

    }

    /**
     * Get Site instance by its ID.
     *
     * @param int $siteID Site ID.
     * @return Site
     *
     * @throws SystemException 'ERR_NO_SITE'
     */
    public function getSiteByID($siteID) {

        if (!isset($this->data[$siteID])) {
            throw new SystemException('ERR_NO_SITE', SystemException::ERR_DEVELOPER, $siteID);
        }
        return $this->data[$siteID];
    }

    /**
     * Get exemplar of Site object by his page ID.
     *
     * @param int $pageID Page ID.
     * @return Site
     */
    public function getSiteByPage($pageID) {
        if(!($id = $this->dbh->getScalar('share_sitemap', 'site_id', ['smap_id' => $pageID]))) return null;

        return $this->getSiteByID($id);
    }

    /**
     * Returns current site.
     *
     * @return Site
     */
    public function getCurrentSite() {
        return $this->data[$this->currentSiteID];

    }


    /**
     * Get default site.
     *
     * @return Site
     *
     * @throws SystemException 'ERR_NO_DEFAULT_SITE'
     */
    public function getDefaultSite() {
        foreach ($this->data as $site) {
            if ($site->isDefault) {
                return $site;
            }
        }
        throw new SystemException('ERR_NO_DEFAULT_SITE', SystemException::ERR_DEVELOPER);
    }

    public function current(): mixed {
        $siteIDs = array_keys($this->data);

        return $this->data[$siteIDs[self::$index]];
    }

    public function key(): mixed {
        $siteIDs = array_keys($this->data);
        return $siteIDs[self::$index];
    }

    public function next(): void {
        self::$index++;
    }

    public function rewind(): void {
        self::$index = 0;
    }

    public function valid(): bool {
        $siteIDs = array_keys($this->data);
        return isset($siteIDs[self::$index]);
    }

}