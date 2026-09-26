<?php
/**
 * @file
 * Response.
 *
 * It contains the definition to:
 * @code
final class Response;
@endcode
 *
 * @author 1m.dm
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * HTTP-response.
 *
 * @code
final class Response;
@endcode
 *
 * @final
 */
final class Response extends Primitive {
    /**
     * Reason phrases.
     * @var mixed $reasonPhrases
     */
    private $reasonPhrases;

    /**
     * Line of the response status.
     * @var string $statusLine
     */
    private $statusLine;

    /**
     * Response header.
     * @var array $headers
     */
    private $headers;

    /**
     * Response cookies.
     * @var array $cookies
     */
    private $cookies;

    /**
     * Response body.
     * @var string $body
     */
    private $body;

    public function __construct() {
        $this->reasonPhrases = include_once('reasonPhrases.inc.php');
        $this->setStatus(200);
        $this->headers = array();
        $this->cookies = array();
        $this->body = '';
    }

    /**
     * Prepare redirection URL.
     * It replaces @c lang and @c site to the correspond values.
     *
     * @param string $redirectURL Redirection URL.
     * @return string
     */
    public static function prepareRedirectURL($redirectURL) {
        if (empty($redirectURL)) return $redirectURL;
        $lang = E()->getLanguage();

        return str_replace(
            array(
                '%lang%',
                '%site%'
            ),
            array(
                $lang->getAbbrByID($lang->getCurrent()),
                E()->getSiteManager()->getCurrentSite()->base
            ),
            $redirectURL);
    }

    /**
     * Set response status.
     *
     * @param int $statusCode Status code.
     * @param string $reasonPhrase Reason phrase.
     */
    public function setStatus($statusCode, $reasonPhrase = null) {
        if (is_null($reasonPhrase)) {
            $reasonPhrase =
                (isset($this->reasonPhrases[$statusCode]) ? $this->reasonPhrases[$statusCode] : '');
        }
        $this->statusLine =
            ((isset($_SERVER['SERVER_PROTOCOL'])) ? $_SERVER['SERVER_PROTOCOL'] : 'UNKNOWN') . " $statusCode $reasonPhrase";
    }

    /**
     * Set response header.
     *
     * @param string $name Header name.
     * @param string $value Header value.
     * @param boolean $replace Defines whether the header value should be replaced.
     */
    public function setHeader($name, $value, $replace = true) {
        if ((!$replace) && isset($this->headers[$name])) {
            return;
        }
        $this->headers[$name] = $value;
    }

    /**
     * Set cookies.
     *
     * @param string $name Session name.
     * @param string $value Value.
     * @param int $expire Expire time.
     * @param bool $domain Domain.
     * @param string $path Path.
     * @param bool $httpOnly Недоступна из JS (cookie, которые читает JS, этот флаг не получают).
     */
    public function addCookie($name = UserSession::DEFAULT_SESSION_NAME, $value = '', $expire = 0, $domain = false, $path = '/', $httpOnly = false) {
        if (!$domain) {
            // домен cookie сайта: .хост, для адреса с портом, IP и localhost — без Domain (Site::cookieDomainOf)
            $domain = E()->getSiteManager()->getCurrentSite()->cookieDomain;
            $path = '/';
        }
        $secure = (E()->getRequest()->getURI()->getScheme() == 'https');
        $_COOKIE[$name] = $value;
        $this->cookies[$name] =
            compact('value', 'expire', 'path', 'domain', 'secure', 'httpOnly');
    }

    /**
     * Send cookies to the list.
     *
     * This is used only in @c commit. It is made public for possibility to call this from capcha (but this is exception).
     */
    public function sendCookies() {
        foreach ($this->cookies as $name => $params) {
            // SameSite=Lax: с чужого сайта cookie приходят только при переходе по ссылке, не с POST
            setcookie($name, $params['value'], [
                'expires' => $params['expire'], 'path' => $params['path'], 'domain' => $params['domain'],
                'secure' => $params['secure'], 'httponly' => $params['httpOnly'], 'samesite' => 'Lax',
            ]);
        }
    }

