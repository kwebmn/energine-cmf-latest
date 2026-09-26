<?php
/**
 * @file
 * Site.
 * It contains the definition to:
 * @code
class Site;
 * @endcode
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 * @version 1.0.0
 */
namespace Energine\share\gears;

/**
 * Site.
 * @code
class Site;
 * @endcode
 * @property-read int $id
 * @property-read string $base адрес сайта: схема запроса, site.domain и site.root из конфига
 * @property-read string $root корень сайта (site.root): /, /sub/
 * @property-read string $host хост из site.domain без порта
 * @property-read string $cookieDomain атрибут Domain для cookie (см. cookieDomainOf)
 * @property-read bool $isIndexed
 * @property-read array $metaRobots
 * @property-read string $metaKeywords
 * @property-read string $metaDescription
 */
class Site extends Primitive {
    use DBWorker {
        __get as _get;
    }
    /**
     * Site data.
     * @var array $data
     */
    private $data;
    /**
     * Site translations.
     * @var array $siteTranslationsData
     */
    static private $siteTranslationsData;
    /**
     * Flag, indicates if extended properties 'share_sites_properties' table exists.
     * @var string
     */
    public static $isPropertiesTableExists = null;

    /**
     * @param array $data Data.
     */
    public function __construct($data) {
        parent::__construct();
        $this->data = E()->Utils->convertFieldNames($data, 'site_');
        if (is_null(self::$isPropertiesTableExists)) {
            self::$isPropertiesTableExists = $this->dbh->tableExists('share_sites_properties');
        }
    }

    /**
     * Load site.
     * Return the information about all sites in the form of an array of Site objects.
     * Right away all info is cached from translation table, because ata this moment current language is not yet defined.
     * @return Site[]
     */
    public static function load() {
        $result = [];
        $res = E()->getDB()->select('share_sites');
        foreach ($res as $siteData) {
            if(!empty($siteData['site_meta_robots'])){
                $siteData['site_meta_robots'] = explode(',', $siteData['site_meta_robots']);
            }
            else {
                $siteData['site_meta_robots'] = [];
            }
            $siteData['site_is_indexed'] = !in_array('NOINDEX', $siteData['site_meta_robots']);
            $result[$siteData['site_id']] = new Site($siteData);
        }
        $res = E()->getDB()->select('share_sites_translation');

        self::$siteTranslationsData = [];
        $f = function ($row) {
            unset($row['lang_id'], $row['site_id']);
            $row = E()->Utils->convertFieldNames($row, 'site_');
            return $row;
        };
        foreach ($res as $row) {
            self::$siteTranslationsData[$row['lang_id']][$row['site_id']] = $f($row);

        }

        return $result;
    }

    /**
     * Адрес сайта — из конфига, а не из заголовка Host запроса: поддельный Host не меняет ни ссылок,
     * ни письма восстановления пароля, ни редиректов.
     *
     * @param string $scheme схема запроса (http, https)
     * @param string $domain site.domain: хост и, если нестандартный, порт
     * @param string|null $root site.root
     */
    public function setAddress($scheme, $domain, $root) {
        $this->data['root'] = self::normalizeRoot($root);
        $this->data['host'] = self::hostOf($domain);
        $this->data['cookieDomain'] = self::cookieDomainOf($domain);
        $this->data['base'] = $scheme . '://' . $domain . $this->data['root'];
    }

    /**
     * Хост без порта: 'example.org:8080' → 'example.org'.
     *
     * @param string $domain
     * @return string
     */
    public static function hostOf($domain) {
        return explode(':', (string)$domain, 2)[0];
    }

    /**
     * Атрибут Domain для cookie сайта: '.example.org' — cookie видна и поддоменам (www).
     * Для адреса с портом, IP и имени без точки (localhost) — '': Domain=.127.0.0.1:8123 и Domain=.localhost
     * браузер отбрасывает, cookie ставится только этому хосту.
     *
     * @param string $domain site.domain
     * @return string
     */
    public static function cookieDomainOf($domain) {
        $domain = (string)$domain;
        if ($domain === '' || str_contains($domain, ':') || !str_contains($domain, '.')
            || filter_var($domain, FILTER_VALIDATE_IP)) {
            return '';
        }

        return '.' . $domain;
    }

    /**
     * Корень сайта со слешами с обеих сторон: '' и '/' → '/', 'sub' и '/sub' → '/sub/'.
     *
     * @param string|null $root site.root
     * @return string
     */
    public static function normalizeRoot($root) {
        $root = trim((string)$root, '/');

        return ($root === '') ? '/' : '/' . $root . '/';
    }

    /**
     * Magic @c get method.
     * @param string $propName Property name.
     * @return mixed
     */
    public function __get($propName) {
         $result = null;
        //DBWorker __get alias
        if (!is_null($result = $this::_get($propName))) {
            return $result;
        }
        if (isset($this->data[$propName])) {
            $result = $this->data[$propName];
        }
        elseif (in_array($propName, ['name', 'metaKeywords', 'metaDescription'])) {
            return $this->data[$propName] = self::$siteTranslationsData[E()->getLanguage()->getCurrent()][$this->data['id']][$propName];
        } elseif (self::$isPropertiesTableExists) {
            $res = $this->data[$propName] = $this->dbh->getScalar(
                'SELECT prop_value FROM share_sites_properties
                    WHERE prop_name = %s
                    AND (site_id = %s
                    OR site_id IS NULL)
                    ORDER BY site_id DESC
                    LIMIT 1',
                $propName,
                $this->data['id']
            );

            $result = (false !== $res) ? $res : $result;
            //var_dump($result, $propName);
        }
        return $result;
    }

    function __toString() {
        return (string)$this->id;
    }
}