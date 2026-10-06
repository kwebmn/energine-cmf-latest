<?php
/**
 * Описание схемы базы для форм и гридов: колонки (тип, длина, nullable, default, ключ, индекс, значения SET/ENUM)
 * и внешние ключи всех таблиц базы.
 *
 * Читается из information_schema четырьмя запросами на процесс (прежде — SHOW TABLES LIKE и разбор SHOW CREATE TABLE
 * каждой таблицы); массив тот же, что отдавал прежний разбор — сверка tests/tools/schema-fixture.php. Файловый кэш
 * схемы (site.cache) — как прежде. Таблицы другой базы не поддерживаются (у форка одна база).
 */
namespace Energine\share\gears;

class DBStructureInfo extends Primitive {
    /**
     * Схема: имя таблицы → (имя колонки → свойства). Свойства колонки: nullable, length, default, key (true — первичный,
     * массив tableName/fieldName/constraint — внешний), type (QAL::COLTYPE_*), index ('PRI' | 'MUL' | false),
     * options (значения SET/ENUM), tableName.
     * @var array<string, array<string, array>>
     */
    private $structure = [];

    private bool $loaded = false;

    /**
     * Соединение: запросы схемы идут через Db::run — общий счётчик и журнал запросов.
     * @var Db
     */
    private $db;

    public function __construct(Db $db) {
        $this->db = $db;
        $cached = E()->getCache()->isEnabled() ? E()->getCache()->retrieve(Cache::DB_STRUCTURE_KEY) : null;
        if (is_array($cached) && $cached) {
            $this->structure = $cached;
            $this->loaded = true;
        }
    }

    /**
     * Есть ли таблица (имя — без базы; обратные кавычки допустимы).
     */
    public function tableExists($tableName) {
        $name = $this->plainName($tableName);
        $this->ensureLoaded();
        return isset($this->structure[$name]);
    }

    /**
     * Описание колонок таблицы: имя колонки → свойства (см. $structure). Таблица, появившаяся после загрузки схемы
     * (переход базы в этом же процессе, устаревший кэш), читается заново; неизвестная — ошибка базы, как прежде.
     *
     * @throws SystemException BAD_TABLE_NAME
     */
    public function getTableMeta($tableName) {
        $name = $this->plainName($tableName);
        $this->ensureLoaded();
        if (!isset($this->structure[$name])) {
            $this->loadAll();
        }
        if (empty($this->structure[$name])) {
            throw new SystemException('BAD_TABLE_NAME ' . $tableName, SystemException::ERR_DB, $tableName);
        }
        return $this->structure[$name];
    }

    private function ensureLoaded(): void {
        if (!$this->loaded) {
            $this->loadAll();
        }
    }

    /**
     * Имя таблицы без обратных кавычек и без префикса базы (другая база — не поддерживается).
     *
     * @throws SystemException
     */
    private function plainName($tableName): string {
        $parts = QAL::getFQTableName($tableName, true);
        if (count($parts) > 1) {
            throw new SystemException('BAD_TABLE_NAME ' . $tableName, SystemException::ERR_DB, 'таблицы другой базы не поддерживаются');
        }
        return (string)end($parts);
    }

    /**
     * Вся схема текущей базы: индексы, внешние ключи, колонки (с видом таблицы) — три запроса; результат — в кэш.
     */
    private function loadAll(): void {
        $this->loaded = true;
        $this->structure = [];
        // индексы: первичный — PRI, остальные (в том числе уникальные и составные, любой столбец) — MUL, как прежде
        $indexes = [];
        foreach ($this->db->rows('SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()') as $i) {
            $current = $indexes[$i['TABLE_NAME']][$i['COLUMN_NAME']] ?? false;
            $indexes[$i['TABLE_NAME']][$i['COLUMN_NAME']] = ($i['INDEX_NAME'] === 'PRIMARY' || $current === 'PRI') ? 'PRI' : 'MUL';
        }
        $foreign = [];
        foreach ($this->db->rows('SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME '
            . 'FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL') as $f) {
            $foreign[$f['TABLE_NAME']][$f['COLUMN_NAME']] = ['tableName' => $f['REFERENCED_TABLE_NAME'],
                'fieldName' => $f['REFERENCED_COLUMN_NAME'], 'constraint' => $f['CONSTRAINT_NAME']];
        }
        $columns = $this->db->rows('SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE, c.COLUMN_TYPE, c.IS_NULLABLE, c.COLUMN_DEFAULT, t.TABLE_TYPE '
            . 'FROM information_schema.COLUMNS c JOIN information_schema.TABLES t ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME '
            . 'WHERE c.TABLE_SCHEMA = DATABASE() ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION');
        foreach ($columns as $c) {
            $table = $c['TABLE_NAME'];
            $this->structure[$table][$c['COLUMN_NAME']] = ($c['TABLE_TYPE'] === 'VIEW')
                ? $this->viewColumn($table, $c, count($this->structure[$table] ?? []))
                : $this->column($table, $c, $indexes[$table][$c['COLUMN_NAME']] ?? false, $foreign[$table][$c['COLUMN_NAME']] ?? null);
        }
        if (E()->getCache()->isEnabled()) {
            E()->getCache()->store(Cache::DB_STRUCTURE_KEY, $this->structure);
        }
    }

