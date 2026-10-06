<?php
/**
 * Переводы констант одним запросом на язык (надёжность, этап 4).
 *
 * Прежде translate() выполнял подготовленный запрос на каждую константу (десятки запросов на страницу).
 * Translator при первом обращении читает все переводы языка и дальше отвечает из памяти процесса.
 * Поведение то же: неизвестная константа и пустой перевод — имя константы; регистр имени не важен.
 * Зависит только от Db — годится и в консоли. Правка переводов в этом же процессе — forget().
 */
namespace Energine\share\gears;

class Translator {
    private Db $db;

    /**
     * Загруженные переводы: язык → [ИМЯ_КОНСТАНТЫ → текст] (без пустых).
     * @var array<int, array<string, string>>
     */
    private array $loaded = [];

    public function __construct(Db $db) {
        $this->db = $db;
    }

    /**
     * Перевод константы на язык; нет перевода — имя константы.
     */
    public function translate(string $const, int $langId): string {
        if ($const === '') {
            return $const;
        }
        $const = strtoupper($const);
        if (!isset($this->loaded[$langId])) {
            $this->load($langId);
        }
        return $this->loaded[$langId][$const] ?? $const;
    }

    /**
     * Забыть загруженное: переводы правили в этом же процессе (TranslationEditor, setup translations).
     */
    public function forget(): void {
        $this->loaded = [];
    }

    private function load(int $langId): void {
        $this->loaded[$langId] = [];
        $rows = $this->db->rows('SELECT t.ltag_name, tr.ltag_value_rtf FROM share_lang_tags t '
            . 'JOIN share_lang_tags_translation tr ON tr.ltag_id = t.ltag_id WHERE tr.lang_id = ?', [$langId]);
        foreach ($rows as $row) {
            // пустой перевод — как отсутствующий: отдаётся имя константы (так было и прежде)
            if ((string)$row['ltag_value_rtf'] !== '') {
                $this->loaded[$langId][strtoupper((string)$row['ltag_name'])] = (string)$row['ltag_value_rtf'];
            }
        }
    }
}
