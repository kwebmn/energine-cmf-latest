<?php
/**
 * История текстовых блоков и сохранение как событие.
 *
 * Перед каждой записью текста прежний текст языка уходит в share_textblocks_history (не больше LIMIT версий на блок
 * и язык, одинаковый текст историю не пополняет); пустой текст удаляет перевод и, если переводов не осталось, блок —
 * история уходит каскадом. Каждая запись — строка журнала действий (site.action_log) и дата страницы smap_last_mod.
 * Используют TextBlock::save (правка на странице) и TextBlockHistory::restore (откат).
 */
namespace Energine\share\gears;

use Energine\share\components\TextBlock;

class TextHistory {
    use DBWorker;

    /** Сколько версий хранится на блок и язык. */
    const LIMIT = 20;
    const TABLE = 'share_textblocks_history';
    const TRANSLATION = 'share_textblocks_translation';

    /**
     * Записать текст блока на языке. Вызывается внутри транзакции вызывающего.
     *
     * @param string $content очищенный HTML; пустая строка — очистка
     * @param array $log дополнительные данные записи журнала (при откате — tbh_id версии)
     */
    public function store(int $tbId, int $langId, string $content, array $log = []): void {
        // блок читается до записи: при очистке последнего перевода его строка исчезнет
        $block = $this->dbh->row('SELECT smap_id, tb_num FROM share_textblocks WHERE tb_id = ?', [$tbId]) ?? ['smap_id' => null, 'tb_num' => ''];
        $current = $this->dbh->scalar('SELECT tb_content FROM ' . self::TRANSLATION . ' WHERE tb_id = ? AND lang_id = ?', [$tbId, $langId]);
        $had = ($current !== false && $current !== null);
        if ($had && $current === $content) {
            return; // текст не изменился — ни версии, ни события
        }
        if ($had && $current !== $content) {
            $row = ['tb_id' => $tbId, 'lang_id' => $langId, 'tbh_content' => $current];
            if ($uid = (int)E()->getUser()->getID()) {
                $row['u_id'] = $uid;
            }
            $this->dbh->insert(self::TABLE, $row);
            $this->dbh->exec('DELETE FROM ' . self::TABLE . ' WHERE tb_id = ? AND lang_id = ? AND tbh_id NOT IN '
                . '(SELECT tbh_id FROM (SELECT tbh_id FROM ' . self::TABLE . ' WHERE tb_id = ? AND lang_id = ? ORDER BY tbh_id DESC LIMIT '
                . self::LIMIT . ') kept)', [$tbId, $langId, $tbId, $langId]);
        }
        if (trim($content) !== '') {
            if ($had) {
                $this->dbh->update(self::TRANSLATION, ['tb_content' => $content], ['tb_id' => $tbId, 'lang_id' => $langId]);
            } else {
                $this->dbh->insert(self::TRANSLATION, ['tb_id' => $tbId, 'lang_id' => $langId, 'tb_content' => $content]);
            }
        } else {
            $this->dbh->delete(self::TRANSLATION, ['tb_id' => $tbId, 'lang_id' => $langId]);
            if ($this->dbh->scalar('SELECT COUNT(*) FROM ' . self::TRANSLATION . ' WHERE tb_id = ?', [$tbId]) == 0) {
                $this->dbh->delete('share_textblocks', ['tb_id' => $tbId]);
            }
        }
        $this->event($block['smap_id'] ? (int)$block['smap_id'] : null, (string)$block['tb_num'], $langId, $content, $log);
    }

    /**
     * Версии блока на языке, новые первыми.
     *
     * @return array[] tbh_id, tbh_date, u_id, tbh_content
     */
    public function versions(int $tbId, int $langId): array {
        return $this->dbh->rows('SELECT tbh_id, tbh_date, u_id, tbh_content FROM ' . self::TABLE
            . ' WHERE tb_id = ? AND lang_id = ? ORDER BY tbh_id DESC', [$tbId, $langId]);
    }

    /**
     * Версия, если она принадлежит этому блоку и языку.
     */
    public function version(int $tbhId, int $tbId, int $langId): ?array {
        return $this->dbh->row('SELECT tbh_id, tbh_date, u_id, tbh_content FROM ' . self::TABLE
            . ' WHERE tbh_id = ? AND tb_id = ? AND lang_id = ?', [$tbhId, $tbId, $langId]);
    }

    /**
     * Сохранение как событие: строка журнала (класс TextBlock, объект — адрес страницы и номер блока) и дата страницы.
     */
    private function event(?int $smapId, string $num, int $langId, string $content, array $extra): void {
        $data = ['smap_id' => $smapId, 'num' => $num, 'lang_id' => $langId,
            'length' => mb_strlen(trim(strip_tags($content)))] + $extra;
        $page = '';
        if ($smapId) {
            try {
                $page = (string)E()->getMap()->getURLByID($smapId);
            } catch (\Throwable $e) {
                $page = '#' . $smapId;
            }
        }
        if ($class = Primitive::getConfigValue('site.action_log')) {
            (new $class(TextBlock::class, mb_substr($page . '#' . $num, 0, 100)))->write('UPDATE', $data); // al_objectname — varchar(100)
        }
        if ($smapId) {
            $this->dbh->update('share_sitemap', ['smap_last_mod' => date('Y-m-d H:i:s')], ['smap_id' => $smapId]);
        }
    }
}
