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
 * Сайт установки — один: запись share_sites и адрес из конфига (site.domain, site.root).
 *
 * @code
final class SiteManager;
 * @endcode
 *
 * @final
 */
final class SiteManager extends Primitive {
    use DBWorker;

    /**
     * Сайт.
     * @var Site $site
     */
    private $site;

    /**
     * Адрес сайта — из конфига (site.domain, site.root), схема — из запроса. Заголовок Host адреса не меняет.
     *
     * @throws SystemException 'ERR_NO_SITE' нет site.domain в конфиге или записи сайта в базе
     */
    public function __construct() {
        parent::__construct();
        $this->site = Site::load();
        if (!($domain = (string)$this->getConfigValue('site.domain')) || !$this->site) {
            throw new SystemException('ERR_NO_SITE', SystemException::ERR_DEVELOPER, 'site.domain');
        }
        $this->site->setAddress(URI::create()->getScheme(), $domain, $this->getConfigValue('site.root'));
    }

    /**
     * Сайт установки.
     *
     * @return Site
     */
    public function getCurrentSite() {
        return $this->site;
    }
}
