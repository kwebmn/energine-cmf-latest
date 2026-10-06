<?php
/**
 * @file
 * TextBlock
 *
 * It contains the definition to:
 * @code
final class TextBlock;
 * @endcode
 *
 * @author 1m.dm
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\share\components;
use Energine\share\gears\DataDescription, Energine\share\gears\FieldDescription, Energine\share\gears\Data, Energine\share\gears\Field, Energine\share\gears\SystemException, Energine\share\gears\QAL, Energine\share\gears\TextHistory, Energine\share\gears\TextLinks;
/**
 * Text block.
 *
 * @code
 class TextBlock;
 * @endcode
 *
 * @final
 */
class TextBlock extends DataSet implements SampleTextBlock{
    /**
     * Name of the main table.
     * @var string $tableName
     */
    private $tableName;

    /**
     * Text block ID.
     * @var int $id
     */
    private $id = false;

    /**
     * Content of the text block.
     * @var string $content
     */
    private $content = '';

    /**
     * Is this text block editable?
     * @var boolean $isEditable
     */
    private $isEditable;

    //todo VZ: Is the next todo done?
    /**
     * @copydoc DataSet::__construct
     */
    public function __construct($name,  ?array $params = null) {
        parent::__construct($name, $params);
        /**
         * @todo Не забыть убрать $_REQUEST или переделать чтобы для режима отладки  -_REQUEST а так  - _POST
         *
         */
        $this->isEditable = $this->document->isEditable();
        $this->tableName = 'share_textblocks';
        if ($this->isEditable) {
            //выставляем свойство указывающее на то что блок находится в режиме редактирования
            $this->setProperty('editable', 'editable');
        }
    }

    /**
     * @copydoc DataSet::defineParams
     */
    // Добавлен параметр num
    protected function defineParams() {
        return array_merge(
            parent::defineParams(),
            array(
                'num' => 1,
                'active' => true,
                'text' => false,
                // константа с образцом текста секции визитки: показывается в режиме правки вместо пустого блока
                'section_sample' => false,
                // секция визитки по имени (hero … cta): номер блока и образец — из SECTIONS
                'section' => false
            )
        );
    }

    /**
     * Секции визиток: имя → номер текстового блока на странице (номер — число, чтобы блок был свой у страницы;
     * нечисловой num — общий блок всех страниц). Номера не меняются: по ним в базе лежат тексты.
     */
    /**
     * Окно истории (состояние history).
     * @var TextBlockHistory|null
     */
    private $historyWindow = null;

    const SECTIONS = ['hero' => 11, 'services' => 12, 'prices' => 13, 'reviews' => 14, 'gallery' => 15, 'faq' => 16,
        'contacts' => 17, 'cta' => 18];

    /**
     * section=<имя> задаёт номер блока и образец секции (TXT_SECTION_SAMPLE_<ИМЯ>, если образец не указан явно).
     * @throws SystemException ERR_DEV_NO_SECTION — секции с таким именем нет
     */
    protected function setParam($name, $value) {
        if ($name === 'section' && $value) {
            if (!isset(self::SECTIONS[$value])) {
                throw new SystemException('ERR_DEV_NO_SECTION', SystemException::ERR_DEVELOPER,
                    [$value, implode(', ', array_keys(self::SECTIONS))]);
            }
            parent::setParam('num', self::SECTIONS[$value]);
            if (!$this->getParam('section_sample')) {
                parent::setParam('section_sample', 'TXT_SECTION_SAMPLE_' . strtoupper($value));
            }
        }
        parent::setParam($name, $value);
    }

    //todo VZ: This confuse! What is returned when $num is text block ID?
    /**
     * Get text block ID by document ID and number.
     *
     * @param int $smapID Document ID.
     * @param string $num Text block ID.
     * @return int
     */
    protected function getTextBlockID($smapID, $num) {
        $smapID = (empty($smapID)) ? null : $smapID;
        return $this->dbh->getScalar($this->tableName, array('tb_id'), array('smap_id' => $smapID, 'tb_num' => $num));
    }

    /**
     * @copydoc DataSet::main
     */
    // Загрузка данных
    protected function main() {
        /**
         * @todo Тут вообще получается ограничение, что num лейаутного текстового блока не должен быть цифрой
         */

        if (intval($this->getParam('num')) !== 0) {
            $docID = $this->document->getID();
        } else {
            $docID = '';
            //Блок - глобальный
            $this->setProperty('global', 'global');
        }

        // все блоки страницы (или все глобальные) на языке читаются одним запросом на запрос — у секций визитки
        // блоков на странице несколько, прежде каждый делал свой запрос
        $blocks = self::pageBlocks($docID ? (int)$docID : null, (int)$this->document->getLang());
        if ($res = $blocks[(string)$this->getParam('num')] ?? null) {
            $this->id = $res['id'];
            $this->content = $res['content'];
        } elseif ($this->getParam('text')) {
            $this->content = $this->getParam('text');
        }
        // битые ссылки текста (TextLinks): посетителю — текст без перехода на 404, администратору — пометка с причиной;
        // в режиме правки текст не трогается — редактор сохранил бы изменения
        if (!$this->isEditable && is_string($this->content) && $this->content !== '') {
            $this->content = TextLinks::forRequest()->filter($this->content, $this->document->getRights() > ACCESS_EDIT,
                ['page' => $this->translate('TXT_BROKEN_LINK_PAGE'), 'file' => $this->translate('TXT_BROKEN_LINK_FILE')]);
        }

        $this->setProperty('num', $this->getParam('num'));
        if ($this->id) {
            $this->setProperty('tb_id', $this->id); // окно истории блока (PageEditor): есть, что показывать
        }
        if ($this->getParam('section')) {
            $this->setProperty('section', $this->getParam('section'));
        }
        if ($this->isEditable && ($sample = $this->getParam('section_sample')) && trim((string)$this->content) === '') {
            $this->setProperty('section_sample', $sample);
            $this->document->addTranslation($sample, $this);
        }
        $this->prepare();
    }

