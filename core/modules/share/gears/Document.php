<?php
/**
 * @file.
 * Document.
 * It contains the definition to:
 * @code
final class Document;
 * @endcode
 * @author dr.Pavka
 * @copyright Energine 2006
 * @version 1.0.0
 */
namespace Energine\share\gears;

use Energine\share\components\Component;

/**
 * Page document.
 * @code
final class Document;
 * @endcode
 * @final
 */
final class Document extends Primitive implements IDocument {
    use DBWorker;
    /**
     * Template content.
     * @var string TMPL_CONTENT
     */
    const TMPL_CONTENT = 'content';
    /**
     * Template layout.
     * @var string TMPL_LAYOUT
     */
    const TMPL_LAYOUT = 'layout';

    /**
     * Reserved URL segment for 'single'-mode
     * @var string SINGLE_SEGMENT
     */
    const SINGLE_SEGMENT = 'single';

    /**
     * Path to the directory with templates.
     * @var string TEMPLATES_DIR
     */
    const TEMPLATES_DIR = 'templates/';
    /**
     * Component manager.
     * @var ComponentManager $componentManager
     */
    public $componentManager;
    /**
     * Exemplar of the AuthUser class.
     * @var AuthUser $user
     */
    public $user;
    /**
     * Info about system language.
     * @var Language $language
     */
    protected $language;
    /**
     * Site map.
     * @var Sitemap $sitemap
     */
    protected $sitemap;
    /**
     * Name of the BreadCrumbs default class
     * @var string
     */
    private $breadCrumbsClass = 'Energine\share\components\BreadCrumbs';
    /**
     * Document ID
     * @var int $id
     */
    private $id = false;
    /**
     * Document language ID.
     * @var int $lang
     */
    private $lang;
    /**
     * Request.
     * @var Request $request
     */
    private $request;
    /**
     * Result document.
     * @var \DOMDocument $doc
     */
    private $doc;
    /**
     * User rights for document.
     * Rights:
     * - ACCESS_NONE = 0
     * - ACCESS_READ = 1
     * - ACCESS_EDIT = 2
     * - ACCESS_FULL = 3
     * @var int $rights
     */
    private $rights = false;
    /**
     * Document properties.
     * @var array $properties
     */
    private $properties = [];
    /**
     * Document information.
     * @var array $documentInfo
     * @see Sitemap::getDocumentInfo()
     */
    private $documentInfo = [];

    /**
     * Array of constants for translations.
     * @var array $translations
     */
    private $translations = [];
    /**
     * Array of document javascripts (js behaviours included into content/layout files)
     *
     * @var \DOMElement[]
     */
    private $js = [];

    public function __construct() {
        parent::__construct();
        $this->user = E()->getUser();
        $this->language = E()->getLanguage();
        $this->lang = $this->language->getCurrent();
        $this->sitemap = E()->getMap();
        $this->request = E()->getRequest();
        $segments = $this->request->getPath();
        $this->componentManager = new ComponentManager($this);
        // получаем идентификатор документа
        if (isset($segments[0]) && $segments[0] == self::SINGLE_SEGMENT) {
            $segments = [];
        }
        $this->id = $this->sitemap->getIDByURI($segments);
        if (empty($this->id)) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }

        // получаем права пользователя на документ
        $this->rights =
            $this->sitemap->getDocumentRights($this->getID(), $this->user->getGroups());
        if ($this->getRights() == ACCESS_NONE) {
            throw new SystemException('ERR_403', SystemException::ERR_403);
        }

        // получаем информацию о документе
        $this->documentInfo = $this->sitemap->getDocumentInfo($this->getID());
        //Если его нет в перечне страниц значит он IsDisabled
        if (!$this->documentInfo) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        //Если URL редиректа не пустой  - осуществляем редирект по нему
        if (!empty($this->documentInfo['RedirectUrl'])) {
            // страница-ссылка на страницу сайта — на её версию языка посетителя (Response::pageLinkURL). Код 302
            // осознанно: цель владелец может сменить, а 301 браузер запомнил бы навсегда
            E()->getResponse()->setRedirect(Response::pageLinkURL($this->documentInfo['RedirectUrl']), 302);
        }
        // загружаем компоненты страницы
        //$this->loadComponents($this->documentInfo['templateID']);

        // устанавливаем свойства документа
        if ($this->documentInfo['MetaKeywords'])
            $this->setProperty('keywords', $this->documentInfo['MetaKeywords']);
        if ($this->documentInfo['MetaDescription'])
            $this->setProperty('description', $this->documentInfo['MetaDescription']);
        if ($this->documentInfo['DescriptionRtf'])
            $this->setProperty('DescriptionRtf', $this->documentInfo['DescriptionRtf']);
            
