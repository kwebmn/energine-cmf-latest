<?php
/**
 * @file
 * Setup
 *
 * @code
final class Setup;
@endcode
 *
 * @author dr.Pavka
 * @copyright 2013 Energine
 *
 * @version 1.0.0
 */

require_once('JSqueeze.php');

/**
 * Main system setup.
 */
final class Setup {
    /**
     * Symlink mode  - for development
     */
    const MODE_SYMLINK = 'symlink';
    /**
     * Copy minified mode - for production
     */
    const MODE_COPY = 'copy';

    /**
     * Path to the directory for uploads.
     */
    const UPLOADS_PATH = 'uploads/public/';

    /**
     * Table name, where customer uploads are sotred.
     */
    const UPLOADS_TABLE = 'share_uploads';

    /**
     * Flag, that indicates that the installer was executed from console.
     *
     * States:
     * - @c true - executed from console
     * - @c false - executed from browser.
     *
     * @var bool $isFromConsole
     */
    private $isFromConsole;

    /**
     * System configurations.
     * @var array $config
     */
    private $config;

    /**
     * Array of directories, that will be created and where will be placed symbolic links from system core and site.
     * @var array $htdocsDirs
     */
    private $htdocsDirs = array(
        'images',
        'scripts',
        'stylesheets',
        'templates/content',
        'templates/icons',
        'templates/layout'
    );

    /**
     * PDO
     * @var PDO $dbConnect
     */
    private $dbConnect;

    /**
     * @param bool $consoleRun Is setup from console called?
     */
    public function __construct($consoleRun) {
        header('Content-Type: text/plain; charset=' . CHARSET);
        $this->title('Средство настройки CMF Energine');
        $this->isFromConsole = $consoleRun;
    }

    /**
     * Filter input arguments from potential attacks.
     * If input argument contain symbols except letters, numbers, @c "-", @c "." and @c "/" then exception error will be thrown.
     *
     * @param string $var Input argument.
     * @return string
     *
     * @throws Exception 'Некорректные данные системных переменных, возможна атака на сервер.'
     */
    private function filterInput($var) {
        if (preg_match('/^[\~\-0-9a-zA-Z\/\.\_]+$/i', $var))
            return $var;
        else
            throw new \Exception('Некорректные данные системных переменных, возможна атака на сервер.' . $var);
    }

    /**
     * Get site host name.
     *
     * @return string
     */
    private function getSiteHost() {
        if (!isset($_SERVER['HTTP_HOST'])
            || $_SERVER['HTTP_HOST'] == ''
        )
            return $this->filterInput($_SERVER['SERVER_NAME']);
        else
            return $this->filterInput($_SERVER['HTTP_HOST']);
    }

    /**
     * Get site root directory.
     *
     * @return string
     */
    private function getSiteRoot() {
        $siteRoot = $this->filterInput($_SERVER['PHP_SELF']);
        $siteRoot = str_replace('index.php', '', $siteRoot);
        return $siteRoot;
    }

