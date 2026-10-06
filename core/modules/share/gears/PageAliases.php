<?php
/**
 * Старые адреса страниц (надёжность, этап 5): переименованная или перенесённая страница отвечает со старого адреса
 * переадресацией 301 на нынешний — ссылки и закладки на неё не ломаются.
 *
 * Таблица share_sitemap_aliases: прежний путь страницы без языка и краевых слешей (about/team) → страница. Пишет
 * remember() — форма раздела после сохранения (сама страница и её подразделы, у которых путь изменился); читает find()
 * — обработчик 404 (DocumentController). Псевдоним указывает на страницу, а не на путь, поэтому цепочек нет: любой
 * прежний адрес ведёт сразу на нынешний. Путь, снова занятый страницей, — не псевдоним (настоящая страница важнее).
 * Удаление страницы уносит её строки каскадом. Сегмент адреса общий для всех языков — и псевдоним тоже.
 */
namespace Energine\share\gears;

final class PageAliases {
    /** Длина колонки alias_path: путь длиннее не запоминается (и не ищется). */
    const MAX_PATH = 255;

    public function __construct(private Db $db) {
    }

    /**
     * Пути всех страниц из базы — без учёта прав посетителя и языка: id → путь без краевых слешей ('' — главная).
     *
     * @return array<int, string>
     */
    public function paths(): array {
        $rows = [];
        foreach ($this->db->rows('SELECT smap_id, smap_pid, smap_segment FROM share_sitemap') as $row) {
            $rows[(int)$row['smap_id']] = $row;
        }
        $paths = [];
        foreach (array_keys($rows) as $id) {
            $this->pathOf($id, $rows, $paths);
        }
        return $paths;
    }

    /**
     * После сохранения раздела: страницам, чей путь изменился, — прежний путь (последний владелец пути выигрывает);
     * затем убираются псевдонимы, совпавшие с нынешними путями страниц.
     *
     * @param array<int, string> $before paths() до сохранения
     * @return int сколько прежних адресов записано
     */
    public function remember(array $before): int {
        $after = $this->paths();
        $written = 0;
        foreach ($before as $id => $old) {
            if ($old !== '' && isset($after[$id]) && $after[$id] !== $old && mb_strlen($old) <= self::MAX_PATH) {
                $this->db->exec('INSERT INTO share_sitemap_aliases (alias_path, smap_id) VALUES (?, ?) '
                    . 'ON DUPLICATE KEY UPDATE smap_id = VALUES(smap_id), alias_date = CURRENT_TIMESTAMP', [$old, $id]);
                $written++;
            }
        }
        $current = array_values(array_filter($after, fn(string $path) => $path !== ''));
        foreach (array_chunk($current, 500) as $chunk) {
            $this->db->exec('DELETE FROM share_sitemap_aliases WHERE alias_path IN (' . rtrim(str_repeat('?, ', count($chunk)), ', ') . ')', $chunk);
        }
        return $written;
    }

    /**
     * Прежний адрес для пути запроса: самый длинный префикс сегментов, записанный как псевдоним.
     *
     * @param string[] $segments сегменты пути без языка
     * @return array{id: int, rest: string[]}|null страница и остаток пути (параметры компонентов, подразделы)
     */
    public function find(array $segments): ?array {
        $segments = array_values(array_filter(array_map('strval', $segments), fn(string $s) => $s !== ''));
        $candidates = [];
        for ($n = count($segments); $n > 0; $n--) {
            $path = implode('/', array_slice($segments, 0, $n));
            if (mb_strlen($path) <= self::MAX_PATH) {
                $candidates[$n] = $path;
            }
        }
        if (!$candidates) {
            return null;
        }
        $hits = [];
        foreach ($this->db->rows('SELECT alias_path, smap_id FROM share_sitemap_aliases WHERE alias_path IN ('
            . rtrim(str_repeat('?, ', count($candidates)), ', ') . ')', array_values($candidates)) as $row) {
            // сравнение в базе — без учёта регистра (utf8mb3_general_ci), здесь — так же
            $hits[mb_strtolower($row['alias_path'])] = (int)$row['smap_id'];
        }
        return self::match($hits, $segments);
    }

    /**
     * Все прежние адреса одним запросом — для проверки многих ссылок сразу (TextLinks).
     *
     * @return array<string, int> путь в нижнем регистре → страница
     */
    public function all(): array {
        $hits = [];
        foreach ($this->db->rows('SELECT alias_path, smap_id FROM share_sitemap_aliases') as $row) {
            $hits[mb_strtolower($row['alias_path'])] = (int)$row['smap_id'];
        }
        return $hits;
    }

    /**
     * Самый длинный префикс сегментов среди уже прочитанных прежних адресов (find, all).
     *
     * @param array<string, int> $aliases путь в нижнем регистре → страница
     * @param string[] $segments сегменты пути без языка
     * @return array{id: int, rest: string[]}|null
     */
    public static function match(array $aliases, array $segments): ?array {
        $segments = array_values(array_filter(array_map('strval', $segments), fn(string $s) => $s !== ''));
        for ($n = count($segments); $n > 0; $n--) {
            $path = mb_strtolower(implode('/', array_slice($segments, 0, $n)));
            if (isset($aliases[$path])) {
                return ['id' => $aliases[$path], 'rest' => array_slice($segments, $n)];
            }
        }
        return null;
    }

    /**
     * Путь страницы (с запоминанием в $paths); корень, страница без родителя в базе и петля — ''.
     *
     * @param array<int, array> $rows
     * @param array<int, string> $paths
     */
    private function pathOf(int $id, array $rows, array &$paths, int $depth = 0): string {
        if (isset($paths[$id])) {
            return $paths[$id];
        }
        $row = $rows[$id] ?? null;
        if (!$row || $row['smap_pid'] === null || $depth > 64) {
            return $paths[$id] = '';
        }
        $parent = $this->pathOf((int)$row['smap_pid'], $rows, $paths, $depth + 1);
        return $paths[$id] = ltrim($parent . '/' . $row['smap_segment'], '/');
    }
}
