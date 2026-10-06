<?php
/**
 * @file
 * HtmlCleaner — очистка HTML от мусора Office/Word (надёжность 6, вместо расширения tidy, которого на сервере нет).
 */
namespace Energine\share\gears;

/**
 * Убирает только следы Office/Word и не трогает разметку владельца:
 * - комментарии Office: условные <!--[if …]> … <![endif]-->, <![if …]>, <!--StartFragment-->; прочие (noindex) — остаются;
 * - <xml>, <meta> Word (ProgId, Generator, Originator, Content-Type), <link> Word (File-List, themeData …), <style> с
 *   объявлениями Office (mso-, Mso…);
 * - элементы с офисным префиксом (o:p, w:sdt, v:shape, st1:place) и <font> — сами элементы, содержимое остаётся;
 *   маркер списка Word (mso-list:Ignore: «·» и пробелы) — целиком;
 * - атрибуты с офисным префиксом (o:spid, v:shapes, x:str, xmlns:o), классы Mso…, объявления mso-… в style.
 * Текст без следов Office возвращается тем же и не разбирается вовсе: iframe, script, svg, значки, ссылки, комментарии
 * noindex, атрибуты виджетов (x-on:click, :class) — байт в байт.
 */
final class HtmlCleaner {
    /** следы Office: без них текст не разбирается */
    private const MARKERS = '~mso-|\bclass\s*=\s*["\']?[^"\'>]*\bMso|<(?:o|w|v|m|st\d+):\w|<!--\s*\[if|<!\[if|<!--\s*(?:Start|End)Fragment'
        . '|xmlns:(?:o|w|v|m|x)\b|urn:schemas-microsoft-com|<meta[^>]+(?:ProgId|Generator|Originator)'
        . '|<link[^>]+rel\s*=\s*["\']?(?:File-List|Edit-Time-Data|themeData|colorSchemeMapping|OLE-Object-Data)~i';

    /** офисный префикс имени элемента или атрибута */
    private const OFFICE_PREFIX = '~^(?:o|w|v|x|m|st\d+):~i';

    public static function clean(string $html): string {
        if ($html === '' || !preg_match(self::MARKERS, $html)) {
            return $html;
        }
        // кодировка — всегда UTF-8: иначе <meta charset="windows-1251"> в самом тексте перекодировал бы его в кракозябры
        $doc = \Dom\HTMLDocument::createFromString('<!DOCTYPE html><html><head></head><body>' . $html . '</body></html>',
            LIBXML_NOERROR, 'UTF-8');
        $body = $doc->body;
        if (!$body) {
            return $html;
        }
        self::cleanChildren($body);
        return $body->innerHTML;
    }

    private static function cleanChildren(\Dom\Node $parent): void {
        for ($node = $parent->firstChild; $node; $node = $next) {
            $next = $node->nextSibling;
            if ($node instanceof \Dom\Comment) {
                if (preg_match('~^\s*(?:\[if|\[endif|(?:Start|End)Fragment)~i', (string)$node->data)) {
                    $parent->removeChild($node);
                }
                continue;
            }
            if (!($node instanceof \Dom\Element)) {
                continue;
            }
            if (self::isJunk($node)) {
                $parent->removeChild($node);
                continue;
            }
            self::cleanChildren($node);
            $tag = strtolower($node->localName);
            if ($tag === 'font' || preg_match(self::OFFICE_PREFIX, $tag)) {
                // сам элемент Office или <font> — прочь, содержимое остаётся на его месте
                while ($node->firstChild) {
                    $parent->insertBefore($node->firstChild, $node);
                }
                $parent->removeChild($node);
                continue;
            }
            self::cleanAttributes($node);
        }
    }

    /** элемент Office, который удаляется вместе с содержимым */
    private static function isJunk(\Dom\Element $el): bool {
        $tag = strtolower($el->localName);
        $style = (string)$el->getAttribute('style');
        return $tag === 'xml'
            || ($tag === 'style' && preg_match('~mso-|Mso~i', (string)$el->textContent))
            || ($tag === 'meta' && preg_match('~^(?:ProgId|Generator|Originator)$~i', (string)$el->getAttribute('name')))
            || ($tag === 'meta' && strcasecmp((string)$el->getAttribute('http-equiv'), 'Content-Type') === 0)
            || ($tag === 'link' && preg_match('~^(?:File-List|Edit-Time-Data|themeData|colorSchemeMapping|OLE-Object-Data)$~i',
                (string)$el->getAttribute('rel')))
            // маркер списка Word: «·», «1.» и пробелы перед текстом пункта
            || preg_match('~mso-list\s*:\s*Ignore~i', $style);
    }

    private static function cleanAttributes(\Dom\Element $el): void {
        $names = [];
        foreach ($el->attributes as $attr) {
            $names[] = $attr->name;
        }
        foreach ($names as $name) {
            if (preg_match(self::OFFICE_PREFIX, $name) || preg_match('~^xmlns:(?:o|w|v|m|x)$~i', $name)) {
                $el->removeAttribute($name);
            }
        }
        if ($el->hasAttribute('class')) {
            $classes = array_filter(preg_split('~\s+~', trim($el->getAttribute('class'))), fn(string $c) => $c !== '' && stripos($c, 'Mso') !== 0);
            $classes ? $el->setAttribute('class', implode(' ', $classes)) : $el->removeAttribute('class');
        }
        if ($el->hasAttribute('style')) {
            $rules = array_filter(array_map('trim', explode(';', $el->getAttribute('style'))),
                fn(string $r) => $r !== '' && stripos($r, 'mso-') !== 0);
            $rules ? $el->setAttribute('style', implode(';', $rules)) : $el->removeAttribute('style');
        }
    }
}
