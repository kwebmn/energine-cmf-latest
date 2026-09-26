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

    /**
     * Та же страница по адресу сайта, если GET или HEAD пришёл по другому имени или порту (www, IP, поддельный Host).
     * У сайта один адрес: формы страницы, открытой по другому имени, уходили бы на адрес из конфига с чужим Origin
     * и отклонялись проверкой Csrf, а поисковики видели бы копии сайта. POST не переадресуется (его отклонит Csrf),
     * консоль — тоже.
     *
     * @return string|null адрес для переадресации 301 или null — запрос уже на адресе сайта
     */
    public function canonicalLocation() {
        if (E()->Utils->is_PHP_CLI() || !in_array($_SERVER['REQUEST_METHOD'] ?? 'GET', ['GET', 'HEAD'], true)) {
            return null;
        }
        $uri = URI::create();
        $domain = (string)$this->getConfigValue('site.domain');
        $port = (int)(explode(':', $domain, 2)[1] ?? ($uri->getScheme() == 'https' ? 443 : 80));
        if (strcasecmp($uri->getHost(), Site::hostOf($domain)) === 0 && (int)$uri->getPort() === $port) {
            return null;
        }

        return $uri->getScheme() . '://' . $domain . ($_SERVER['REQUEST_URI'] ?? '/');
    }
}