    /**
     * @copydoc DataSet::createDataDescription
     */
    protected function createDataDescription() {
        $dataDescr = new DataDescription();
        $fieldDescr = new FieldDescription($this->getName());
        $fieldDescr->setType(FieldDescription::FIELD_TYPE_HTML_BLOCK);
        $dataDescr->addFieldDescription($fieldDescr);

        return $dataDescr;
    }

    /**
     * @copydoc DataSet::createData
     */
    // Создаем свои данные
    protected function createData() {
        $data = new Data();
        $field = new Field($this->getName());
        $field->setData($this->getContent());
        $data->addField($field);

        return $data;
    }

    /**
     * Get text block content.
     *
     * @return string
     */
    protected function getContent() {
        return $this->content;
    }

    /**
     * Блоки страницы (smap_id; null — глобальные) на языке: tb_num → [id, content]; один запрос на страницу и язык
     * за время запроса (статический кэш живёт один запрос PHP).
     *
     * @return array<string, array{id: string, content: string|null}>
     */
    protected static function pageBlocks(?int $smapId, int $langId): array {
        static $cache = [];
        $key = ($smapId ?? 'global') . ':' . $langId;
        if (!isset($cache[$key])) {
            $cache[$key] = [];
            $rows = E()->getDB()->rows('SELECT st.tb_num, st.tb_id AS id, stt.tb_content AS content FROM share_textblocks st '
                . 'LEFT JOIN share_textblocks_translation stt ON st.tb_id = stt.tb_id AND stt.lang_id = ? '
                . 'WHERE smap_id ' . ($smapId === null ? 'IS NULL' : '= ?'), $smapId === null ? [$langId] : [$langId, $smapId]);
            foreach ($rows as $row) {
                $cache[$key][(string)$row['tb_num']] = ['id' => $row['id'], 'content' => $row['content']];
            }
        }
        return $cache[$key];
    }

    /**
     * Get text block ID.
     *
     * @return int
     */
    protected function getID() {
        return $this->id;
    }

    /**
     * @copydoc DataSet::createToolbar
     */
    protected function loadToolbar() {
        return false;
    }

    /**
     * @copydoc DataSet::buildJS
     */
    protected function buildJS() {
        $result = false;

        if ($this->isEditable) {

            $result = parent::buildJS();
        }

        return $result;
    }

    /**
     * Окно истории текста блока (TextBlockHistory): версии текущего языка, просмотр и откат.
     */
    protected function history() {
        $this->request->shiftPath(1);
        $docID = (intval($this->getParam('num')) !== 0) ? $this->document->getID() : '';
        $tbID = $this->getTextBlockID($docID, $this->getParam('num'));
        $this->historyWindow = $this->document->componentManager->createComponent('history',
            'Energine\\share\\components\\TextBlockHistory', ['tb_id' => (int)$tbID, 'lang_id' => (int)$this->document->getLang()]);
        $this->historyWindow->run();
    }

    /**
     * @copydoc DataSet::build
     */
    public function build() {
        if ($this->getState() === 'history') {
            return $this->historyWindow->build();
        }
        return parent::build();
    }

    /**
     * Save data.
     */
    protected function save() {
        $this->dbh->beginTransaction();
        try {

            if (!isset($_POST['data']) && !isset($_POST['num'])) {
                throw new SystemException('ERR_DEV_NO_DATA', SystemException::ERR_DEVELOPER);
            }
            $langID = $this->document->getLang();
            $docID = (isset($_POST['ID'])) ? $_POST['ID'] : '';
            //пытаемся определить есть ли у нас запись о содержимом блока в основной таблице

            $tbID = $this->getTextBlockID($docID, $_POST['num']);
            $result = DataSet::cleanupHTML($_POST['data']);
            if (trim($result) && !$tbID) {
                $tbID = $this->dbh->modify(QAL::INSERT, $this->tableName, array('smap_id' => $docID, 'tb_num' => $_POST['num']));
            }
            if ($tbID) {
                // прежний текст языка — в историю, текст — в перевод (пустой — удаление перевода и, если переводов не
                // осталось, блока); сохранение — событие журнала и дата страницы
                (new TextHistory())->store((int)$tbID, (int)$langID, trim($result) ? $result : '');
            }
            $this->dbh->commit();
            $response = ['result' => true, 'data' => $result, 'tb_id' => $tbID ? (int)$tbID : null];
        } catch (\Exception $e) {
            $this->dbh->rollback();
            $response = ['result' => false, 'errors' => [['message' => $e->getMessage()]]];
        }

        // ответ — JSON: правка на странице (PageEditor) считает сохранённым только {result: true}
        $this->response->setHeader('Content-Type', 'application/json; charset=utf-8');
        $this->response->write(json_encode($response, JSON_UNESCAPED_UNICODE));
        $this->response->commit();
    }
}

/**
 * Fake interface to create sample.
 *
 * @code
interface SampleTextBlock;
@endcode
 */
interface SampleTextBlock {
}