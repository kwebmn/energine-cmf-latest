<?php
/**
 * @file
 * ComponentConfig.
 *
 * It contains the definition to:
 * @code
class ComponentConfig;
@endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2007
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;
/**
 * Component configuration manager.
 *
 * @code
class ComponentConfig;
@endcode
 */
class ComponentConfig {
    /**
     * Site configuration directory.
     * Path to the directory, that contains configuration files for the component.
     * @var string SITE_CONFIG_DIR
     */
    const SITE_CONFIG_DIR = '/modules/%s/config/';

    /**
     * Core configuration directory.
     * Path to the directory, that contains configuration files for standard components.
     *
     * @var string CORE_CONFIG_DIR
     *
     * @note @c %s will be substituted to the module name, that contains the component.
     */
    const CORE_CONFIG_DIR = '/modules/%s/config/';

    /**
     * Configuration file.
     * @var \SimpleXMLElement $config
     */
    private $config = false;

    /**
     * Configuration of the current state.
     * @var \SimpleXMLElement $currentState
     */
    private $currentState = false;

    /**
     * Initialize configuration.
     *
     * @param mixed $config Configuration or configuration filename.
     * @param string $className Class name.
     * @param string $moduleName Module name.
     * @return ComponentConfig
     *
     * @throws SystemException 'ERR_DEV_BAD_CONFIG_FILE'
     * @throws SystemException 'ERR_DEV_STRANGE'
     */
    public function __construct($config, $className, $moduleName) {
        //Если это строка(с именем файла) или false
        if (!$config || is_string($config)) {
            $config = ($param = $this->getConfigPath($config, $moduleName)) ? $param
                    : $this->getConfigPath(simplifyClassName($className) . '.component.xml', $moduleName);
            //search in parents classes configs
            if(!$config){
                foreach(class_parents($className) as $tClass){
                    list(,$pModuleName,,$pClassName) = explode('\\', $tClass);
                    if(in_array($pClassName, ['DBDataSet', 'DataSet', 'Component'])){
                        break;
                    }
                    if($config = $this->getConfigPath(simplifyClassName($pClassName) . '.component.xml', $pModuleName)){
                        break;
                    }
                }
            }

            if ($config) {
                try {
                    // базовый конфиг (extends) ищется так же, как сам конфиг: файл проекта, сайт, модуль
                    $this->config = self::loadXml($config, self::baseResolver(fn($name) => $this->getConfigPath($name, $moduleName),
                        glob(CORE_DIR . '/modules/*/config', GLOB_ONLYDIR) ?: []));
                } catch (\RuntimeException $e) {
                    throw new SystemException($e->getMessage(), SystemException::ERR_DEVELOPER, $config);
                } catch (\Exception  $e) {
                    throw new SystemException('ERR_DEV_BAD_CONFIG_FILE', SystemException::ERR_DEVELOPER, $config);
                }
            }
        } //А может это конфиг из шаблона?
        elseif (is_a($config, 'SimpleXMLElement')) {
            $this->config = $config;
        } else {
            //Этого не может быть
            throw new SystemException('ERR_DEV_STRANGE', SystemException::ERR_DEVELOPER, func_get_args());
            //поскольку быть этого не может никогда
        }
    }

    /**
     * Поиск базового конфига для extends: рядом с текущим файлом, затем обычный поиск конфига компонента (файл проекта,
     * сайт, модуль компонента), затем конфиги всех модулей ядра. Сам текущий файл пропускается: конфиг сайта с тем же
     * именем, что у ядра (Foo.component.xml extends="Foo.component.xml"), наследует ядро, а не себя.
     *
     * @param callable $lookup имя => путь или false (обычный поиск)
     * @param string[] $coreDirs каталоги config модулей ядра
     */
    public static function baseResolver(callable $lookup, array $coreDirs): callable {
        return function (string $name, string $from) use ($lookup, $coreDirs) {
            $self = realpath($from);
            $candidates = array_merge([dirname($from) . '/' . $name, $lookup($name)],
                array_map(fn($dir) => rtrim($dir, '/') . '/' . $name, $coreDirs));
            foreach ($candidates as $candidate) {
                if ($candidate && is_file($candidate) && realpath($candidate) !== $self) {
                    return $candidate;
                }
            }
            return false;
        };
    }

