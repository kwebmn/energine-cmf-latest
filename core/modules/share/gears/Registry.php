<?php

/**
 * @file
 * E(), Registry.
 *
 * It contains the definition to:
 * @code
function E();
 * final class Registry;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2013
 *
 * @version 1.0.0
 */
namespace {
    /**
     * @fn E
     * @brief E[nergine].
     * Shortcut for Registry::getInstance.
     * @return Energine\share\gears\Registry
     */
    function E() {
        return Energine\share\gears\Registry::getInstance();
    }

}

namespace Energine\share\gears {
    // Подключаем предка напрямую
    require('Primitive.php');

    /**
     * Реестр приложения: по одному экземпляру объектов ядра на запрос.
     *
     * Объекты берутся типизированными методами (getDB(), getLanguage(), getUtils(), getUserGroup() …) — IDE и PHPStan
     * видят типы, опечатка в имени — ошибка, а не новый пустой объект. Магических __get/__set нет (надёжность, этап 4;
     * tests/registry.php следит, что обращений вида E()->Имя не осталось).
     *
     * @see Singleton
     *
     * @final
     */
    final class Registry extends Primitive implements \ArrayAccess {
        /**
         * Instance of this class.
         * @var Registry $instance
         */
        static private $instance = NULL;

        /**
         * List of stored objects in the registry.
         * @var array $entities
         */
        private $entities = [];

        /**
         * Flag for imitation the private constructor.
         * @var boolean $flag
         */
        private static $flag = NULL;

        /**
         * @throws \InvalidArgumentException
         */
        public function __construct() {
            if (is_null(self::$flag)) {
                throw new \InvalidArgumentException('This class could only be instantiated through "getInstance" method.');
            }
            self::$flag = NULL;
        }

        /**
         * Disable cloning.
         */
        private function __clone() {
        }

        /**
         * Get instance.
         *
         * @return Registry
         *
         * @final
         */
        final public static function getInstance() {
            if (is_null(self::$instance)) {
                self::$flag = true;
                self::$instance = new static;
            }
            return self::$instance;
        }

        /**
         * Утилиты: перевод, формат дат, работа с массивами.
         */
        public function getUtils(): Utils {
            return $this->offsetGet(Utils::class);
        }

        /**
         * Группы пользователей и их права.
         */
        public function getUserGroup(): UserGroup {
            return $this->offsetGet(UserGroup::class);
        }

        /**
         * Сведения о файлах репозитория (тип, размеры).
         */
        public function getFileRepoInfo(): FileRepoInfo {
            return $this->offsetGet(FileRepoInfo::class);
        }

        /**
         * Документ страницы ошибки.
         */
        public function getErrorDocument(): ErrorDocument {
            return $this->offsetGet(ErrorDocument::class);
        }

        /**
         * Документ структуры страницы (?struct).
         */
        public function getPageStructureDocument(): PageStructureDocument {
            return $this->offsetGet(PageStructureDocument::class);
        }

        /**
         * Сессия пользователя (cookie, хранилище сессий).
         */
        public function getUserSession(): UserSession {
            return $this->offsetGet(UserSession::class);
        }

        /**
         * Get AuthUser.
         */
        public function getUser(): AuthUser {
            return $this->offsetGet('Energine\\share\\gears\\AuthUser');
        }

        /**
         * Set AuthUser.
         *
         * @param AuthUser $anotherAuthUserObject AuthUser object.
         *
         * @throws \Exception 'AuthUser object is already used. You can not substitute it here.'
         */
        public function setUser(AuthUser $anotherAuthUserObject) {
            if (isset($this->entities['AuthUser'])) {
                throw new \Exception ('AuthUser object is already used. You can not substitute it here.');
            }
            $this->entities['AuthUser'] = $anotherAuthUserObject;
        }

        /**
         * Get Request.
         *
         * @return Request
         */
        public function getRequest(): Request {
            return $this->offsetGet('Energine\\share\\gears\\Request');
        }

        /**
         * Get Response.
         *
         * @return Response
         */
        public function getResponse(): Response {
            return $this->offsetGet('Energine\\share\\gears\\Response');
        }

        /**
         * Get Document.
         *
         * @return Document
         */
        public function getDocument(): Document {
            return $this->offsetGet('Energine\\share\\gears\\Document');
        }

        /**
         * Get Language.
         *
         * @return Language
         */
        public function getLanguage(): Language {
            return $this->offsetGet('Energine\\share\\gears\\Language');
        }

        /**
         * Get SiteManager.
         *
         * @return SiteManager
         */
        public function getSiteManager(): SiteManager {
            return $this->offsetGet('Energine\\share\\gears\\SiteManager');
        }

        /**
         * Дерево разделов сайта (одно на сайт).
         *
         * @return Sitemap
         */
        public function getMap(): Sitemap {
            if (!isset($this->entities['Sitemap'])) {
                $this->entities['Sitemap'] = new Sitemap();
            }
            return $this->entities['Sitemap'];
        }

