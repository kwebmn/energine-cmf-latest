<?php
/**
 * @file
 * ExtendedFeedEditor
 *
 * It contains the definition to:
 * @code
class ExtendedFeedEditor;
@endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2011
 *
 * @version 1.0.0
 */
namespace Energine\apps\components;
use Energine\share\gears\ExtendedSaver, Energine\share\gears\JSONCustomBuilder;
/**
 * Media feed editor.
 *
 * @code
class ExtendedFeedEditor;
@endcode
 */
class ExtendedFeedEditor extends FeedEditor {
    /**
     * Publication field name-ID
     * Имя поля - идентификатора публикации
     * @var string $publishFieldName
     */
    private $publishFieldName = false;

    /**
     * @copydoc FeedEditor::__construct
     */
    public function __construct($name,  ?array $params = null) {
        parent::__construct($name, $params);
        $this->setSaver(new ExtendedSaver());
    }

    /**
     * @copydoc FeedEditor::setParam
     */
    protected function setParam($name, $value) {
        if ($name == 'tableName') {
            foreach (array_keys($this->dbh->getColumnsInfo($value)) as $columnName) {
                if (strpos($columnName, '_is_published')) {
                    $this->publishFieldName = $columnName;
                    $this->addTranslation('BTN_PUBLISH', 'BTN_UNPUBLISH');
                    break;
                }
            }
        }
        parent::setParam($name, $value);
    }


    /**
     * Publish material.
     */
    protected function publish() {
        list($id) = $this->getStateParams();
        $this->dbh->modify('UPDATE ' . $this->getTableName() . ' SET ' . $this->publishFieldName . ' = NOT ' . $this->publishFieldName . ' WHERE ' . $this->getPK() . ' = %s', $id);

        $b = new JSONCustomBuilder();
        $b->setProperties(
            array(
                'result' => true
            )
        );
        $this->setBuilder($b);
    }

}