    /**
     * Send headers.
     */
    public function sendHeaders() {
        header($this->statusLine);
        foreach ($this->headers as $name => $value) {
            header("$name: $value");
        }
    }

    /**
     * Remove cookie by name.
     *
     * @param string $name
     */
    public function deleteCookie($name) {
        $this->addCookie($name, '', (time() - 1));
    }

    /**
     * Set redirection URL and redirect.
     *
     * @param string $location Redirection URL.
     * @param int $status
     * @throws InvalidArgumentException
     */
    public function setRedirect($location, $status = 302) {
        if(!in_array($status, array(301, 302))) throw new \InvalidArgumentException();

        $this->setStatus($status);
        $this->setHeader('Location', self::prepareRedirectURL($location));
        $this->setHeader('Content-Length', 0);
        $this->commit();
    }

    /**
     * Redirect to current section.
     *
     * @param string $action Action name.
     */
    public function redirectToCurrentSection($action = '') {
        if ($action && substr($action, -1) !== '/') {
            $action .= '/';
        }
        $request = E()->getRequest();
        $this->setRedirect(
            E()->getSiteManager()->getCurrentSite()->base .
                $request->getLangSegment()
                . $request->getPath(Request::PATH_TEMPLATE, true)
                . $action
        );
    }

    /**
     * Add data to the response body.
     *
     * @param string $data New data.
     */
    public function write($data) {
        $this->body .= $data;
    }

    /**
     * Адрес ведёт на этот же сайт: путь от корня или полный адрес с хостом запроса.
     *
     * @param string $url
     * @return bool
     */
    private static function isLocalURL($url) {
        if (preg_match('~[\x00-\x1f\\\\]~', $url)) {
            return false;
        }
        if (preg_match('~^/(?!/)~', $url)) {
            return true;
        }
        $host = preg_replace('/:\d+$/', '', (string)($_SERVER['HTTP_HOST'] ?? ''));
        return in_array(strtolower((string)parse_url($url, PHP_URL_SCHEME)), ['http', 'https'], true)
            && $host !== '' && strcasecmp((string)parse_url($url, PHP_URL_HOST), $host) === 0;
    }

    /**
     * Go back.
     *
     * @see auth.php
     */
    public function goBack() {
        $url = $_GET['return'] ?? $_SERVER['HTTP_REFERER'] ?? null;
        // только на этот же сайт: чужой адрес в return или Referer уводил бы посетителя куда угодно
        if (!is_string($url) || !self::isLocalURL($url)) {
            $url = E()->getSiteManager()->getCurrentSite()->root;
        }
        $this->setHeader('Location', $url);
        $this->commit();
    }

    /**
     * Disable cache.
     */
    public function disableCache() {
        $this->setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
        $this->setHeader('Pragma', 'no-cache');
        $this->setHeader('X-Accel-Expires', 0);
    }

    /**
     * Send response to the client.
     * @note This the last step.
     */
    public function commit() {
        if (!headers_sent()) {
            $this->sendHeaders();
            $this->sendCookies();
        } else {
            //throw new SystemException('ERR_HEADERS_SENT', SystemException::ERR_CRITICAL);
        }
        $contents = $this->body;

        if ((bool)Primitive::getConfigValue('site.compress')
            && isset($_SERVER['HTTP_ACCEPT_ENCODING'])
            && (strpos($_SERVER['HTTP_ACCEPT_ENCODING'], 'gzip') !== false)
            && !(bool)Primitive::getConfigValue('site.debug')
        ) {
            header("Vary: Accept-Encoding");
            header("Content-Encoding: gzip");
            $contents = gzencode($contents, 6);
        }
        echo $contents;
        session_write_close();
        exit;
    }
}