    /**
     * Свойства колонки таблицы — в прежнем виде.
     *
     * @param string|false $index 'PRI' | 'MUL' | false
     */
    private function column(string $table, array $c, $index, ?array $foreignKey): array {
        $type = self::convertType($c['DATA_TYPE']);
        $inParens = preg_match('/\((.+)\)/', (string)$c['COLUMN_TYPE'], $m) ? $m[1] : '';
        $options = null;
        if ($type == QAL::COLTYPE_SET || $type == QAL::COLTYPE_ENUM) {
            $options = array_map(fn($value) => trim($value, '\'""'), explode(',', $inParens));
            $length = true;
        } elseif ($type == QAL::COLTYPE_DECIMAL) {
            // decimal(10,2): 10 + 2 + 1 (разделитель)
            $length = array_sum(array_map('intval', array_filter(explode(',', $inParens)))) + 1;
        } else {
            $length = (int)$inParens;
        }
        return [
            'nullable' => $c['IS_NULLABLE'] === 'YES',
            'length' => $length,
            'default' => self::defaultOf($c['COLUMN_DEFAULT']),
            'key' => $foreignKey ?? ($index === 'PRI'),
            'type' => $type,
            'index' => $index,
            'options' => $options,
            'tableName' => $table,
        ];
    }

    /**
     * Колонка представления (у него нет ключей): первая считается ключом — как прежде.
     */
    private function viewColumn(string $table, array $c, int $position): array {
        $type = self::convertType($c['DATA_TYPE']);
        return [
            'key' => $position === 0,
            'nullable' => $c['IS_NULLABLE'] === 'YES',
            'type' => $type,
            'length' => ($type == QAL::COLTYPE_STRING) ? 100 : 10,
            'index' => ($position === 0) ? 'PRI' : false,
            'default' => '',
            'tableName' => $table,
        ];
    }

    /**
     * Значение по умолчанию, как его отдавал разбор SHOW CREATE TABLE: без DEFAULT — '', DEFAULT NULL — null,
     * строка — без кавычек, число — строкой, выражение (current_timestamp()) — ''.
     */
    private static function defaultOf(?string $default) {
        if ($default === null) {
            return '';
        }
        if (strcasecmp($default, 'NULL') === 0) {
            return null;
        }
        if (preg_match('/^\'(.*)\'$/s', $default, $m)) {
            return str_replace("''", "'", $m[1]);
        }
        if (preg_match('/^-?\d+(\.\d+)?$/', $default)) {
            return $default;
        }
        return '';
    }

    /**
     * Тип колонки базы → QAL::COLTYPE_*. Отображение полное: редкий тип (uuid, inet6, geometry …) — строка,
     * чтобы форма над такой таблицей открывалась, а не падала на неизвестном типе поля.
     */
    static private function convertType($mysqlType) {
        $mysqlType = strtoupper((string)$mysqlType);
        switch ($mysqlType) {
            case 'TINYINT':
            case 'MEDIUMINT':
            case 'SMALLINT':
            case 'INT':
            case 'BIGINT':
            case 'YEAR':
            case 'BIT':
                $result = QAL::COLTYPE_INTEGER;
                break;
            case 'FLOAT':
            case 'DOUBLE':
            case 'REAL':
                $result = QAL::COLTYPE_FLOAT;
                break;
            case 'DECIMAL':
            case 'NUMERIC':
                $result = QAL::COLTYPE_DECIMAL;
                break;
            case 'DATE':
                $result = QAL::COLTYPE_DATE;
                break;
            case 'TIME':
                $result = QAL::COLTYPE_TIME;
                break;
            case 'TIMESTAMP':
                $result = QAL::COLTYPE_TIMESTAMP;
                break;
            case 'DATETIME':
                $result = QAL::COLTYPE_DATETIME;
                break;
            case 'VARCHAR':
            case 'CHAR':
                $result = QAL::COLTYPE_STRING;
                break;
            case 'TEXT':
            case 'TINYTEXT':
            case 'MEDIUMTEXT':
            case 'LONGTEXT':
                $result = QAL::COLTYPE_TEXT;
                break;
            case 'BLOB':
            case 'TINYBLOB':
            case 'MEDIUMBLOB':
            case 'LONGBLOB':
                $result = QAL::COLTYPE_BLOB;
                break;
            case 'SET':
                $result = QAL::COLTYPE_SET;
                break;
            case 'ENUM':
                $result = QAL::COLTYPE_ENUM;
                break;
            default:
                $result = QAL::COLTYPE_STRING;
        }

        return $result;
    }
}