    /**
     * Конфиг с наследованием: <configuration extends="Базовый.component.xml"> — берутся состояния базового (рекурсивно),
     * одноимённые заменяются на месте, новые добавляются в конец, <state name="…" remove="1"/> убирает состояние.
     * Порядок — как у базового: от него зависят веса шаблонов адресов.
     *
     * @param string $file путь к файлу конфига
     * @param callable $resolve (имя базового, путь текущего) => путь базового или false — см. baseResolver()
     * @param string[] $seen уже загруженные файлы цепочки (защита от цикла)
     * @throws \RuntimeException ERR_DEV_CONFIG_EXTENDS_LOOP, ERR_DEV_NO_BASE_CONFIG
     */
    public static function loadXml(string $file, callable $resolve, array $seen = []): \SimpleXMLElement {
        $real = realpath($file) ?: $file;
        if (in_array($real, $seen, true)) {
            throw new \RuntimeException('ERR_DEV_CONFIG_EXTENDS_LOOP: ' . implode(' → ', array_merge($seen, [$real])));
        }
        $doc = new \DOMDocument();
        if (!@$doc->load($file)) {
            throw new \Exception('ERR_DEV_BAD_CONFIG_FILE');
        }
        $root = $doc->documentElement;
        $extends = $root->getAttribute('extends');
        if ($extends === '') {
            return simplexml_import_dom($doc);
        }
        $baseFile = $resolve($extends, $file);
        if (!$baseFile) {
            throw new \RuntimeException('ERR_DEV_NO_BASE_CONFIG: ' . $extends);
        }
        $base = dom_import_simplexml(self::loadXml($baseFile, $resolve, array_merge($seen, [$real])))->ownerDocument;
        $baseRoot = $base->documentElement;
        $states = [];
        foreach ($baseRoot->childNodes as $node) {
            if ($node instanceof \DOMElement && $node->tagName === 'state') {
                $states[$node->getAttribute('name')] = $node;
            }
        }
        foreach ($root->childNodes as $node) {
            if (!$node instanceof \DOMElement || $node->tagName !== 'state') {
                continue;
            }
            $name = $node->getAttribute('name');
            if ($node->getAttribute('remove') === '1') {
                if (isset($states[$name])) {
                    $baseRoot->removeChild($states[$name]);
                    unset($states[$name]);
                }
                continue;
            }
            $copy = $base->importNode($node, true);
            if (isset($states[$name])) {
                $baseRoot->replaceChild($copy, $states[$name]);
            } else {
                $baseRoot->appendChild($copy);
            }
            $states[$name] = $copy;
        }
        return simplexml_import_dom($base);
    }

    /**
     * Get full path to the configuration file.
     *
     * It will return @c false if the file was not found.
     *
     * @param string $configFilename Configuration file name.
     * @param string $moduleName Module name.
     * @return string|bool
     */
    private function getConfigPath($configFilename, $moduleName) {
	    if(!$configFilename) {
		    return false;
	    }

        if (!file_exists($file = ROOT_DIR.'/'.$configFilename)) {
            //Смотрим в директории текущего сайта с пользовательскими конфигами
            if (!file_exists($file = sprintf(SITE_DIR . self::SITE_CONFIG_DIR . $configFilename, E()->getSiteManager()->getCurrentSite()->folder))) {
                if (!file_exists($file = sprintf(CORE_DIR . self::CORE_CONFIG_DIR, $moduleName) . $configFilename)) {
                    $file = false;
                }
            }
        }
        return $file;
    }

    /**
     * Set current state.
     *
     * @param string $methodName Method name.
     *
     * @throws SystemException 'ERR_NO_METHOD '
     */
    public function setCurrentState($methodName) {
        if (!($this->currentState = $this->getStateConfig($methodName))) {
            //inspect($this->c, $this->config->xpath(sprintf('/configuration/state[@name=\'%s\']', $methodName)));
            throw new SystemException('ERR_NO_METHOD ' . $methodName, SystemException::ERR_DEVELOPER, $methodName);
        }
    }

    /**
     * Register state.
     *
     * @param string $methodName Method name.
     * @param array|string $patterns Set of patterns.
     * @param bool|int $rights Rights.
     */
    protected function registerState($methodName, $patterns, $rights = false) {
        if ($this->config) {
            $newState = $this->config->addChild('state');
            $newState->addAttribute('name', $methodName);
            $newState->addAttribute('weight', true);
            if ($rights) {
                $newState->addAttribute('rights', $rights);
            }
            if (!is_array($patterns)) $patterns = array($patterns);
            $uriPatterns = $newState->addChild('uri_patterns');
            foreach ($patterns as $pattern) {
                $uriPatterns->addChild('pattern', $pattern);
            }
        }
    }

