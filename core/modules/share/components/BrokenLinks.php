<?php
/**
 * @file
 * BrokenLinks: страница админки «Битые ссылки».
 */
namespace Energine\share\components;

use Energine\share\gears\LinkChecker;

/**
 * Битые ссылки в текстах сайта (LinkChecker) — таблица для администратора: страница, язык, ссылка, причина;
 * ссылки на страницы только для вошедших — отдельным списком (гостю не откроются, но это не ошибка).
 */
class BrokenLinks extends Component {
    /** причина LinkChecker → константа перевода */
    const REASONS = [
        'нет страницы' => 'TXT_LINKS_NO_PAGE',
        'нет файла' => 'TXT_LINKS_NO_FILE',
        'страница отключена' => 'TXT_LINKS_DISABLED',
        'вне сайта' => 'TXT_LINKS_OUTSIDE',
        LinkChecker::MEMBERS_ONLY => 'TXT_LINKS_MEMBERS_ONLY',
    ];

    public function build() {
        $result = parent::build();
        foreach (array_merge(array_values(self::REASONS), ['TXT_LINKS_NONE', 'TXT_LINKS_MEMBERS', 'TXT_LINKS_PAGE', 'TXT_LINKS_LANG',
                     'TXT_LINKS_LINK', 'TXT_LINKS_REASON', 'TXT_LINKS_HINT']) as $const) {
            $this->document->addTranslation($const, $this);
        }
        $site = E()->getSiteManager()->getCurrentSite();
        $checker = new LinkChecker(E()->getDB()->getPDO(), HTDOCS_DIR, (string)parse_url($site->base, PHP_URL_HOST),
            (string)$site->root);
        $list = $this->doc->createElement('links');
        foreach ($checker->check() as $b) {
            $link = $this->doc->createElement('link');
            foreach (['page', 'lang', 'link'] as $attr) {
                $link->setAttribute($attr, $b[$attr]);
            }
            $link->setAttribute('reason', self::REASONS[$b['reason']] ?? $b['reason']);
            $link->setAttribute('members', $b['reason'] === LinkChecker::MEMBERS_ONLY ? '1' : '0');
            $list->appendChild($link);
        }
        // build() компонента отдаёт документ: список — в его корневой элемент component
        ($result instanceof \DOMDocument ? $result->documentElement : $result)->appendChild($list);
        return $result;
    }
}