    /**
     * Check system environment.
     * It checks:
     * - PHP version
     * - the presence of configuration file
     * - the presence of file with system modules.
     *
     * @throws Exception 'Вашему РНР нужно еще немного подрости. Минимальная допустимая версия '
     * @throws Exception 'Не найден конфигурационный файл system.config.php. По хорошему, он должен лежать в корне проекта.'
     * @throws Exception 'Странный какой то конфиг. Пользуясь ним я не могу ничего сконфигурить. Или возьмите нормальный конфиг, или - извините.'
     * @throws Exception 'В конфиге ничего не сказано о режиме отладки. Это плохо. Так я работать не буду.'
     * @throws Exception 'Нет. С отключенным режимом отладки я работать не буду, и не просите. Запускайте меня после того как исправите в конфиге ["site"]["debug"] с 0 на 1.'
     * @throws Exception 'Странно. Отсутствует перечень модулей. Я могу конечно и сам посмотреть, что находится в папке core/modules, но как то это не кузяво будет. '
     */
    public function checkEnvironment() {
        $this->title('Проверка системного окружения');


        //При любом действии без конфига нам не обойтись
        if (!file_exists($configName = implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, 'system.config.php')))) {
            throw new \Exception('Не найден конфигурационный файл system.config.php. По хорошему, он должен лежать в корне проекта.');
        }

        $this->config = include($configName);

        // Если скрипт запущен не с консоли, необходимо вычислить хост сайта и его рут директорию
        /*if (!$this->isFromConsole) {
            $this->config['site']['domain'] = $this->getSiteHost();
            $this->config['site']['root'] = $this->getSiteRoot();
        }*/
        //все вышеизложенное - очень подозрительно
        //что нам мешает просто прочитать значения из конфига?
        //Если бы мы потом это в конфиг писали - то еще куда ни шло ... а так ... до выяснения  - закомментировал

        if (!is_array($this->config)) {
            throw new \Exception('Странный какой то конфиг. Пользуясь ним я не могу ничего сконфигурить. Или возьмите нормальный конфиг, или - извините.');
        }

        //маловероятно конечно, но лучше убедиться
        if (!isset($this->config['site']['debug'])) {
            throw new \Exception('В конфиге ничего не сказано о режиме отладки. Это плохо. Так я работать не буду.');
        }
        $this->text('Конфигурационный файл подключен и проверен');

        //Если режим отладки отключен - то и говорить дальше не о чем
        if (!$this->isFromConsole && !$this->config['site']['debug']) {
            throw new \Exception('Нет. С отключенным режимом отладки я работать не буду, и не просите. Запускайте меня после того как исправите в конфиге ["site"]["debug"] с 0 на 1.');
        }
        if ($this->config['site']['debug']) {
            $this->text('Режим отладки включен');
        } else {
            $this->text('Режим отладки выключен');
        }

        //А задан ли у нас перечень модулей?
        if (!isset($this->config['modules']) && empty($this->config['modules'])) {
            throw new \Exception('Странно. Отсутствует перечень модулей. Я могу конечно и сам посмотреть, что находится в папке core/modules, но как то это не кузяво будет. ');
        }
        $this->text('Перечень модулей:', PHP_EOL . ' => ' . implode(PHP_EOL . ' => ', array_values($this->config['modules'])));
    }

    /**
     * Check connection to database.
     *
     * @throws Exception 'В конфиге нет информации о подключении к базе данных'
     * @throws Exception 'Удивительно, но не указан параметр: ' . $description . '  (["database"]["' . $key . '"])'
     * @throws Exception 'Не удалось соединиться с БД по причине: '
     */
    private function checkDBConnection() {

        $this->text('Проверяем коннект к БД');

        if (!isset($this->config['database']) || empty($this->config['database'])) {
            throw new \Exception('В конфиге нет информации о подключении к базе данных');
        }

        $dbInfo = $this->config['database'];

        //валидируем все скопом
        foreach (array('host' => 'адрес хоста', 'db' => 'имя БД', 'username' => 'имя пользователя', 'password' => 'пароль') as $key => $description) {
            if (!isset($dbInfo[$key]) && empty($dbInfo[$key])) {
                throw new \Exception('Удивительно, но не указан параметр: ' . $description . '  (["database"]["' . $key . '"])');
            }
        }
        try {
            //Поскольку ошибка при конструировании ПДО объекта генерит кроме исключения еще и варнинги
            //используем пустой обработчик ошибки с запретом всплывания(return true)
            //все это сделано только для того чтобы не выводился варнинг

            set_error_handler(function () { return true; });
            $connect = new PDO(
                // сокет (database.socket) — если задан, иначе хост и порт
                !empty($dbInfo['socket'])
                    ? sprintf('mysql:unix_socket=%s;dbname=%s', $dbInfo['socket'], $dbInfo['db'])
                    : sprintf(
                        'mysql:host=%s;port=%s;dbname=%s',

                        $dbInfo['host'],
                        (isset($dbInfo['port']) && !empty($dbInfo['port'])) ? $dbInfo['port'] : 3306,
                        $dbInfo['db']
                    ),
                $dbInfo['username'],
                $dbInfo['password'],
                array(
                    PDO::ATTR_PERSISTENT => false,
                    PDO::ATTR_EMULATE_PREPARES => true,
                    Pdo\Mysql::ATTR_USE_BUFFERED_QUERY => true
                ));

            $this->dbConnect = $connect;
        } catch (\Exception $e) {
            throw new \Exception('Не удалось соединиться с БД по причине: ' . $e->getMessage());
        }
        restore_error_handler();
        $connect->query('SET NAMES utf8');

        $this->text('Соединение с БД ', $dbInfo['db'], ' успешно установлено');
    }

    /**
     * Function that calls some class method.
     * In fact, it runs one of the system installation modes.
     *
     * @param string $action Method name.
     * @param array $arguments Method arguments.
     *
     * @throws Exception 'Подозрительно все это... Либо программисты че то не учли, либо.... произошло непоправимое.'
     */
    public function execute($action, $arguments) {
        if (!method_exists($this, $methodName = $action . 'Action')) {
            throw new \Exception('Подозрительно все это... Либо программисты че то не учли, либо.... произошло непоправимое.');
        }
        // установка и демо берут конфиг сами: при установке его ещё нет
        if (!in_array($action, ['install', 'demo'], true)) {
            $this->checkEnvironment();
        }
        call_user_func_array(array($this, $methodName), array_values($arguments));
        //$this->{$methodName}();
    }

    /**
     * Clear cache directory.
     * @todo: определится с именем папки
     */
    private function clearCacheAction() {
        $this->title('Очищаем кеш');
        $this->cleaner(implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, 'cache')));
    }

    /**
     * Установка в пустую базу (docs/INSTALL.md):
     * @code
     * php web/index.php setup install --admin-email=E-MAIL [--admin-name=ИМЯ] [--domain=ДОМЕН | --url=АДРЕС]
     *     [--db-host=ХОСТ] [--db-port=ПОРТ] [--db-socket=СОКЕТ] [--db-name=БАЗА] [--db-user=ЛОГИН]
     *     [--config=ФАЙЛ] [--no-static]
     * @endcode
     * Конфиг площадки: если его нет — пишется из шаблона (параметры --db-*, --domain или --url; режим 600;
     * по умолчанию configs/system.config.ДОМЕН.php и ссылка web/system.config.php), если есть — берётся он.
     * Пароли в аргументах не принимаются (их видно в списке процессов и в истории): пароль базы —
     * ENERGINE_DB_PASSWORD, администратора — ENERGINE_ADMIN_PASSWORD; без переменной — запрос с терминала
     * без эха. Всё проверяется до первого изменения базы: расширения, параметры, пароли, соединение,
     * пустота базы. Затем — схема и базовые данные (sql/structure.sql, sql/data.sql), администратор
     * в группе с полным доступом к корню, адрес сайта в share_domains, статика (без --no-static).
     */
    private function installAction(...$args) {
        $o = $this->options($args, ['config', 'domain', 'url', 'db-host', 'db-port', 'db-socket', 'db-name', 'db-user',
            'admin-email', 'admin-name'], ['no-static']);
        $this->title('Установка');
        $this->checkExtensions();

        $configFile = $o['config'] ?? implode(DIRECTORY_SEPARATOR, [HTDOCS_DIR, 'system.config.php']);
        $config = null;
        if (file_exists($configFile)) {
            $config = include $configFile;
            if (!is_array($config) || empty($config['database']) || !is_array($config['database'])) {
                throw new \Exception('В конфиге ' . $configFile . ' нет раздела database');
            }
            $database = $config['database'];
            $this->text('Конфиг площадки: ', $configFile);
        } else {
            foreach (['db-name', 'db-user'] as $key) {
                if (empty($o[$key])) {
                    throw new \Exception('Конфига площадки нет (' . $configFile . '): нужен параметр --' . $key);
                }
            }
            if (empty($o['domain']) && empty($o['url'])) {
                throw new \Exception('Конфига площадки нет (' . $configFile . '): нужен параметр --domain или --url');
            }
            $database = [
                'host' => $o['db-host'] ?? 'localhost',
                'port' => $o['db-port'] ?? '3306',
                'socket' => $o['db-socket'] ?? '',
                'db' => $o['db-name'],
                'username' => $o['db-user'],
                'password' => $this->secret('ENERGINE_DB_PASSWORD', 'пароль базы'),
            ];
        }
        $urls = $this->siteUrls($o, $config['site'] ?? []);
        // новый конфиг: указанный файл или configs/system.config.ДОМЕН.php и ссылка на него из web/
        $configTarget = null;
        if (!$config) {
            $configTarget = isset($o['config']) ? $configFile
                : implode(DIRECTORY_SEPARATOR, [ROOT_DIR, 'configs', 'system.config.' . $urls[0]['host'] . '.php']);
            if (file_exists($configTarget) || !is_writable(dirname($configTarget))) {
                throw new \Exception('Конфиг не записать: ' . $configTarget . ' уже есть или каталог закрыт для записи');
            }
        }
        $email = trim((string)($o['admin-email'] ?? ''));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new \Exception('Нужен корректный e-mail администратора: --admin-email=…');
        }
        $name = trim((string)($o['admin-name'] ?? '')) ?: 'Admin';
        $password = $this->secret('ENERGINE_ADMIN_PASSWORD', 'пароль администратора');

        $pdo = $this->connect($database);
        $tables = (int)$pdo->query('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()')->fetchColumn();
        $routines = (int)$pdo->query('SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()')->fetchColumn();
        if ($tables || $routines) {
            throw new \Exception(sprintf('База «%s» не пуста (таблиц: %d, процедур: %d): установка ставится только в пустую базу. '
                . 'Для новой установки очистите базу или укажите другую.', $database['db'], $tables, $routines));
        }
        $this->text('База «', $database['db'], '» пуста');

        if ($configTarget) {
            $this->writeConfig($configTarget, $database, $urls[0]);
            if ($configTarget !== $configFile) {
                symlink($configTarget, $configFile);
            }
            $this->text('Конфиг записан: ', $configTarget);
        }
        try {
            $this->text('Схема: ', $this->runSqlFile($pdo, ROOT_DIR . '/sql/structure.sql'), ' запросов');
            $this->text('Базовые данные: ', $this->runSqlFile($pdo, ROOT_DIR . '/sql/data.sql'), ' запросов');
            $this->createAdmin($pdo, $email, $name, $password);
            $this->text('Администратор: ', $email);
            $this->writeDomains($pdo, $urls);
        } catch (\Exception $e) {
            throw new \Exception('установка прервалась: ' . $e->getMessage() . PHP_EOL
                . 'База заполнена частично: очистите её (все таблицы и процедуры) и запустите установку снова.');
        }
        if (empty($o['no-static'])) {
            $this->config = include $configFile;
            $this->linkerAction();
            $this->scriptMapAction();
        }
        $this->text('Готово: ', $urls[0]['protocol'], '://', $urls[0]['host'],
            in_array($urls[0]['port'], [80, 443]) ? '' : ':' . $urls[0]['port'], $urls[0]['root']);
    }

    /**
     * Демо-контент simple.energine.org поверх свежей установки: sql/demo.sql и файлы sql/demo/uploads в web/uploads.
     * @code
     * php web/index.php setup demo [--config=ФАЙЛ] [--no-static]
     * @endcode
     */
    private function demoAction(...$args) {
        $o = $this->options($args, ['config'], ['no-static']);
        $this->title('Демо-контент');
        $configFile = $o['config'] ?? implode(DIRECTORY_SEPARATOR, [HTDOCS_DIR, 'system.config.php']);
        $config = file_exists($configFile) ? include $configFile : null;
        if (!is_array($config) || empty($config['database'])) {
            throw new \Exception('Нет конфига площадки (' . $configFile . '): сначала setup install');
        }
        $pdo = $this->connect($config['database']);
        try {
            $filled = (int)$pdo->query('SELECT (SELECT COUNT(*) FROM apps_news) + (SELECT COUNT(*) FROM share_textblocks)')->fetchColumn();
        } catch (\PDOException $e) {
            throw new \Exception('База не установлена: сначала setup install');
        }
        if ($filled) {
            throw new \Exception('В базе уже есть новости или тексты: демо ставится только на свежую установку');
        }
        $this->text('Демо: ', $this->runSqlFile($pdo, ROOT_DIR . '/sql/demo.sql'), ' запросов');
        if (empty($o['no-static'])) {
            $source = ROOT_DIR . '/sql/demo/uploads';
            $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($source, \FilesystemIterator::SKIP_DOTS));
            $n = 0;
            foreach ($files as $file) {
                $target = HTDOCS_DIR . '/uploads/' . substr($file->getPathname(), strlen($source) + 1);
                if (!is_dir(dirname($target))) {
                    mkdir(dirname($target), 0755, true);
                }
                copy($file->getPathname(), $target);
                $n++;
            }
            $this->text('Файлы демо: ', $n, ' в ', HTDOCS_DIR, '/uploads');
        }
    }

    /**
     * Параметры вида --имя=значение и флаги --имя. Незнакомый параметр — ошибка (значение не печатается:
     * в нём мог оказаться пароль).
     *
     * @param string[] $args
     * @param string[] $valued
     * @param string[] $flags
     * @return array
     */
    private function options(array $args, array $valued, array $flags) {
        $result = [];
        foreach ($args as $arg) {
            if (preg_match('/^--([a-z-]+)=(.*)$/s', (string)$arg, $m) && in_array($m[1], $valued, true)) {
                $result[$m[1]] = $m[2];
            } elseif (preg_match('/^--([a-z-]+)$/', (string)$arg, $m) && in_array($m[1], $flags, true)) {
                $result[$m[1]] = true;
            } elseif (preg_match('/^--[a-z-]*pass/i', (string)$arg)) {
                throw new \Exception('Пароли в аргументах не принимаются: ENERGINE_DB_PASSWORD, ENERGINE_ADMIN_PASSWORD');
            } else {
                throw new \Exception('Неизвестный параметр: ' . strtok((string)$arg, '='));
            }
        }

        return $result;
    }

    /**
     * Расширения PHP, без которых сайт не работает.
     */
    private function checkExtensions() {
        $missing = array_filter(['pdo_mysql', 'dom', 'xsl', 'simplexml', 'mbstring', 'gd', 'openssl', 'fileinfo'],
            fn($extension) => !extension_loaded($extension));
        if ($missing) {
            throw new \Exception('Нет расширений PHP: ' . implode(', ', $missing));
        }
        $this->text('Расширения PHP на месте');
    }

    /**
     * Пароль: из переменной окружения, иначе — с терминала без эха. Не печатается.
     *
     * @param string $variable
     * @param string $what
     * @return string
     */
    private function secret($variable, $what) {
        $value = getenv($variable);
        if (is_string($value) && $value !== '') {
            return $value;
        }
        if (function_exists('posix_isatty') && posix_isatty(STDIN)) {
            fwrite(STDERR, 'Введите ' . $what . ': ');
            shell_exec('stty -echo');
            $value = rtrim((string)fgets(STDIN), "\r\n");
            shell_exec('stty echo');
            fwrite(STDERR, PHP_EOL);
            if ($value !== '') {
                return $value;
            }
        }
        throw new \Exception('Не задан ' . $what . ': переменная окружения ' . $variable . ' или ввод с терминала');
    }

    /**
     * Соединение для установки: сокет (database.socket) или хост и порт.
     *
     * @param array $db
     * @return \PDO
     */
    private function connect(array $db) {
        $dsn = !empty($db['socket']) ? 'mysql:unix_socket=' . $db['socket']
            : 'mysql:host=' . ($db['host'] ?? 'localhost') . ';port=' . (($db['port'] ?? '') ?: 3306);
        try {
            return new \PDO($dsn . ';dbname=' . $db['db'] . ';charset=utf8mb4', (string)$db['username'], (string)$db['password'],
                [\PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION]);
        } catch (\PDOException $e) {
            throw new \Exception('Нет соединения с базой «' . $db['db'] . '»: ' . $e->getMessage());
        }
    }

    /**
     * Выполнить файл SQL, как это делает клиент mariadb: запросы до разделителя, DELIMITER меняет разделитель
     * (тела процедур), строки комментариев между запросами пропускаются. Строковые значения в файлах установки
     * однострочные (mariadb-dump экранирует переводы строк), так что разделитель в конце строки — конец запроса.
     *
     * @param \PDO $pdo
     * @param string $file
     * @return int сколько запросов выполнено
     */
    private function runSqlFile(\PDO $pdo, $file) {
        if (!is_readable($file)) {
            throw new \Exception('Нет файла ' . $file);
        }
        $delimiter = ';';
        $statement = '';
        $count = 0;
        foreach (file($file) as $number => $line) {
            $trimmed = trim($line);
            if ($statement === '') {
                if ($trimmed === '' || str_starts_with($trimmed, '--')) {
                    continue;
                }
                if (preg_match('/^DELIMITER\s+(\S+)$/i', $trimmed, $m)) {
                    $delimiter = $m[1];
                    continue;
                }
            }
            $statement .= $line;
            if (str_ends_with(rtrim($line), $delimiter)) {
                $sql = substr(rtrim($statement), 0, -strlen($delimiter));
                $statement = '';
                if (trim($sql) === '') {
                    continue;
                }
                try {
                    $pdo->exec($sql);
                } catch (\PDOException $e) {
                    throw new \Exception(basename($file) . ', строка ' . ($number + 1) . ': ' . $e->getMessage());
                }
                $count++;
            }
        }
        if (trim($statement) !== '') {
            throw new \Exception(basename($file) . ': незаконченный запрос в конце файла');
        }

        return $count;
    }

    /**
     * Конфиг площадки из шаблона: база и домен; режим 600.
     *
     * @param string $file
     * @param array $db
     * @param array $url
     */
    private function writeConfig($file, array $db, array $url) {
        $text = (string)file_get_contents(implode(DIRECTORY_SEPARATOR, [ROOT_DIR, 'configs', 'system.config.default.php']));
        $values = [
            "'host' => 'DB HOST NAME'" => "'host' => " . var_export((string)$db['host'], true),
            "'port' => '3306'" => "'port' => " . var_export((string)$db['port'], true),
            "'socket' => ''" => "'socket' => " . var_export((string)$db['socket'], true),
            "'db' => 'DB NAME'" => "'db' => " . var_export((string)$db['db'], true),
            "'username' => 'DB LOGIN'" => "'username' => " . var_export((string)$db['username'], true),
            "'password' => 'DB PASSWORD'" => "'password' => " . var_export((string)$db['password'], true),
            "'domain' => 'PROJECT DOMAIN NAME'" => "'domain' => " . var_export($url['host'], true),
        ];
        foreach ($values as $from => $to) {
            if (substr_count($text, $from) !== 1) {
                throw new \Exception('В шаблоне конфига нет строки ' . $from);
            }
            $text = str_replace($from, $to, $text);
        }
        $umask = umask(0077);
        $written = file_put_contents($file, $text);
        umask($umask);
        if ($written === false || !chmod($file, 0600)) {
            throw new \Exception('Конфиг не записан: ' . $file);
        }
    }

    /**
     * Адреса сайта для share_domains: --url — ровно он; --domain — http и https на стандартных портах;
     * без них — домен и корень из конфига площадки.
     *
     * @param array $o
     * @param array $site раздел site конфига
     * @return array[] protocol, host, port, root
     */
    private function siteUrls(array $o, array $site) {
        if (!empty($o['url'])) {
            $u = parse_url($o['url']);
            if (empty($u['host']) || !in_array($u['scheme'] ?? '', ['http', 'https'], true)) {
                throw new \Exception('Неверный --url: нужен http(s)://хост[:порт]/путь/');
            }
            $root = '/' . trim($u['path'] ?? '', '/');
            return [['protocol' => $u['scheme'], 'host' => $u['host'], 'port' => (int)($u['port'] ?? ($u['scheme'] === 'https' ? 443 : 80)),
                'root' => rtrim($root, '/') . '/']];
        }
        $host = (string)($o['domain'] ?? ($site['domain'] ?? ''));
        if (!preg_match('/^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$/i', $host)) {
            throw new \Exception('Неверный домен сайта: «' . $host . '» (--domain=…)');
        }
        $root = rtrim('/' . trim((string)($site['root'] ?? '/'), '/'), '/') . '/';

        return [['protocol' => 'http', 'host' => $host, 'port' => 80, 'root' => $root],
            ['protocol' => 'https', 'host' => $host, 'port' => 443, 'root' => $root]];
    }

    /**
     * Администратор — в группе с полным доступом к корню сайта.
     *
     * @param \PDO $pdo
     * @param string $email
     * @param string $name
     * @param string $password
     */
    private function createAdmin(\PDO $pdo, $email, $name, $password) {
        $group = $pdo->query('SELECT group_id FROM share_access_level WHERE right_id = 3
            AND smap_id = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL) ORDER BY group_id LIMIT 1')->fetchColumn();
        if (!$group) {
            throw new \Exception('в базовых данных нет группы с полным доступом к корню сайта');
        }
        $pdo->prepare('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)')
            ->execute([$email, password_hash($password, PASSWORD_DEFAULT), $name]);
        $pdo->prepare('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, ?)')->execute([$pdo->lastInsertId(), $group]);
    }

    /**
     * Адреса сайта — единственного сайта базовых данных.
     *
     * @param \PDO $pdo
     * @param array[] $urls
     */
    private function writeDomains(\PDO $pdo, array $urls) {
        $site = $pdo->query('SELECT site_id FROM share_sites ORDER BY site_id LIMIT 1')->fetchColumn();
        foreach ($urls as $u) {
            $pdo->prepare('INSERT INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES (?, ?, ?, ?)')
                ->execute([$u['protocol'], $u['port'], $u['host'], $u['root']]);
            $pdo->prepare('INSERT INTO share_domain2site (domain_id, site_id) VALUES (?, ?)')->execute([$pdo->lastInsertId(), $site]);
            $this->text('Адрес сайта: ', $u['protocol'], '://', $u['host'], ':', $u['port'], $u['root']);
        }
    }

    /**
     * Search and show untranslated constants.
     * To show the information about founded constants on the display use @code $mode='show' @endcode @n
     * To write the information about founded constants into the file use @code $mode='file' @endcode @n
     *
     * @param string $mode Display mode.
     *
     * @throws Exception 'Режим ' . $mode . ' не зарегистрирован'
     */
    private function untranslatedAction($mode = 'show') {
        $this->title('Поиск непереведенных констант');
        $this->checkDBConnection();

        $all = array_merge(
            $this->getTransEngineCalls(),
            $this->getTransXmlCalls()
        );
        $result = $this->getUntranslated($all);
        if ($result) {
            //todo VZ: I think switch is better.
            if ($mode == 'show') {
                foreach ($result as $key => $val) {
                    $this->text($key . ': ' . implode(', ', $val['file']));
                }
            } elseif ($mode = 'file') {
                $this->writeTranslations($this->fillTranslations($result), 'untranslated.csv');
            } else {
                throw new \Exception('Режим ' . $mode . ' не зарегистрирован');
            }
        } else {
            $this->text('Все в порядке, все языковые константы переведены');
        }


    }

    /**
     * Export translation constants into the file.
     */
    private function exportTransAction() {
        $this->title('Экспорт констант в файлы');
        $this->checkDBConnection();
        $all = array_merge(
            $this->getTransEngineCalls(),
            $this->getTransXmlCalls()
        );
        $this->writeTranslations($this->fillTranslations($all));
    }

    /**
     * Load data from the file with translations.
     * File format: "Translation";"abbreviation 1";"abbreviation 2"
     *
     * @param string $path Path.
     * @param string $module Module name.
     *
     * @throws Exception 'Не видать файла:' . $path
     * @throws Exception 'Файл вроде как есть, а вот читать из него невозможно.'
     */
    private function loadTransFileAction($path, $module = 'share') {
        $this->title('Загрузка файла с переводами: ' . $path . ' в модуль ' . $module);
        if (!file_exists($path)) {
            throw new \Exception('Не видать файла:' . $path);
        }
        $row = 0;
        $loadedRows = 0;

        if (($handle = fopen($path, 'r')) !== FALSE) {
            $this->checkDBConnection();
            $langRes = $this->dbConnect->prepare('SELECT lang_id FROM share_languages WHERE lang_abbr= ?', array(PDO::ATTR_CURSOR => PDO::CURSOR_SCROLL));
            $langTagRes = $this->dbConnect->prepare('INSERT IGNORE INTO share_lang_tags(ltag_name) VALUES (?)');
            $langTransTagRes = $this->dbConnect->prepare('INSERT IGNORE INTO share_lang_tags_translation VALUES (?, ?, ?)');
            $this->dbConnect->beginTransaction();
            $langInfo = array();
            try {
                while (($data = fgetcsv($handle, 1000, ";", escape: '\\')) !== FALSE) {
                    //На первой строчке определяемся с языками
                    if (!($row++)) {
                        //Отбрасываем первую колонку - Имя
                        array_shift($data);
                        foreach ($data as $langNum => $langAbbr) {
                            if (!$langRes->execute(array(strtolower($langAbbr)))) {
                                throw new \Exception('Что то опять не слава Богу.');
                            }
                            //Создаем масив соответствия порядкового номера колонки - идентификатору языка
                            $langInfo[$langNum + 1] = $langRes->fetch(PDO::FETCH_COLUMN);
                        }
                    } else {

                        if ($r = !$langTagRes->execute(array($data[0]))) {
                            throw new \Exception('Произошла ошибка при вставке в share_lang_tags значения:' . $data[0]);
                        }
                        $ltagID = $this->dbConnect->lastInsertId();
                        if ($ltagID) {
                            $this->text('Пишем в основную таблицу: ' . $ltagID . ', ' . $data[0]);
                            $loadedRows++;
                            foreach ($langInfo as $langNum => $langID) {
                                if (!$langTransTagRes->execute(array($ltagID, $langID, stripslashes($data[$langNum])))) {
                                    throw new \Exception('Произошла ошибка при вставке в share_lang_tags_translation значения:' . $data[$langNum]);
                                }
                                $this->text('Пишем в таблицу переводов: ' . $ltagID . ', ' . $langID . ', ' . $data[$langNum]);
                            }
                        } else {
                            $this->text('Такая константа уже существует: ' . $data[0] . '- пропускаем.');
                        }
                    }
                }
                $this->dbConnect->commit();
            } catch (\Exception $e) {
                $this->dbConnect->rollBack();
                throw $e;
            }
            fclose($handle);
        } else {
            throw new \Exception('Файл вроде как есть, а вот читать из него невозможно.');
        }


        $this->text('Загружено ' . ($loadedRows) . ' значений');
    }

    /**
     * Get an array with information about translations.
     *
     * @param array $transData Translation data.
     * @return mixed
     */
    private function fillTranslations($transData) {
        array_walk($transData,
            function (&$transInfo, $transConst, $findTransRes) {
                if ($findTransRes->execute(array($transConst))) {
                    if ($data = $findTransRes->fetchAll(PDO::FETCH_ASSOC)) {
                        foreach ($data as $row) {
                            $transInfo['data'][$row['lang_id']] = $row['ltag_value_rtf'];
                        }

                    }
                }
            },
            $this->dbConnect->prepare('select ltag_value_rtf, lang_id FROM share_lang_tags_translation LEFT JOIN share_lang_tags USING(ltag_id) WHERE ltag_name=?')
        );
        return $transData;
    }

    /**
     * Search constants in XML-file.
     *
     * @return array
     */
    private function getTransXmlCalls() {
        $output = array();

        $result = [];

        $files = array_merge(
            glob(CORE_DIR . '/modules/*/config/*.xml'),
            glob(CORE_DIR . '/modules/*/templates/content/*.xml'),
            glob(CORE_DIR . '/modules/*/templates/layout/*.xml'),
            glob(SITE_DIR . '/modules/*/config/*.xml'),
            glob(SITE_DIR . '/modules/*/templates/content/*.xml'),
            glob(SITE_DIR . '/modules/*/templates/layout/*.xml')
        );

        if ($files)
            foreach ($files as $file) {
                $doc = new \DOMDocument();
                $doc->preserveWhiteSpace = false;
                $doc->load($file);
                $xpath = new DOMXPath($doc);

                // находим теги translation
                $nl = $xpath->query('//translation');
                if ($nl->length > 0)
                    foreach ($nl as $node)
                        if ($node instanceof DOMElement)
                            $result[$file][] = $node->getAttribute('const');

                // находим теги control
                $nl = $xpath->query('//control');
                if ($nl->length > 0)
                    foreach ($nl as $node)
                        if ($node instanceof DOMElement)
                            $result[$file][] = $node->getAttribute('title');

                // находим теги field
                $nl = $xpath->query('//field');
                if ($nl->length > 0)
                    foreach ($nl as $node)
                        if ($node instanceof DOMElement)
                            $result[$file][] = 'FIELD_' . strtoupper($node->getAttribute('name'));
            }

        if ($result) {
            foreach ($result as $file => $res) {
                foreach ($res as $key => $line) {
                    if (isset($output[$line]['count'])) {
                        $output[$line]['count']++;
                        if (!in_array($file, $output[$line]['file']))
                            $output[$line]['file'][] = $file;
                    } else {
                        $output[$line]['count'] = 1;
                        $output[$line]['file'][] = $file;
                    }
                }
            }
        }

        return $output;
    }

    /**
     * Get untranslated constants.
     *
     * @param array $data %Data.
     * @return array
     */
    private function getUntranslated($data) {
        $result = array();
        $dbRes = $this->dbConnect->prepare('SELECT ltag_id FROM share_lang_tags WHERE ltag_name=?');

        if ($data) {
            foreach ($data as $const => $val) {
                if (!$const) continue;
                if ($dbRes->execute(array($const))) {
                    $res = $dbRes->fetchColumn();
                    if (empty($res))
                        $result[$const] = $val;
                }
            }
        }

        return $result;
    }

    /**
     * Search constants in the code.
     *
     * @return array
     */
    private function getTransEngineCalls() {
        $output = array();
        $result = [];

        $dirIterators = new AppendIterator();
        $dirIterators->append(new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator(
                CORE_DIR,
                \FilesystemIterator::FOLLOW_SYMLINKS
            )
        ));
        $dirIterators->append(new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator(
                SITE_DIR,
                \FilesystemIterator::FOLLOW_SYMLINKS
            )
        ));

        $files = new RegexIterator(
            $dirIterators,
            '/^.+\.php$/i',
            RecursiveRegexIterator::GET_MATCH
        );

        /*
         * что ищем:
         * ->addTranslation('CONST'[, 'CONST', ..])
         * ->translate('CONST')
         * System Exception('CONST')
         */
            foreach ($files as $file) {
                list($file) = $file;

                $content = file_get_contents($file);

                if (is_array($content))
                    $content = join('', $content);

                $r = array();
                //Ищем в методе динамического добавления переводов
                if (preg_match_all('/addTranslation\(([\'"]+([_A-Z0-9]+)[\'"]+([ ]{0,}[,]{1,1}[ ]{0,}[\'"]+([_A-Z0-9]+)[\'"]){0,})\)/', $content, $r) > 0) {
                    if ($r and isset($r[1])) {
                        foreach ($r[1] as $string) {
                            $string = str_replace(array('"', "'", " "), '', $string);
                            $consts = explode(',', $string);
                            if ($consts) {
                                foreach ($consts as $const) {
                                    $result[$file][] = $const;
                                }
                            }
                        }
                    }
                }
                //Ищем в обращениях за переводами
                if (preg_match_all('/->translate\([\'"]+([_A-Z0-9]+)[\'"]+\)/', $content, $r) > 0) {
                    if ($r and isset($r[1])) {
                        foreach ($r[1] as $row) {
                            $result[$file][] = $row;
                        }
                    }
                }
                //Ищем в текстах ошибок
                if (preg_match_all('/new SystemException\([\'"]+([_A-Z0-9]+)[\'"]+\)/', $content, $r) > 0) {
                    if ($r and isset($r[1])) {
                        foreach ($r[1] as $row) {
                            $result[$file][] = $row;
                        }
                    }
                }
            }

        if ($result) {
            foreach ($result as $file => $res) {
                foreach ($res as $key => $line) {

                    if (isset($output[$line]['count'])) {
                        $output[$line]['count']++;
                        if (!in_array($file, $output[$line]['file']))
                            $output[$line]['file'][] = $file;
                    } else {
                        $output[$line]['count'] = 1;
                        $output[$line]['file'][] = $file;
                    }
                }
            }
        }
        return $output;
    }

    /**
     * Write translation data into the file (for each module).
     *
     * @param array $data %Data.
     * @param string $transFileName Filename with translations.
     *
     * @throws Exception 'Директория ' . $dirName . ' отсутствует или недоступна для записи.'
     * @throws Exception 'Произошла ошибка при записи в файл: '
     */
    private function writeTranslations($data, $transFileName = 'translations.csv') {
        $langRes = $this->dbConnect->query('SELECT lang_id, lang_abbr FROM share_languages');
        while ($row = $langRes->fetch(PDO::FETCH_ASSOC)) {
            $langData[$row['lang_id']] = $row['lang_abbr'];
        }


        //$rows[] = 'CONST;' . implode(';', $langData);
        //Формируем массив вида [тип_модуля][имя_модуля]=>array("Имя константы; Перевод 1; Перевод 2")
        foreach ($data as $ltagName => $ltagInfo) {
            //Берем только первый файл, все остальные вхождения нам не сильно интересны
            $fileName = str_replace(HTDOCS_DIR, '', $ltagInfo['file'][0]);

            if (preg_match('/\/([a-z]+)\/modules\/([a-z]+)\//', $fileName, $matches)) {

                $row = array($ltagName);
                foreach (array_keys($langData) as $langID) {
                    array_push($row, (isset($ltagInfo['data'][$langID])) ? ('"' . addslashes(str_replace("\r\n", '\r\n', $ltagInfo['data'][$langID])) . '"') : '');
                }
                $rows[$matches[1]][$matches[2]][] = implode(';', $row);
            }
        }

        //Пишем в файлы данные массива
        foreach ($rows as $moduleType => $modulesInfo) {
            //Не используем  константы CORE_REL_DIR/SITE_REL_DIR поскольку там могут быть пути
            if ($moduleType == 'core') {
                $filePath = CORE_DIR;
            } elseif ($moduleType == 'site') {
                $filePath = SITE_DIR;
            }
            $filePath .= '/modules/%s/install/';

            foreach ($modulesInfo as $moduleName => $data) {
                if (!file_exists($dirName = sprintf($filePath, $moduleName)) || !is_writable($dirName)) {
                    throw new \Exception('Директория ' . $dirName . ' отсутствует или недоступна для записи.');
                }
                array_unshift($data, 'CONST;' . implode(';', $langData));

                if (!file_put_contents($dirName . $transFileName, implode("\r\n", $data))) {
                    throw new \Exception('Произошла ошибка при записи в файл: ' . $dirName . $transFileName . '.');
                }
                $this->text('Записываем в файл ' . $dirName . $transFileName . ' (' . sizeof($data) . ')');

            }
        }

    }

    /**
     * Create segment <tt>Google sitemap</tt> into @c share_sitemap.
     * It sets for that segment read-only access for non-authorized users. @n
     * Segment name should be defined in configurations.
     */
    private function createSitemapSegment() {
        $this->dbConnect->query('INSERT INTO share_sitemap(site_id,smap_layout,smap_content,smap_segment,smap_pid) '
            . 'SELECT sso.site_id,\'' . $this->config['seo']['sitemapTemplate'] . '.layout.xml\','
            . '\'' . $this->config['seo']['sitemapTemplate'] . '.content.xml\','
            . '\'' . $this->config['seo']['sitemapSegment'] . '\','
            . '(SELECT smap_id FROM share_sitemap ss2 WHERE ss2.site_id = sso.site_id AND smap_pid IS NULL LIMIT 0,1) '
            . 'FROM share_sites sso '
            . 'WHERE NOT FIND_IN_SET(\'NOINDEX\', site_meta_robots) AND site_is_active '
            . 'AND (SELECT COUNT(ssi.site_id) FROM share_sites ssi '
            . 'INNER JOIN share_sitemap ssm ON ssi.site_id = ssm.site_id '
            . 'WHERE ssm.smap_segment = \'' . $this->config['seo']['sitemapSegment'] . '\' AND ssi.site_id = sso.site_id) = 0');
        $smIdsInfo = $this->dbConnect->query('SELECT smap_id FROM share_sitemap WHERE '
            . 'smap_segment = \'' . $this->config['seo']['sitemapSegment'] . '\'');
        while ($smIdInfo = $smIdsInfo->fetch()) {
            $this->dbConnect->query('INSERT INTO share_access_level SELECT ' . $smIdInfo[0] . ',group_id,'
                . '(SELECT right_id FROM `user_group_rights` WHERE right_const = \'ACCESS_READ\') FROM `user_groups` ');
            $this->dbConnect->query('INSERT INTO share_sitemap_translation(smap_id,lang_id,smap_name,smap_is_disabled) '
                . 'VALUES (' . $smIdInfo[0] . ',(SELECT lang_id FROM `share_languages` WHERE lang_default),\'Google sitemap\',0)');
        }
    }

    /**
     * Generate symlinks.
     *
     * @throws Exception 'Не существует: ' . $module_path
     * @throws Exception 'Нет доступа на запись: ' . $modules_dir
     */
    private function linkerAction() {

        $this->title('Связывание данных модулей ');

        foreach ($this->htdocsDirs as $dir) {
            $dir = HTDOCS_DIR . DIRECTORY_SEPARATOR . $dir;

            if (!file_exists($dir)) {
                if (!@mkdir($dir, 0755, true)) {
                    throw new \Exception('Невозможно создать директорию:' . $dir);
                }
            } else {
                $this->cleaner($dir);
            }
        }

        // создаем симлинки модулей из их физического расположения, описанного в конфиге
        // в папку CORE_DIR . '/modules/'
        $this->text(PHP_EOL . 'Создание символических ссылок в ' . CORE_DIR . ':');
        foreach ($this->config['modules'] as $module => $module_path) {
            $symlinked_dir = implode(DIRECTORY_SEPARATOR, array(CORE_DIR, MODULES, $module));

            // ядро и проект в одном репозитории: модуль уже лежит там, куда вела бы ссылка
            if (is_dir($symlinked_dir) && !is_link($symlinked_dir)
                && realpath($symlinked_dir) === realpath($module_path)) {
                $this->text('Модуль на месте: ', $symlinked_dir);
                continue;
            }

            $this->text('Создание символической ссылки ', $module_path, ' -> ', $symlinked_dir);

            if (file_exists($symlinked_dir) || is_link($symlinked_dir)) {
                unlink($symlinked_dir);
            }

            if (!file_exists($module_path)) {
                throw new \Exception('Не существует: ' . $module_path);
            }

            $modules_dir = implode(DIRECTORY_SEPARATOR, array(CORE_DIR, MODULES));
            if (!is_writeable($modules_dir)) {
                throw new \Exception('Нет доступа на запись: ' . $modules_dir);
            }

            symlink($module_path, $symlinked_dir);

        }

        //На этот момент у нас есть все необходимые директории в htdocs и они пустые
        foreach ($this->htdocsDirs as $dir) {

            $this->text(PHP_EOL . 'Обработка ' . $dir . ':');
            //сначала проходимся по модулям ядра
            foreach (array_reverse($this->config['modules']) as $module => $module_path) {
                $this->linkCore(
                    ($this->config['site']['debug'])?self::MODE_SYMLINK:self::MODE_COPY,
                    implode(DIRECTORY_SEPARATOR, array(CORE_DIR, MODULES, $module, $dir, '*')),
                    implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, $dir)),
                    sizeof(explode(DIRECTORY_SEPARATOR, $dir)));

            }
            $this->linkSite(
                ($this->config['site']['debug'])?self::MODE_SYMLINK:self::MODE_COPY,
                implode(DIRECTORY_SEPARATOR, array(SITE_DIR, MODULES, '*', $dir, '*')),
                implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, $dir))
            );
        }

        $this->text('Символические ссылки расставлены');
    }

    /**
     * Iterate over uploads.
     *
     * @param string $directory Directory.
     * @param null|int $PID Parent ID.
     *
     * @throws Exception 'ERROR'
     * @throws Exception 'ERROR INSERTING'
     * @throws Exception 'ERROR UPDATING'
     */
    private function iterateUploads($directory, $PID = null) {

        //static $counter = 0;

        $iterator = new DirectoryIterator($directory);
        foreach ($iterator as $fileinfo) {
            if (!$fileinfo->isDot() && (substr($fileinfo->getFilename(), 0, 1) != '.')) {

                $uplPath = str_replace('../', '', $fileinfo->getPathname());
                $filename = $fileinfo->getFilename();

                echo $uplPath . PHP_EOL;
                $res = $this->dbConnect->query('SELECT upl_id, upl_pid FROM ' . self::UPLOADS_TABLE . ' WHERE upl_path = "' . $uplPath . '"');
                if (!$res) throw new \Exception('ERROR');

                $data = $res->fetch(\PDO::FETCH_ASSOC);

                if (empty($data)) {
                    $uplWidth = $uplHeight = 'NULL';
                    if (!$fileinfo->isDir()) {
                        $childsCount = 'NULL';
                        $finfo = new finfo(FILEINFO_MIME_TYPE);
                        $mimeType = $finfo->file($fileinfo->getPathname());

                        switch ($mimeType) {
                            case 'image/jpeg':
                            case 'image/png':
                            case 'image/gif':
                                $tmp = getimagesize($fileinfo->getPathname());
                                $internalType = 'image';
                                $uplWidth = $tmp[0];
                                $uplHeight = $tmp[1];
                                break;
                            case 'text/csv':
                                $internalType = 'text';
                                break;
                            case 'application/zip':
                                $internalType = 'zip';
                                break;
                            default:
                                $internalType = 'unknown';
                                break;
                        }
                        $title = $fileinfo->getBasename('.' . $fileinfo->getExtension());
                    } else {
                        $mimeType = 'unknown/mime-type';
                        $internalType = 'folder';
                        $childsCount = 0;
                        $title = $fileinfo->getBasename();
                    }

                    $PID = (empty($PID)) ? 'NULL' : $PID;

                    $r = $this->dbConnect->query($q = sprintf('INSERT INTO ' . self::UPLOADS_TABLE . ' (upl_pid, upl_childs_count, upl_path, upl_filename, upl_name, upl_title,upl_internal_type, upl_mime_type, upl_width, upl_height) VALUES(%s, %s, "%s", "%s", "%s", "%s", "%s", "%s", %s, %s)', $PID, $childsCount, $uplPath, $filename, $title, $title, $internalType, $mimeType, $uplWidth, $uplHeight));
                    if (!$r) throw new \Exception('ERROR INSERTING');
                    //$this->text($uplPath);
                    if ($fileinfo->isDir()) {
                        $newPID = $this->dbConnect->lastInsertId();
                    }

                    //$this->dbConnect->lastInsertId();
                } else {
                    $newPID = $data['upl_pid'];
                    $r = $this->dbConnect->query('UPDATE ' . self::UPLOADS_TABLE . ' SET upl_is_active=1 WHERE upl_id="' . $data['upl_id'] . '"');
                    if (!$r) throw new \Exception('ERROR UPDATING');
                }
                if ($fileinfo->isDir()) {
                    $this->iterateUploads($fileinfo->getPathname(), $newPID);
                }

            }
        }
    }

    /**
     * Synchronize uploads.
     *
     * @param string $uploadsPath Path to the uploads.
     *
     * @throws Exception 'Репозиторий по такому пути не существует'
     * @throws Exception 'Странный какой то идентификатор родительский.'
     */
    private function syncUploadsAction($uploadsPath = self::UPLOADS_PATH) {
        $this->checkDBConnection();
        $this->title('Синхронизация папки с загрузками');
        $this->dbConnect->beginTransaction();
        if (substr($uploadsPath, -1) == '/') {
            $uploadsPath = substr($uploadsPath, 0, -1);
        }
        $r = $this->dbConnect->query('SELECT upl_id FROM ' . self::UPLOADS_TABLE . ' WHERE upl_path LIKE "' . $uploadsPath . '"');
        if (!$r) {
            throw new \Exception('Репозиторий по такому пути не существует');
        }
        $PID = $r->fetchColumn();
        if (!$PID) {
            throw new \Exception('Странный какой то идентификатор родительский.');
        }
        $uploadsPath .= '/';

        try {
            $this->dbConnect->query('UPDATE ' . self::UPLOADS_TABLE . ' SET upl_is_active=0 WHERE upl_path LIKE "' . $uploadsPath . '%"');
            $this->iterateUploads(implode(DIRECTORY_SEPARATOR, array(HTDOCS_DIR, $uploadsPath)), $PID);
            $this->dbConnect->commit();
        } catch (\Exception $e) {
            $this->dbConnect->rollBack();
            throw new \Exception($e->getMessage());
        }
    }

    /**
     * Recursive clean directory.
     *
     * @param string $dir Path to the directory.
     */
    private function cleaner($dir) {
        if (is_dir($dir)) {
            if ($dh = opendir($dir)) {
                while ((($file = readdir($dh)) !== false)) {
                    if (!in_array($file, array('.', '..'))) {
                        if (is_dir($file = $dir . DIRECTORY_SEPARATOR . $file)) {
                            if (is_link($file)) {
                                unlink($file);
                            } else {
                                $this->cleaner($file);
                                rmdir($file);
                            }
                            $this->text('Удаляем директорию ', $file);
                        } else {
                            $this->text('Удаляем файл ', $file);
                            unlink($file);
                        }
                    }
                }
                closedir($dh);
            }
        }
    }

    //todo VZ: $level is not used.
    /**
     * Create symlinks for core modules.
     *
     * @param string $mode Mode.
     * @param string $globPattern File selection pattern.
     * @param string $module Path to the core module.
     * @param int $level Depth level for relative paths.
     *
     * @throws Exception 'Не удалось создать символическую ссылку'
     */
    private function linkCore($mode, $globPattern, $module, $level = 1) {
        $JSMIn = new JSqueeze();
        $fileList = glob($globPattern);

        if (!empty($fileList)) {
            foreach ($fileList as $fo) {
                if (is_dir($fo)) {
                    $dir = $module . DIRECTORY_SEPARATOR . basename($fo);
                    if (!file_exists($dir)) {
                        mkdir($dir);
                        $this->text('Создаем директорию ', $dir);
                    }
                    $this->linkCore($mode, $fo . DIRECTORY_SEPARATOR . '*', $dir, $level + 1);
                } else {
                    //Если одним из низших по приоритету модулей был уже создан симлинк
                    //то затираем его нафиг
                    if (file_exists($dest = $module . DIRECTORY_SEPARATOR . basename($fo))) {
                        unlink($dest);
                    }

                    switch ($mode) {
                        case self::MODE_SYMLINK:
                            $this->text('Создаем симлинк ', $fo, ' --> ', $dest);
                            if (!@symlink($fo, $dest)) {
                                throw new \Exception('Не удалось создать символическую ссылку с ' . $fo . ' на ' . $dest);
                            }
                            break;
                        case self::MODE_COPY:
                            $pi = pathinfo($fo);

                            if (isset($pi['extension']) && ($pi['extension'] == 'js')) {

                                if (
                                    (strpos($pi['filename'], 'mootools') === false)
                                    &&
                                    (strpos($pi['filename'], 'mootools-more') === false)
                                    &&
                                    (strpos($pi['filename'], 'mootools-ext') === false)
                                    &&
                                    (strpos($pi['dirname'], 'jodit') === false)
                                    &&
                                    (strpos($pi['dirname'], 'codemirror') === false)

                                ) {
                                    $this->text('Минифицируем и копируем ', $fo, ' --> ', $dest);
                                    file_put_contents($dest, $JSMIn->squeeze(file_get_contents($fo), true, false, false));
                                } else {
                                    $this->text('Создаем символическую ссылку ', $fo, ' --> ', $dest);
                                    if (!@symlink($fo, $dest)) {
                                        throw new \Exception('Не удалось создать символическую ссылку с ' . $fo . ' на ' . $dest);
                                    }
                                }

                            } else {
                                $this->text('Создаем символическую ссылку ', $fo, ' --> ', $dest);
                                if (!@symlink($fo, $dest)) {
                                    throw new \Exception('Не удалось создать символическую ссылку с ' . $fo . ' на ' . $dest);

                                }
                            }
                            break;
                    }
                }
            }
        }
    }

    /**
     * Create symlinks for site modules.
     *
     * @param string $mode Mode.
     * @param string $globPattern File selection pattern.
     * @param string $dir Directory where symlinks will be created.
     *
     * @throws Exception 'Не удалось создать символическую ссылку'
     */
    private function linkSite($mode, $globPattern, $dir) {
        $JSMin = new JSqueeze();

        $fileList = glob($globPattern);
        if (!empty($fileList)) {
            foreach ($fileList as $fo) {

                $fo_stripped = str_replace(SITE_DIR, '', $fo);
                list(, , $module) = explode(DIRECTORY_SEPARATOR, $fo_stripped);
                $new_dir = implode(DIRECTORY_SEPARATOR, array($dir, $module));

                if (!file_exists($new_dir)) {
                    mkdir($new_dir);
                }

                $srcFile = $fo;
                $linkPath = implode(DIRECTORY_SEPARATOR, array($dir, $module, basename($fo_stripped)));

                switch ($mode) {
                    case self::MODE_SYMLINK:
                        $this->text('Создаем симлинк ', $srcFile, ' --> ', $linkPath);
                        if (!@symlink($srcFile, $linkPath)) {
                            throw new \Exception('Не удалось создать символическую ссылку с ' . $srcFile . ' на ' . $linkPath);
                        }
                        break;
                    case self::MODE_COPY:
                        $pi = pathinfo($srcFile);

                        if (isset($pi['extension']) && ($pi['extension'] == 'js')) {
                            $this->text('Минифицируем и копируем ', $srcFile, ' --> ', $linkPath);
                            file_put_contents($linkPath, $JSMin->squeeze(file_get_contents($srcFile), true, false, false));
                        } else {
                            $this->text('Создаем символическую ссылку ', $srcFile, ' --> ', $linkPath);
                            if (!@symlink($srcFile, $linkPath)) {
                                throw new \Exception('Не удалось создать символическую ссылку с ' . $srcFile . ' на ' . $linkPath);

                            }
                        }
                        break;
                }
            }
        }
    }

    /**
     * Show title of current installation action with beauty stars.
     *
     * @param string $text Text.
     */
    private function title($text) {
        echo str_repeat('*', 80), PHP_EOL, $text, PHP_EOL, PHP_EOL;
    }

    /**
     * Show all input arguments as string line.
     *
     * @return string
     */
    private function text() {
        foreach (func_get_args() as $text) {
            echo $text;
        }
        echo PHP_EOL;
    }

    /**
     * Recursive iterate throw all files and directories in the folder @c "scripts" and store the result into @c $result argument.
     *
     * @param string $directory Directory.
     * @param array $result Reference to the result.
     */
    private function iterateScripts($directory, &$result) {
        $iterator = new DirectoryIterator($directory);
        foreach ($iterator as $fileinfo) {
            if ($fileinfo->isFile() && !$fileinfo->isDot() && $fileinfo->getExtension() == 'js') {
                $class = str_replace(array(HTDOCS_DIR . '/scripts/', '.js'), '', $directory . DIRECTORY_SEPARATOR . $fileinfo->getFilename());
                $result[$class] = $directory . DIRECTORY_SEPARATOR . $fileinfo->getFilename();
            }
        }

        foreach ($iterator as $fileinfo) {
            if ($fileinfo->isDir() && !$fileinfo->isDot()) {
                $this->iterateScripts($fileinfo->getPathname(), $result);
            }
        }
    }

    /**
     * Parse inclusions in <tt>ScriptLoader.load()</tt>
     *
     * @param string $script Full name of JavaScript-file
     * @return array
     */
    private function parseScriptLoader($script) {
        $result = array();
        $data = file_get_contents($script);
        $r = array();
        if (preg_match_all('/ScriptLoader\.load\((([\s,]{1,})?((?:\'|")([a-zA-Z0-9\/\:\.\-_]{1,})(?:\'|")){1,}([\s,]{1,})?){1,}\)/', $data, $r)) {
            $s = str_replace(array('ScriptLoader.load', '(', ')', "\r", "\n"), '', (string)$r[0][0]);
            $classes = array_map(function ($el) {
                return str_replace(array('\'', '"',',', ' '), '', $el);
            }, explode(',', $s));
            $result = $classes;
        }

        return $result;
    }

    /**
     * Write an array of dependencies into @c "system.jsmap.php"
     *
     * @param array $deps Dependencies.
     */
    private function writeScriptMap($deps) {
        file_put_contents(HTDOCS_DIR . '/system.jsmap.php', '<?php return ' . var_export($deps, true) . ';');
    }

    /**
     * Create file @c "system.jsmap.php" with dependencies for JavaScript classes.
     */
    private function scriptMapAction() {

        $this->title("Создание карты зависимости Javascript классов");

        $files = array();
        $this->iterateScripts(HTDOCS_DIR . '/scripts', $files);

        $result = array();

        foreach ($files as $class => $file) {
            $deps = $this->parseScriptLoader($file);
            if ($deps) {
                $class_dir = str_replace(array(HTDOCS_DIR . '/scripts/', '.js'), '', $file);
                $result[$class_dir] = $deps;
                $this->text($class_dir . ' --> ' . implode(', ', $deps));
            }
        }

        $this->writeScriptMap($result);
    }
}
