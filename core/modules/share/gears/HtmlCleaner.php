<?php
/**
 * @file
 * HtmlCleaner — очистка HTML от мусора Office/Word (надёжность 6, вместо расширения tidy, которого на сервере нет).
 */
namespace Energine\share\gears;

/**
 * Убирает только то, что приносит вставка из Word и других программ Office, и не трогает разметку владельца:
 * - комментарии (в том числе условные <!--[if gte mso 9]> … <![endif]-->);
 * - <meta>, <link>, <xml>, <title> внутри текста и <style> с объявлениями Office (mso-, Mso…);
 * - элементы с двоеточием в имени (o:p, w:sdt, v:shape, st1:place) и <font> — сами элементы, содержимое остаётся;
 * - атрибуты с двоеточием в имени (o:spid, xmlns:o), классы Mso…, объявления mso-… в style (пустые атрибуты — прочь).
 * Текст без признаков Office возвращается тем же и не разбирается вовсе: iframe, script, значки, ссылки владельца,
 * сущности — байт в байт.
 */
final class HtmlCleaner {
    /** признаки Office: без них текст не разбирается */
    private const MARKERS = '~mso-|\bclass\s*=\s*["\']?[^"\'>]*\bMso|<\w+:\w|<!--|<font\b|<xml\b|<meta\b|<link\b|<title\b~i';

    /** элементы, которых в тексте страницы не бывает: удаляются вместе с содержимым */
    private const DROP = ['meta', 'link', 'xml', 'title'];

    public static function clean(string $html): string {
        if ($html === '' || !preg_match(self::MARKERS, $html)) {
            return $html;
        }
        $doc = \Dom\HTMLDocument::createFromString('<!DOCTYPE html><html><head></head><body>' . $html . '</body></html>',
            LIBXML_NOERROR);
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
                $parent->removeChild($node);
                continue;
            }
            if (!($node instanceof \Dom\Element)) {
                continue;
            }
            $tag = strtolower($node->localName);
            if (in_array($tag, self::DROP, true)
                || ($tag === 'style' && preg_match('~mso-|Mso~i', (string)$node->textContent))) {
                $parent->removeChild($node);
                continue;
            }
            self::cleanChildren($node);
            if ($tag === 'font' || str_contains($tag, ':')) {
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

    private static function cleanAttributes(\Dom\Element $el): void {
        $names = [];
        foreach ($el->attributes as $attr) {
            $names[] = $attr->name;
        }
        foreach ($names as $name) {
            if (str_contains($name, ':')) {
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
