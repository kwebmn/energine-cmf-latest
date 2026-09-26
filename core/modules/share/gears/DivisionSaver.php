<?php
/**
 * @file
 * DivisionSaver
 *
 * It contains the definition to:
 * @code
class DivisionSaver;
 * @endcode
 *
 * @author d.pavka
 * @copyright d.pavka@gmail.com
 *
 * @version 1.0.0
 */
namespace Energine\share\gears;


/**
 * Saver for division editor.
 *
 * @code
class DivisionSaver;
 * @endcode
 */
class DivisionSaver extends ExtendedSaver {

    /**
     * @copydoc ExtendedSaver::validate
     */
    public function validate() {
        // Для метода редактирования заглавной страницы удаляем описание.
        // Поле родителя приходит не из каждой формы: редакторы, которые правят
        // только часть свойств раздела (категории каталога, например), его не
        // выводят. Прежний код звал getRowData() прямо у результата
        // getFieldByName(), а тот при отсутствии поля возвращает false, и
        // сохранение обрывалось фатальной ошибкой.
        $pidField = $this->getData()->getFieldByName('smap_pid');
        if (!$pidField || !$pidField->getRowData(0)) {
            if ($segment = $this->getDataDescription()->getFieldDescriptionByName('smap_segment')) {
                $this->getDataDescription()->removeFieldDescription($segment);
            }
        }
        return parent::validate();
    }

    /**
     * @copydoc ExtendedSaver::save
     */
    public function save() {
        if (($f = $this->getData()->getFieldByName('smap_segment')) && !$f->getRowData(0)) {
            $f->setData(Translit::asURLSegment($this->getData()->getFieldByName('smap_name')->getRowData(0)), true);
        }
        // сегмент адреса у разделов одного родителя не повторяется (ключ smap_pid, smap_segment): отказ до записи —
        // сообщением для человека, а не текстом ошибки SQL
        $id = (int)($_POST['share_sitemap']['smap_id'] ?? 0);
        $pidField = $this->getData()->getFieldByName('smap_pid');
        $pid = $pidField ? $pidField->getRowData(0)
            : ($id ? $this->dbh->getScalar('share_sitemap', 'smap_pid', ['smap_id' => $id]) : null);
        if ($f && $pid && $this->dbh->getScalar('SELECT COUNT(*) FROM share_sitemap WHERE smap_pid = %s AND smap_segment = %s AND smap_id <> %s',
                $pid, $f->getRowData(0), $id)) {
            throw new SystemException('ERR_SEGMENT_EXISTS', SystemException::ERR_WARNING);
        }

        //Проверяем изменился ли лейаут или контент

        //Значит - редактирование
        if ($prevTemplateData =
            $this->dbh->select('share_sitemap', ['smap_layout', 'smap_content'], ['smap_id' => $_POST['share_sitemap']['smap_id']])
        ) {
            list($prevTemplateData) = $prevTemplateData;
        }

        $result = parent::save();
        $smapID = ($this->getMode() ==
            QAL::INSERT) ? $result : $this->getData()->getFieldByName('smap_id')->getRowData(0);

        if ($this->getMode() !== QAL::INSERT) {
            $data = [];
            if (isset($_POST[$this->getTableName()]['smap_content_xml'])) {
                $data['smap_content_xml'] = $_POST[$this->getTableName()]['smap_content_xml'];
            }

            // Для апдейта - проверяем не изменился ли лейаут или контент.
            // Поля шаблонов есть только в полном редакторе структуры, поэтому
            // проверяем их наличие: у сокращённых форм их нет.
            if (($layout = $this->getData()->getFieldByName('smap_layout'))
                && $prevTemplateData['smap_layout'] != $layout->getRowData(0)
            ) {
                $data['smap_layout_xml'] = '';
            }
            if (($content = $this->getData()->getFieldByName('smap_content'))
                && $prevTemplateData['smap_content'] != $content->getRowData(0)
            ) {
                $data['smap_content_xml'] = '';
            }

            if (!empty($data)) {
                $this->dbh->modify(QAL::UPDATE, 'share_sitemap', $data, ['smap_id' => $smapID]);
            }
        }

        // Права переписываем только если форма их прислала: у сокращённых
        // редакторов вкладки прав нет, и прежний безусловный DELETE стирал
        // права раздела, а обращение к $_POST['right_id'] падало.
        if (isset($_POST['right_id']) && is_array($_POST['right_id'])) {
            //Удаляем все предыдущие записи в таблице прав
            $this->dbh->modify(QAL::DELETE, 'share_access_level', NULL, ['smap_id' => $smapID]);
            foreach ($_POST['right_id'] as $groupID => $rightID) {
                if ($rightID != ACCESS_NONE) {
                    $this->dbh->modify(QAL::INSERT, 'share_access_level', ['smap_id' => $smapID, 'right_id' => $rightID, 'group_id' => $groupID]);
                }
            }
        }
        return $result;
    }
}