<?php
/**
 * Db — небольшой типизированный слой над PDO для нового кода (надёжность, этап 4).
 *
 * Запросы только с параметрами «?», имена таблиц и колонок — через quoteName() (проверяются как идентификаторы),
 * транзакция — функцией с откатом при исключении (вложенная — одна внешняя), один счётчик и журнал запросов.
 * QAL (прежний API с подстановками %s) наследует Db и выполняет свои запросы через run() — счётчик общий.
 * Ничего не знает о ядре (E(), константы): годится и для консоли, и для тестов с голым PDO.
 */
namespace Energine\share\gears;

// Primitive — конфиг и таймеры ядра (QAL наследовал его и раньше; конструктор ничего не требует)
class Db extends Primitive {
    /** @var \PDO */
    protected $pdo;

    /** Сколько запросов выполнено через этот объект. */
    private int $queryCount = 0;

    /**
     * Журнал запросов (включается logQueries(true) — отладка): текст запроса с параметрами.
     * @var string[]
     */
    private array $queryLog = [];
    private bool $logging = false;

    public function __construct(\PDO $pdo) {
        parent::__construct();
        $this->pdo = $pdo;
    }

    public function getPDO(): \PDO {
        return $this->pdo;
    }

    /**
     * Выполнить запрос с параметрами «?»; все пути (и QAL) проходят здесь — ради счётчика и журнала.
     *
     * @param array $params значения для «?» (массив — список через запятую, как в QAL)
     */
    public function run(string $sql, array $params = []): \PDOStatement {
        $this->queryCount++;
        if ($this->logging) {
            $this->queryLog[] = $params ? $sql . ' -- ' . json_encode(array_values($params), JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR) : $sql;
        }
        if (!$params) {
            return $this->pdo->query($sql);
        }
        $statement = $this->pdo->prepare($sql);
        $statement->execute(array_values($params));
        return $statement;
    }

    /** Все строки (ассоциативные массивы); пусто — []. */
    public function rows(string $sql, array $params = []): array {
        return $this->run($sql, $params)->fetchAll(\PDO::FETCH_ASSOC) ?: [];
    }

    /** Первая строка или null. */
    public function row(string $sql, array $params = []): ?array {
        $row = $this->run($sql, $params)->fetch(\PDO::FETCH_ASSOC);
        return $row === false ? null : $row;
    }

    /** Первое значение первой строки; нет строки — false. */
    public function scalar(string $sql, array $params = []): mixed {
        return $this->run($sql, $params)->fetchColumn();
    }

    /** Первая колонка всех строк. */
    public function column(string $sql, array $params = []): array {
        return $this->run($sql, $params)->fetchAll(\PDO::FETCH_COLUMN) ?: [];
    }

    /** Запрос без выборки; результат — число затронутых строк. */
    public function exec(string $sql, array $params = []): int {
        return $this->run($sql, $params)->rowCount();
    }

    /**
     * INSERT одной строки; результат — id (0 у таблицы без автоинкремента).
     *
     * @param array $row колонка => значение (null — NULL)
     */
    public function insert(string $table, array $row): int {
        if (!$row) {
            throw new \InvalidArgumentException('insert: нет данных для ' . $table);
        }
        $columns = implode(', ', array_map([$this, 'quoteName'], array_keys($row)));
        $this->run('INSERT INTO ' . $this->quoteName($table) . ' (' . $columns . ') VALUES (' . rtrim(str_repeat('?, ', count($row)), ', ') . ')', array_values($row));
        return (int)$this->pdo->lastInsertId();
    }

    /**
     * UPDATE по условию (колонка => значение, И между ними; массив значений — IN); результат — число строк.
     */
    public function update(string $table, array $data, array $where): int {
        if (!$data || !$where) {
            throw new \InvalidArgumentException('update: нужны данные и условие для ' . $table);
        }
        $set = implode(', ', array_map(fn($column) => $this->quoteName($column) . ' = ?', array_keys($data)));
        [$condition, $params] = $this->where($where);
        return $this->exec('UPDATE ' . $this->quoteName($table) . ' SET ' . $set . $condition, array_merge(array_values($data), $params));
    }

    /** DELETE по условию (как у update); результат — число строк. */
    public function delete(string $table, array $where): int {
        if (!$where) {
            throw new \InvalidArgumentException('delete: нужно условие для ' . $table);
        }
        [$condition, $params] = $this->where($where);
        return $this->exec('DELETE FROM ' . $this->quoteName($table) . $condition, $params);
    }

    /**
     * Транзакция: функция выполняется целиком или откатывается при исключении (исключение идёт дальше). Внутри уже
     * открытой транзакции (своей или QAL::beginTransaction) — просто выполняется: одна внешняя.
     */
    public function transaction(callable $fn): mixed {
        if ($this->pdo->inTransaction()) {
            return $fn($this);
        }
        $this->pdo->beginTransaction();
        try {
            $result = $fn($this);
            $this->pdo->commit();
            return $result;
        } catch (\Throwable $e) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Имя таблицы или колонки в обратных кавычках (с базой через точку); не идентификатор — исключение.
     */
    public function quoteName(string $name): string {
        if (!preg_match('/^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?$/', $name)) {
            throw new \InvalidArgumentException('Не имя таблицы или колонки: ' . $name);
        }
        return '`' . str_replace('.', '`.`', $name) . '`';
    }

    public function queryCount(): int {
        return $this->queryCount;
    }

    /** Включить журнал запросов (отладка): тексты запросов доступны через queryLog(). */
    public function logQueries(bool $on = true): void {
        $this->logging = $on;
    }

    /** @return string[] */
    public function queryLog(): array {
        return $this->queryLog;
    }

    /**
     * Условие WHERE из массива колонка => значение: null — IS NULL, массив — IN (пустой — ложь).
     *
     * @return array{0: string, 1: array}
     */
    private function where(array $where): array {
        $parts = [];
        $params = [];
        foreach ($where as $column => $value) {
            $name = $this->quoteName((string)$column);
            if ($value === null) {
                $parts[] = $name . ' IS NULL';
            } elseif (is_array($value)) {
                if (!$value) {
                    $parts[] = '0';
                } else {
                    $parts[] = $name . ' IN (' . rtrim(str_repeat('?, ', count($value)), ', ') . ')';
                    $params = array_merge($params, array_values($value));
                }
            } else {
                $parts[] = $name . ' = ?';
                $params[] = $value;
            }
        }
        return [' WHERE ' . implode(' AND ', $parts), $params];
    }
}