        /**
         * Get DocumentController.
         *
         * @return DocumentController
         */
        public function getController(): DocumentController {
            if (!isset($this->entities['DocumentController'])) {
                return $this->setController();
            }
            return $this->entities['DocumentController'];
        }

        /**
         * @param $newDocumentController
         *
         * @return DocumentController
         */
        public function setController($newDocumentController = NULL): DocumentController {
            $path = 'Energine\\share\\gears\\';
            if ($newDocumentController && isset($this->entities['DocumentController'])) {
                throw new \InvalidArgumentException('Document controller is already defined.');
            }
            if (is_null($newDocumentController)) {
                $newDocumentController = 'DocumentController';
            }
            if (!(class_exists($newDocumentController) || class_exists($newDocumentController = $path . $newDocumentController))) {
                throw new \InvalidArgumentException("Class $newDocumentController not found");
            }

            $this->entities['DocumentController'] = new $newDocumentController;
            if (!is_a($this->entities['DocumentController'], $path . 'DocumentController')) {
                throw new \InvalidArgumentException('Class must be extended from ' . $path . 'DocumentController class.');
            }

            return $this->entities['DocumentController'];
        }

        /**
         * Get QAL.
         *
         * @return QAL
         */
        public function getDB(): QAL {
            if (!isset($this->entities['QAL'])) {
                // сокет сервера базы (database.socket) — если задан, иначе хост и порт
                $socket = $this->getConfigValue('database.socket');
                $this->entities['QAL'] = new QAL(
                    $socket
                        ? sprintf('mysql:unix_socket=%s;dbname=%s', $socket, $this->getConfigValue('database.db'))
                        : sprintf('mysql:host=%s;port=%s;dbname=%s',
                            $this->getConfigValue('database.host'),
                            $this->getConfigValue('database.port'),
                            $this->getConfigValue('database.db')
                        ),
                    $this->getConfigValue('database.username'),
                    $this->getConfigValue('database.password'),
                    [
                        \PDO::ATTR_PERSISTENT => (bool)$this->getConfigValue('database.persistent'),
                        \PDO::ATTR_EMULATE_PREPARES => true,
                        \Pdo\Mysql::ATTR_USE_BUFFERED_QUERY => true,
                        // PHP 8.1+ returns native int/float with emulated prepares, the code expects strings
                        \PDO::ATTR_STRINGIFY_FETCHES => true
                    ]
                );
                // отладка: тексты запросов попадают в XML страницы (?debug → document/queries)
                if ($this->getConfigValue('site.debug')) {
                    $this->entities['QAL']->logQueries(true);
                }
            }

            return $this->entities['QAL'];
        }

        /**
         * Переводы констант (одним запросом на язык).
         *
         * @return Translator
         */
        public function getTranslator(): Translator {
            if (!isset($this->entities['Translator'])) {
                $this->entities['Translator'] = new Translator($this->getDB());
            }
            return $this->entities['Translator'];
        }

        /**
         * Get Cache.
         *
         * @return Cache
         */
        public function getCache(): Cache {
            return $this->offsetGet('Energine\\share\\gears\\Cache');
        }

        /**
         * Whether a offset exists
         * @link http://php.net/manual/en/arrayaccess.offsetexists.php
         * @param mixed $entityName <p>
         * An offset to check for.
         * </p>
         * @return boolean true on success or false on failure.
         * </p>
         * <p>
         * The return value will be casted to boolean if non-boolean was returned.
         * @since 5.0.0
         */
        public function offsetExists($entityName): bool {
            return isset($this->entities[$entityName]);
        }

        /**
         * Offset to retrieve
         * @link http://php.net/manual/en/arrayaccess.offsetget.php
         * @param mixed $fullClassName <p>
         * The offset to retrieve.
         * </p>
         * @return mixed Can return all value types.
         * @since 5.0.0
         */
        public function offsetGet($fullClassName): mixed {
            $result = NULL;
            $c = explode('\\', $fullClassName);
            $className = array_pop($c);
            if(!sizeof($c)){
                $fullClassName = 'Energine\\share\\gears\\' . $className;
            }
            if (isset($this->entities[$className])) {
                $result = $this->entities[$className];
            } //поскольку предполагается хранить синглтоны, пробуем создать соответствующий класс ориентируясь на имя
            else {
                $result = new $fullClassName();
                $this->entities[$className] = $result;
            }
            return $result;
        }

        /**
         * Offset to set
         * @link http://php.net/manual/en/arrayaccess.offsetset.php
         * @param mixed $className <p>
         * The offset to assign the value to.
         * </p>
         * @param mixed $object <p>
         * The value to set.
         * </p>
         * @return void
         * @since 5.0.0
         */
        public function offsetSet($className, $object): void {
            if (!isset($this->entities[$className])) {
                $this->entities[$className] = $object;
            }
        }

        /**
         * Offset to unset
         * @link http://php.net/manual/en/arrayaccess.offsetunset.php
         * @param mixed $offset <p>
         * The offset to unset.
         * </p>
         * @return void
         * @since 5.0.0
         */
        public function offsetUnset($offset): void {
            // nothing to do
            //Manual unsetting is impossible
        }
    }
}