        if ($this->documentInfo['MetaRobots'])
            $this->setProperty('robots', implode(',', $this->documentInfo['MetaRobots']));
        $this->setProperty('template', $this->request->getPath(Request::PATH_TEMPLATE, true));
        $this->setProperty('ID', $this->getID());
        $this->setProperty('default',
            $this->sitemap->getDefault() == $this->getID());
    }

    /**
     * Get document ID.
     * @return int
     */
    public function getID() {
        return $this->id;
    }

    /**
     * Get user rights.
     * @see Document::$rights
     * @return int
     */
    public function getRights() {
        return $this->rights;
    }

    /**
     * Set document property.
     * @param string $propName Property name.
     * @param string $propValue Property value.
     */
    public function setProperty($propName, $propValue) {
        $this->properties[$propName] = $propValue;
    }

    /**
     * Setting breadCrumbs class name
     * It gives the possibilty to add custom BreadCrumbs class
     * @param string $breadCrumbsClass
     * @throws SystemException
     */
    public function setBreadCrumbs($breadCrumbsClass) {
        if (!class_parents($breadCrumbsClass)) {
            throw new SystemException('ERR_BAD_BREADCRUMBS_CLASS', SystemException::ERR_DEVELOPER, $breadCrumbsClass);
        }
        $this->breadCrumbsClass = $breadCrumbsClass;
    }

    /**
     * Building resulte XML Document
     */
    public function build() {
        //Если у нас не режим json

        $this->doc = new \DOMDocument('1.0', 'UTF-8');
        $dom_root = $this->doc->createElement('document');
        $dom_root->setAttribute('debug', $this->getConfigValue('site.debug'));
        $dom_root->setAttribute('editable', $this->isEditable());
        $this->setProperty('url', (string)$this->request->getURI());

        $this->doc->appendChild($dom_root);
        if (!isset($this->properties['title'])) {
            $this->setProperty('title', strip_tags($this->documentInfo['Name']));
        }
        $dom_documentProperties = $this->doc->createElement('properties');
        foreach ($this->properties as $propName => $propValue) {
            $dom_property =
                $this->doc->createElement('property', str_replace('&', '&amp;', (string)$propValue));
            $dom_property->setAttribute('name', $propName);
            if ($propName == 'title') {
                $dom_property->setAttribute('alt', (string)$this->documentInfo['HtmlTitle']);
            }
            $dom_documentProperties->appendChild($dom_property);
        }
        $dom_root->appendChild($dom_documentProperties);

        //Дополнительные свойства, имеющие параметры
        $prop = $this->doc->createElement('property', (
        $baseURL = E()->getSiteManager()->getCurrentSite()->base));
        $prop->setAttribute('name', 'base');
        $prop->setAttribute('static', (($staticURL =
            $this->getConfigValue('site.static')) ? $staticURL : $baseURL));
        $prop->setAttribute('media', (($mediaURL =
            $this->getConfigValue('site.media')) ? $mediaURL : $baseURL));
        $prop->setAttribute('resizer', (($resizerURL =
            $this->getConfigValue('site.resizer')) ? $resizerURL : ($baseURL . 'resizer/')));
        $prop->setAttribute('folder', E()->getSiteManager()->getCurrentSite()->folder);
        $dom_documentProperties->appendChild($prop);

        $prop = $this->doc->createElement('property', $this->getLang());
        $prop->setAttribute('name', 'lang');
        $prop->setAttribute('abbr', $this->request->getLangSegment());
        $prop->setAttribute('default', E()->getLanguage()->getDefault());
        $prop->setAttribute('real_abbr', E()->getLanguage()->getAbbrByID($this->getLang()));
        $dom_documentProperties->appendChild($prop);

        // токен против подделки запросов: meta и Energine.csrf в document.xslt, скрытое поле в формах
        $prop = $this->doc->createElement('property', Csrf::token());
        $prop->setAttribute('name', 'csrf');
        $dom_documentProperties->appendChild($prop);

        unset($prop);
        foreach ($this->componentManager as $component) {
            $componentResult = false;
            if ($component->enabled()
                &&
                ($this->getRights() >= $component->getCurrentStateRights())
            ) {
                $componentResult = $this->timed($component, 'build', fn() => $component->build());
            }

            if (!empty($componentResult)) {
                try {
                    $componentResult = $this->doc->importNode(
                        $componentResult->documentElement,
                        true
                    );
                } catch (\Exception $e) {
                    //stop($e->getTraceAsString());
                }
                $dom_root->appendChild($componentResult);
            }
        }

        if (!empty($this->translations)) {
            $dom_translations = $this->doc->createElement('translations');
            $dom_root->appendChild($dom_translations);

            foreach ($this->translations as $const => $componentName) {
                $dom_translation =
                    $this->doc->createElement('translation', translate($const));
                $dom_translation->setAttribute('const', $const);
                if (!is_null($componentName)) {
                    $dom_translation->setAttribute('component', $componentName);
                }
                $dom_translations->appendChild($dom_translation);
            }
        }

        // модули страницы: поведения компонентов и все скрипты web/scripts для import map (имя → время файла:
        // после обновления браузер не возьмёт из кэша прежний файл ни у страницы, ни у её зависимостей)
        $dom_javascript = $this->doc->createElement('javascript');
        $dom_root->appendChild($dom_javascript);
        foreach ($this->js as $behavior) {
            $dom_javascript->appendChild($this->doc->importNode($behavior, true));
        }
        foreach ($this->scriptModules() as $name => $version) {
            $dom_module = $this->doc->createElement('module');
            $dom_module->setAttribute('name', $name);
            $dom_module->setAttribute('version', $version);
            $dom_javascript->appendChild($dom_module);
        }

        // отладка: сколько и каких запросов к базе понадобилось странице (?debug → document/@queries, document/queries)
        if ($this->getConfigValue('site.debug')) {
            $db = E()->getDB();
            $dom_root->setAttribute('queries', (string)$db->queryCount());
            $dom_queries = $this->doc->createElement('queries');
            foreach ($db->queryLog() as $sql) {
                $dom_queries->appendChild($this->doc->createElement('query'))->appendChild($this->doc->createTextNode($sql));
            }
            $dom_root->appendChild($dom_queries);
            // время блоков (по образцу ?speed xSight): какой компонент тормозит и сколько запросов делает. Элемент
            // timing, а не component: шаблоны собирают все //component[@name]
            $dom_timings = $this->doc->createElement('timings');
            foreach ($this->timings as $name => $t) {
                $el = $this->doc->createElement('timing');
                $el->setAttribute('name', $name);
                $el->setAttribute('class', $t['class']);
                $el->setAttribute('run', sprintf('%.2f', $t['run']));
                $el->setAttribute('build', sprintf('%.2f', $t['build']));
                $el->setAttribute('queries', (string)$t['queries']);
                $dom_timings->appendChild($el);
            }
            $dom_root->appendChild($dom_timings);
        }
    }

    /**
     * Модули для import map: файлы .js в web/scripts (ссылки на скрипты модулей и Jodit) — имя (путь без .js) →
     * время изменения файла.
     *
     * @return array
     */
    protected function scriptModules() {
        $dir = HTDOCS_DIR . '/scripts';
        $modules = [];
        if (is_dir($dir)) {
            $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($dir,
                \FilesystemIterator::SKIP_DOTS | \FilesystemIterator::FOLLOW_SYMLINKS));
            foreach ($files as $file) {
                // битая ссылка (скрипт убран из кода, setup linker ещё не запускали) — пропускается, страница цела
                if ($file->getExtension() === 'js' && $file->isFile()) {
                    $name = substr(str_replace('\\', '/', substr($file->getPathname(), strlen($dir) + 1)), 0, -3);
                    $modules[$name] = (string)$file->getMTime();
                }
            }
        }
        ksort($modules);
        return $modules;
    }

    /**
     * Check if the component editable.
     * @return bool
     */
    public function isEditable() {
        if ($this->getRights() > 2) {
            return ($this->getConfigValue('site.debug')) ? isset($_REQUEST['editMode']) : isset($_POST['editMode']);
        } else {
            return false;
        }
    }

    /**
     * Get language ID.
     * @return int
     */
    public function getLang() {
        return $this->lang;
    }
    /**modbySD
     * Set language ID.
     */
    public function setLang($lang_id) {
        $this->lang=$lang_id;
    }
    public function getResult() {
        return $this->doc;
    }

    /**
     * Define and load page components into the ComponentManager.
     * @todo Полный рефакторинг!
     */
    public function loadComponents(callable $getStructure) {
        // определяем и загружаем описания content- и layout- частей страницы
        $structure = call_user_func($getStructure, $this->getID());
        // вызывается ли компонент в single режиме?
        $actionParams = $this->request->getPath(Request::PATH_ACTION);
        if (sizeof($actionParams) > 1 &&
            $actionParams[0] == self::SINGLE_SEGMENT
        ) {
            /*
            * Устанавливаем смещение пути на количество существующих
            * сегментов + 1 зарезирвированный сегмент + 1 сегмент
            * имени компонента.
            */
            $this->request->setPathOffset($this->request->getPathOffset() + 2);
            $this->setProperty('single', 'single');
            if ($actionParams[1] == 'pageToolBar') {
                $this->componentManager->add(
                    $this->componentManager->createComponent(
                        'pageToolBar',
                        'Energine\share\components\DivisionEditor',
                        ['state' => 'showPageToolbar']
                    )
                );
            } // существует ли запрошенный компонент среди компонентов страницы?
            else {
                if (!($blockDescription = ComponentManager::findBlockByName(
                    $structure,
                    $actionParams[1]))
                ) {
                    // окна такого компонента на странице нет — «не найдено» (404), а не сбой (500)
                    throw new SystemException('ERR_NO_SINGLE_COMPONENT', SystemException::ERR_404,
                        $actionParams[1]);
                }
                if (E()->getController()->getViewMode() ==
                    DocumentController::TRANSFORM_STRUCTURE_XML
                ) {
                    $int = new IRQ();
                    $int->setStructure($blockDescription);
                    throw $int;
                }

                if ($c = ComponentManager::createBlockFromDescription($blockDescription))
                    $this->componentManager->add($c);
            }

        } else {
            if (E()->getController()->getViewMode() ==
                DocumentController::TRANSFORM_STRUCTURE_XML
            ) {
                $int = new IRQ();
                $int->setStructure($structure);
                throw $int;
            }

            foreach ($structure->children() as $XML) {
                if ($c = ComponentManager::createBlockFromDescription($XML))
                    $this->componentManager->add($c);

            }
            /*
            * Добавляем к набору компонентов страницы
            * обязательные стандартные компоненты:
            *     - BreadCrumbs
            */
            $this->componentManager->add($this->componentManager->createComponent('breadCrumbs',
                $this->breadCrumbsClass));
        }

    }

    /**
     * Run all components.
     */
    /**
     * Время и запросы к базе каждого компонента: имя → class, run, build (мс), queries. При site.debug — <timings> в XML.
     * @var array<string, array>
     */
    private array $timings = [];

    /**
     * Выполнить этап блока (run, build) с замером времени и запросов к базе. Контейнер не замеряется — его компоненты
     * замеряет он сам (ComponentContainer), иначе время считалось бы дважды.
     */
    public function timed($block, string $stage, callable $fn): mixed {
        if ($block instanceof ComponentContainer) {
            return $fn();
        }
        $started = hrtime(true);
        $queries = E()->getDB()->queryCount();
        try {
            return $fn();
        } finally {
            $name = method_exists($block, 'getName') ? (string)$block->getName() : '#' . spl_object_id($block);
            $t = $this->timings[$name] ?? ['class' => get_class($block), 'run' => 0.0, 'build' => 0.0, 'queries' => 0];
            $t[$stage] += (hrtime(true) - $started) / 1e6;
            $t['queries'] += E()->getDB()->queryCount() - $queries;
            $this->timings[$name] = $t;
        }
    }

    public function runComponents() {
        foreach ($this->componentManager as $block) {
            //$block->run();
            if (
                $block->enabled()
                &&
                ($this->getRights() >= $block->getCurrentStateRights())
            ) {
                $this->timed($block, 'run', fn() => $block->run());
            } elseif ($block->enabled() && $this->getProperty('single')) {
                // окно (single): запрошенный компонент — единственный на странице; прав на его состояние нет —
                // отказ 403, а не пустая страница 200
                throw new SystemException('ERR_403', SystemException::ERR_403);
            }
            /*
            * Запускаем определение текущего действия компонента
            * и загрузку конфигурационной информации.
            */
            //$component->getState();

            // если у пользователя достаточно прав - запускаем работу компонента

        }
    }

    /**
     * Get current user.
     * @return AuthUser
     */
    public function getUser() {
        return $this->user;
    }

    /**
     * Get document property.
     * @param string $propName Property name.
     * @return string|false
     */
    public function getProperty($propName) {
        if (isset($this->properties[$propName])) {
            return $this->properties[$propName];
        }

        return false;
    }

    /**
     * Remove property.
     * @param string $propName Property name.
     */
    public function removeProperty($propName) {
        if (isset($this->properties[$propName])) {
            unset($this->properties[$propName]);
        }
    }

    /**
     * Add translation constant.
     * @param string $const Translation constant
     * @param Component $component Component object.
     */
    public function addTranslation($const, ?Component $component = NULL) {
        $this->translations[$const] =
            (!is_null($component)) ? $component->getName() : NULL;
    }

    /**
     * @param $behavior
     * @throws \DOMException
     */
    public function addJSBehavior($behavior) {
        if (is_a($behavior, '\SimpleXMLElement')) {
            if (!($bNode = dom_import_simplexml($behavior))) {
                throw new \DOMException('Bad JS behaviour.');
            }
            array_push($this->js, $bNode);
        }
    }


    public function getXMLDocument() {
        return $this->doc;
    }
}