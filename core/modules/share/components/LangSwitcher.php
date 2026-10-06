<?php
/**
 * @file
 * LangSwitcher
 *
 * It contains the definition to:
 * @code
final class LangSwitcher;
 * @endcode
 *
 * @author dr.Pavka
 * @copyright Energine 2006
 *
 * @version 1.0.0
 */
namespace Energine\share\components;

use Energine\share\gears\SimpleBuilder, Energine\share\gears\Request, Energine\share\gears\DataDescription, Energine\share\gears\FieldDescription;

/**
 * language switcher.
 *
 * @code
class LangSwitcher;
 * @endcode
 */
class LangSwitcher extends DataSet {
    /**
     * @copydoc DataSet::__construct
     */
    public function __construct($name, ?array $params = NULL) {
        parent::__construct($name, $params);
        $this->setType(self::COMPONENT_TYPE_LIST);
    }

    /**
     * @copydoc DataSet::createBuilder
     */
    protected function createBuilder() {
        return new SimpleBuilder();
    }

    /**
     * @copydoc DataSet::loadData
     */
    protected function loadData() {
        $lang = E()->getLanguage();
        $data = $lang->getLanguages();
        $result = [];
        // ссылка на ту же страницу (с хвостом пути) — только на язык, где она открыта; иначе и на странице ошибки —
        // на главную языка, а не на адрес, который там ответит 404
        $available = $this->availableLanguages();
        $path = E()->getRequest()->getPath(Request::PATH_WHOLE, true);
        // Language отдаёт языки «в подготовке» только редакторам — здесь они помечаются (lang_is_active = 0)
        foreach ($data as $langID => $langInfo) {
            $abbr = $langInfo['lang_abbr'];
            if ($langInfo['lang_default']) {
                $langInfo['lang_abbr'] = '';
            }
            $result[$langID] = $langInfo;
            $result[$langID]['lang_real_abbr'] = $abbr;
            $result[$langID]['lang_id'] = $langID;
            $result[$langID]['lang_is_active'] = (!isset($langInfo['lang_is_active']) || $langInfo['lang_is_active']) ? 1 : 0;
            if (!$result[$langID]['lang_is_active']) {
                $this->document->addTranslation('TXT_LANG_INACTIVE', $this);
            }
            $result[$langID]['lang_url'] = $result[$langID]['lang_abbr'] . (($result[$langID]['lang_abbr']) ? '/' : '') .
                (in_array((int)$langID, $available, true) ? $path : '');
        }
        return $result;
    }

    /**
     * Языки, на которых открыта текущая страница: ответ не ошибка (2xx), сама страница и все её родители не выключены
     * на языке (один запрос). На странице ошибки (404, 403, 422…) — ни одного.
     *
     * @return int[]
     */
    private function availableLanguages(): array {
        $status = E()->getResponse()->getStatusCode();
        if ($status < 200 || $status >= 300 || !($id = (int)$this->document->getID())) {
            return [];
        }
        $chain = array_merge([$id], array_map('intval', array_keys(E()->getMap()->getParents($id))));
        return array_map('intval', $this->dbh->column(
            'SELECT lang_id FROM share_sitemap_translation WHERE smap_id IN (' . implode(', ', array_fill(0, count($chain), '?')) . ')'
            . ' AND smap_is_disabled = 0 GROUP BY lang_id HAVING COUNT(*) = ?', array_merge($chain, [count($chain)])));
    }

    /**
     * Create data description.
     *
     * @return DataDescription
     */
    protected function createDataDescription() {
        $result = new DataDescription();
        if (!$this->getConfig()->getCurrentStateConfig()) {
            $f = new FieldDescription('lang_id');
            $f->setType(FieldDescription::FIELD_TYPE_INT);
            $result->addFieldDescription($f);

            $f = new FieldDescription('lang_abbr');
            $f->setType(FieldDescription::FIELD_TYPE_STRING);
            $result->addFieldDescription($f);

            $f = new FieldDescription('lang_name');
            $f->setType(FieldDescription::FIELD_TYPE_STRING);
            $result->addFieldDescription($f);

            $f = new FieldDescription('lang_url');
            $f->setType(FieldDescription::FIELD_TYPE_STRING);
            $result->addFieldDescription($f);

            $f = new FieldDescription('lang_real_abbr');
            $f->setType(FieldDescription::FIELD_TYPE_STRING);
            $result->addFieldDescription($f);

            // 0 — язык «в подготовке» (виден только редактору, с пометкой)
            $f = new FieldDescription('lang_is_active');
            $f->setType(FieldDescription::FIELD_TYPE_INT);
            $result->addFieldDescription($f);
        }
        else {
            $result->loadXML($this->getConfig()->getCurrentStateConfig()->fields);
        }

        return $result;
    }


}
