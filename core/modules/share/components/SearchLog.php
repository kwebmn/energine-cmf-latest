<?php
/**
 * @file
 * SearchLog: страница админки «Поиск по сайту» — журнал поиска.
 */
namespace Energine\share\components;

/**
 * Что искали посетители (share_search_log, пишет SiteSearch::log) — таблица для администратора: запрос, язык, сколько
 * раз искали, сколько нашлось в последний раз, когда; сначала запросы без результатов (каких страниц или слов не
 * хватает), затем частые.
 */
class SearchLog extends Component {
    /** строк в таблице */
    const LIMIT = 300;

    public function build() {
        $result = parent::build();
        foreach (['TXT_SEARCH_LOG_HINT', 'TXT_SEARCH_LOG_NONE', 'TXT_SEARCH_LOG_QUERY', 'TXT_SEARCH_LOG_LANG', 'TXT_SEARCH_LOG_COUNT',
                     'TXT_SEARCH_LOG_RESULTS', 'TXT_SEARCH_LOG_LAST'] as $const) {
            $this->document->addTranslation($const, $this);
        }
        $list = $this->doc->createElement('searchlog');
        foreach ($this->dbh->rows('SELECT l.log_query, g.lang_abbr, l.log_count, l.log_results, l.log_last FROM share_search_log l'
                . ' JOIN share_languages g USING (lang_id) ORDER BY l.log_results > 0, l.log_count DESC, l.log_last DESC LIMIT '
                . self::LIMIT) as $row) {
            $entry = $this->doc->createElement('entry');
            $entry->setAttribute('query', (string)$row['log_query']);
            $entry->setAttribute('lang', (string)$row['lang_abbr']);
            $entry->setAttribute('count', (string)$row['log_count']);
            $entry->setAttribute('results', (string)$row['log_results']);
            $entry->setAttribute('last', date('d.m.Y H:i', strtotime((string)$row['log_last'])));
            $list->appendChild($entry);
        }
        // build() компонента отдаёт документ: журнал — в его корневой элемент component
        ($result instanceof \DOMDocument ? $result->documentElement : $result)->appendChild($list);
        return $result;
    }
}
