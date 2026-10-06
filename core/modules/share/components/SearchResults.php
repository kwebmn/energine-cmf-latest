<?php
/**
 * @file
 * SearchResults: страница результатов поиска по сайту (/search/?q=…&page=N).
 */
namespace Energine\share\components;

use Energine\share\gears\SiteSearch;

/**
 * Поиск по сайту (SiteSearch) для посетителя: запрос q, страница выдачи page. В XML компонента — элемент search
 * (query — запрос как его показать, q — он же для адреса листалки, total, page, pages) и в нём item (url, title) с
 * отрывком snippet: текст и найденные слова в mark — узлами DOM, а не разметкой, так что текст страницы и запрос
 * экранирует преобразование. Поиск (первая страница выдачи) — строка журнала поиска (SiteSearch::log).
 */
class SearchResults extends Component {
    public function build() {
        $result = parent::build();
        foreach (['TXT_SEARCH', 'BTN_SEARCH', 'TXT_SEARCH_FOUND', 'TXT_SEARCH_HINT', 'TXT_SEARCH_NOTHING', 'TXT_SEARCH_PAGES',
                     'TXT_PREVIOUS_PAGE', 'TXT_NEXT_PAGE'] as $const) {
            $this->document->addTranslation($const, $this);
        }
        // параметры — строки (q[]=… или page=x — как их нет)
        $q = isset($_GET['q']) && is_string($_GET['q']) ? $_GET['q'] : '';
        $page = isset($_GET['page']) && is_string($_GET['page']) && ctype_digit($_GET['page']) ? (int)$_GET['page'] : 1;
        $engine = new SiteSearch(E()->getDB());
        $found = $engine->find($q, (int)$this->document->getLang(), $page);
        // журнал поиска — поиск, а не листание его страниц
        if ($found['query'] !== '' && $page === 1) {
            $engine->log($found['query'], (int)$this->document->getLang(), $found['total']);
        }

        $search = $this->doc->createElement('search');
        $search->setAttribute('query', $found['query']);
        $search->setAttribute('q', rawurlencode($found['query']));
        foreach (['total', 'page', 'pages'] as $attr) {
            $search->setAttribute($attr, (string)$found[$attr]);
        }
        foreach ($found['items'] as $item) {
            $el = $this->doc->createElement('item');
            $el->setAttribute('url', $item['url']);
            $el->setAttribute('title', $item['title']);
            $snippet = $this->doc->createElement('snippet');
            foreach ($item['snippet'] as $piece) {
                $text = $this->doc->createTextNode($piece['text']);
                if ($piece['mark']) {
                    $mark = $this->doc->createElement('mark');
                    $mark->appendChild($text);
                    $snippet->appendChild($mark);
                } else {
                    $snippet->appendChild($text);
                }
            }
            $el->appendChild($snippet);
            $search->appendChild($el);
        }
        // build() компонента отдаёт документ: результаты — в его корневой элемент component
        ($result instanceof \DOMDocument ? $result->documentElement : $result)->appendChild($search);
        return $result;
    }
}