    /**
     * Get configuration of current state.
     *
     * @return \SimpleXMLElement
     */
    public function getCurrentStateConfig() {
        return $this->currentState;
    }

    /**
     * Check if configuration is empty.
     *
     * @return boolean
     */
    public function isEmpty() {
        return ($this->config) ? false : true;
    }

    /**
     * Get action name from configuration.
     * It based on URI request.
     *
     * @param string $path URI path.
     * @return array
     */
    public function getActionByURI($path) {
        $actionName = false;
        $actionParams = array();
        $path = '/' . $path;

        $patterns = array();
        //счетчик приоритета паттерна
        $weightInc = $maxWeightInc = sizeof($this->config->state);

        //Дальше идет что то мутное
        //наша цель расставиьт приоритеты паттернов состояний
        foreach ($this->config->state as $method) {
            if (isset($method->uri_patterns->pattern)) {

                $weightInc--;
                //А это счетчик приоритета внутри набора паттернов
                $maxPatternPriority = sizeof($method->uri_patterns->pattern) - 1;
                //вообщем в результате мы получаем что у нас приоритеты выставлены как нужно
                //то есть чем выше - тем важнее
                foreach ($method->uri_patterns->pattern as $pattern) {
                    $patterns[(string)$pattern] = array(
                        'method' => (string)$method['name'],
                        //'rights' => ((isset($method['rights']))?(int)$method['rights']),
                        'weight' => ((!isset($method['weight'])) ? ($weightInc + $maxPatternPriority * 0.1) : ($maxWeightInc++))
                    );
                    $maxPatternPriority--;
                }
            }
        }
        //сортируем  по приоритету
        uasort($patterns, function ($a, $b) {
            return $b['weight'] <=> $a['weight'];
        });

        foreach ($patterns as $pattern => $methodInfo) {
            $methodName = $methodInfo['method'];
            try {
                $resPattern = preg_replace(
                    array('/\[any\]\//', '/\//', '/\[[a-zA-Z_]+\]/'),
                    array('(.*)', '\/', '([^\/]+)'),
                    $pattern
                );
            } catch (\Exception $e) {
                $resPattern = $pattern;
            }
            $matches = array();

            if (preg_match($resPattern = "/^$resPattern$/", $path, $matches)) {
                $useSegments = sizeof(array_filter(explode('/', $pattern)));
                if ($useSegments) {
                    if (strpos($pattern, '[any]') !== false) {
                        $useSegments--;
                    }
                    E()->getRequest()->useSegments(E()->getRequest()->getUsedSegments() + $useSegments);
                }
                array_shift($matches);
                $actionName = $methodName;
                if (!empty($matches)) {
                    preg_match($resPattern, $pattern, $varNames);
                    array_shift($varNames);
                    $varNames = str_replace(array('[', ']'), '', $varNames);
                    $actionParams = array_combine($varNames, $matches);
                }

                break;
            }
        }

        if ($actionName == false) {
            return false;
        }

        return array('name' => $actionName, 'params' => $actionParams);
    }

    /**
     * Get state configuration for specific state.
     *
     * @param string $methodName Method name.
     * @return \SimpleXMLElement|false
     */
    public function getStateConfig($methodName) {
        $result = false;
        if (!$this->isEmpty()) {
            $methodConfig = $this->config->xpath(sprintf('state[@name=\'%s\'][parent::configuration]', $methodName));
            if (!empty($methodConfig)) {
                $result = $methodConfig[0];
            }
        }
        return $result;
    }

    /**
     * Get list of current state parameters from configuration file.
     *
     * @return array|bool
     */
    public function getCurrentStateParams() {
        $result = false;
        //Если уже задано текущее состояние
        // и конфиг не пуст
        //и в нем есть узел параметров
        //и в этом узле есть дочерние
        if ($this->currentState && !$this->isEmpty() && isset($this->currentState->params) && sizeof($this->currentState->params->children())) {
            $result = array();
            foreach ($this->currentState->params->param as $tagName => $param) {
                if (($tagName == 'param') && isset($param['name'])) {
                    $result[(string)$param['name']] = (string)$param;
                }
            }
        }
        return $result;
    }
}

