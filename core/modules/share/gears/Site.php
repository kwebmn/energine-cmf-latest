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
     * Модуль сайта (site/modules/main): шаблоны, трансформеры и конфиги компонентов сайта.
     */
    const FOLDER = 'main';
    /**
     * Site data.
     * @var array $data
     */
    private $data;
    /**
     * Название, ключевые слова и описание сайта по языкам.
     * @var array $translations
     */
    private $translations = [];

    /**
     * @param array $data строка share_sites
     * @param array $translations строки share_sites_translation по lang_id
     */
    public function __construct($data, array $translations = []) {
        parent::__construct();
        $this->data = E()->Utils->convertFieldNames($data, 'site_');
        $this->data['folder'] = self::FOLDER;
        $this->translations = $translations;
    }

    /**
     * Запись сайта — единственная строка share_sites; переводы читаются сразу: текущий язык в этот момент ещё
     * не определён.
     *
     * @return Site|null
     */
    public static function load() {
        if (!($res = E()->getDB()->select('share_sites'))) {
            return null;
        }
        list($siteData) = $res;
        $siteData['site_meta_robots'] = empty($siteData['site_meta_robots']) ? [] : explode(',', $siteData['site_meta_robots']);
        $siteData['site_is_indexed'] = !in_array('NOINDEX', $siteData['site_meta_robots']);
        $translations = [];
        foreach (E()->getDB()->select('share_sites_translation', true, ['site_id' => $siteData['site_id']]) ?: [] as $row) {
            $lang = $row['lang_id'];
            unset($row['lang_id'], $row['site_id']);
            $translations[$lang] = E()->Utils->convertFieldNames($row, 'site_');
        }

        return new Site($siteData, $translations);
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
            return $this->data[$propName] = $this->translations[E()->getLanguage()->getCurrent()][$propName] ?? null;
        } else {
            // дополнительный параметр сайта (share_sites_properties, «Настройки сайта»)
            $res = $this->data[$propName] = $this->dbh->getScalar('share_sites_properties', 'prop_value', ['prop_name' => $propName]);
            $result = (false !== $res) ? $res : $result;
        }
        return $result;
    }

    function __toString() {
        return (string)$this->id;
    }
}