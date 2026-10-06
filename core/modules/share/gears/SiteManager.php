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
     * Канонический адрес текущего запроса (canonicalURL) — для переадресации 301 до разбора адреса; консоль — null.
     *
     * @return string|null адрес для переадресации 301 или null — запрос уже на своём адресе
     */
    public function canonicalLocation() {
        if (E()->getUtils()->is_PHP_CLI()) {
            return null;
        }
        $uri = URI::create();
        return self::canonicalURL(
            (string)($_SERVER['REQUEST_METHOD'] ?? 'GET'),
            $uri->getScheme(),
            $uri->getHost(),
            (int)$uri->getPort(),
            (string)($_SERVER['REQUEST_URI'] ?? '/'),
            strcasecmp((string)($_SERVER['HTTP_X_REQUEST'] ?? ''), 'json') === 0,
            (string)Primitive::getConfigValue('site.domain')
        );
    }

    /**
     * Канонический адрес запроса GET или HEAD — у сайта один адрес на страницу:
     *  - имя и порт — из site.domain: страница, открытая по другому имени (www, IP, поддельный Host), уходила бы формами
     *    на адрес из конфига с чужим Origin (их отклоняет Csrf), а поисковики видели бы копии сайта;
     *  - путь страницы кончается на «/»: /about и /about/ были одной страницей с кодом 200 (дубль). Без слеша остаются
     *    запросы JSON админки (их адреса не индексируются, ответ — данные) и «файлы» — точка в последнем сегменте
     *    (robots.txt, index.php, картинка).
     * Оба отличия — одна переадресация. Путь и строка запроса — как пришли (без декодирования). POST не переадресуется
     * (его отклонил бы Csrf, а 301 сменил бы метод на GET).
     *
     * @param string $requestUri путь со строкой запроса, как в REQUEST_URI
     * @param bool $json запрос JSON (заголовок X-Request: JSON)
     * @param string $domain site.domain (имя, возможно с портом)
     * @return string|null адрес для 301 или null — адрес уже канонический
     */
    public static function canonicalURL(string $method, string $scheme, string $host, int $port, string $requestUri, bool $json, string $domain): ?string {
        if (!in_array(strtoupper($method), ['GET', 'HEAD'], true)) {
            return null;
        }
        [$path, $query] = explode('?', $requestUri, 2) + [1 => null];
        if ($path === '') {
            $path = '/';
        }
        $expectedPort = (int)(explode(':', $domain, 2)[1] ?? ($scheme == 'https' ? 443 : 80));
        $sameHost = strcasecmp($host, Site::hostOf($domain)) === 0 && $port === $expectedPort;
        $last = substr($path, strrpos($path, '/') + 1);
        $addSlash = !$json && !str_ends_with($path, '/') && !str_contains($last, '.');
        if ($sameHost && !$addSlash) {
            return null;
        }

        return $scheme . '://' . $domain . $path . ($addSlash ? '/' : '') . ($query === null ? '' : '?' . $query);
    }
}
