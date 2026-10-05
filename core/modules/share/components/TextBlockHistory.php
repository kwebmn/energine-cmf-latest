<?php
/**
 * Окно истории текстового блока: версии текущего языка (новые сверху), просмотр версии целиком и откат.
 * Встраивается состоянием TextBlock::history с параметрами tb_id и lang_id; сам текст пишет гир TextHistory.
 */
namespace Energine\share\components;

use Energine\share\gears\FieldDescription;
use Energine\share\gears\JSONCustomBuilder;
use Energine\share\gears\QAL;
use Energine\share\gears\SystemException;
use Energine\share\gears\TextHistory;

class TextBlockHistory extends Grid {
    public function __construct($name, ?array $params = null) {
        parent::__construct($name, $params);
        $this->setTableName(TextHistory::TABLE);
        $this->setTitle($this->translate('TXT_TEXT_HISTORY'));
        $this->setOrder(['tbh_id' => QAL::DESC]);
        $this->setFilter(['tb_id' => (int)$this->getParam('tb_id'), 'lang_id' => (int)$this->getParam('lang_id')]);
    }

    protected function defineParams() {
        return array_merge(parent::defineParams(), ['tb_id' => 0, 'lang_id' => 0]);
    }

    /**
     * К колонкам таблицы — автор и начало текста (их считает loadData).
     */
    protected function createDataDescription() {
        $dd = parent::createDataDescription();
        if ($date = $dd->getFieldDescriptionByName('tbh_date')) {
            $date->setProperty('outputFormat', '%E');
        }
        foreach (['tbh_author' => 'FIELD_TBH_AUTHOR', 'tbh_excerpt' => 'FIELD_TBH_EXCERPT'] as $name => $title) {
            if (!$dd->getFieldDescriptionByName($name)) {
                $fd = new FieldDescription($name);
                $fd->setType(FieldDescription::FIELD_TYPE_STRING);
                $fd->setProperty('title', $title);
                $dd->addFieldDescription($fd);
            }
        }
        return $dd;
    }

    /**
     * Строки грида: имя автора по u_id и начало текста без разметки.
     */
    protected function loadData() {
        $rows = parent::loadData();
        if ($rows && $this->getState() === 'getRawData') {
            // текст версии не входит в описание данных грида (его не выводят) — читается отдельно для начала текста
            $texts = [];
            foreach ($this->dbh->select(TextHistory::TABLE, ['tbh_id', 'tbh_content'],
                ['tbh_id' => array_map('intval', array_column($rows, 'tbh_id'))]) ?: [] as $t) {
                $texts[(int)$t['tbh_id']] = (string)$t['tbh_content'];
            }
            $names = [];
            foreach ($rows as &$row) {
                $uid = (int)($row['u_id'] ?? 0);
                if ($uid && !array_key_exists($uid, $names)) {
                    $user = $this->dbh->select('user_users', ['u_fullname', 'u_name'], ['u_id' => $uid]);
                    $names[$uid] = $user ? (string)($user[0]['u_fullname'] ?: $user[0]['u_name']) : '';
                }
                $row['tbh_author'] = $uid ? $names[$uid] : '';
                $text = html_entity_decode(strip_tags($texts[(int)$row['tbh_id']] ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');
                $row['tbh_excerpt'] = mb_substr(trim(preg_replace('/\s+/u', ' ', $text)), 0, 120);
            }
            unset($row);
        }
        return $rows;
    }

    /**
     * Версия целиком — простая страница в окне (состояние show; имя view занято DBDataSet).
     */
    protected function showVersion($tbhId) {
        $version = $this->version((int)$tbhId);
        $this->response->setHeader('Content-Type', 'text/html; charset=utf-8');
        $this->response->write('<!DOCTYPE html><html><head><meta charset="utf-8"><title>'
            . htmlspecialchars($this->translate('TXT_TEXT_HISTORY'), ENT_QUOTES) . ' — ' . htmlspecialchars((string)$version['tbh_date'], ENT_QUOTES)
            . '</title><style>body{margin:0;padding:1.25rem 1.5rem;font:16px/1.5 system-ui,sans-serif;color:#222;background:#fff}'
            . 'img{max-width:100%;height:auto}</style></head><body>' . $version['tbh_content'] . '</body></html>');
        $this->response->commit();
    }

    /**
     * Откат: нынешний текст — в историю, версия — текущая; ответ JSON {result, data}.
     */
    protected function restore($tbhId) {
        $version = $this->version((int)$tbhId);
        $this->dbh->beginTransaction();
        try {
            (new TextHistory())->store((int)$this->getParam('tb_id'), (int)$this->getParam('lang_id'),
                (string)$version['tbh_content'], ['tbh_id' => (int)$tbhId]);
            $this->dbh->commit();
        } catch (\Throwable $e) {
            $this->dbh->rollback();
            throw $e;
        }
        $builder = new JSONCustomBuilder();
        $builder->setProperty('result', true)->setProperty('data', (string)$version['tbh_content']);
        $this->setBuilder($builder);
    }

    /**
     * Версия этого блока и языка — иначе 404.
     */
    private function version(int $tbhId): array {
        $version = (new TextHistory())->version($tbhId, (int)$this->getParam('tb_id'), (int)$this->getParam('lang_id'));
        if (!$version) {
            throw new SystemException('ERR_404', SystemException::ERR_404);
        }
        return $version;
    }
}
