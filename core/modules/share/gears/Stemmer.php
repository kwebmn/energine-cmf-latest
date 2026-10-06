<?php
/**
 * @file
 * Stemmer — основы слов для поиска по сайту (ru, ua, en): отсечение окончаний по спискам в коде.
 */
namespace Energine\share\gears;

/**
 * Основа слова: нижний регистр, ё → е, отсечение самого длинного окончания из списка так, чтобы осталось не меньше трёх
 * букв. Кириллица — окончания русского и украинского языков (имена, прилагательные, частые глагольные), латиница —
 * английские. Точности морфологического словаря нет и не нужно: «услуги», «услуга», «услугами», «услугу» дают одну
 * основу «услуг», а поиск сравнивает основы по началу (услуг*).
 */
final class Stemmer {
    /** окончания кириллицы — длинные раньше коротких (общий список ru + ua) */
    private const CYRILLIC = [
        'иями', 'ями', 'ами', 'ого', 'его', 'ому', 'ему', 'ыми', 'ими', 'ової', 'еві', 'ові', 'ться', 'тись', 'ешь', 'ишь',
        'ать', 'ять', 'еть', 'ить', 'уть', 'ают', 'яют', 'ует', 'ются', 'ых', 'их', 'ой', 'ей', 'ий', 'ый', 'ая', 'яя',
        'ое', 'ее', 'ые', 'ие', 'ую', 'юю', 'ом', 'ем', 'ам', 'ям', 'ах', 'ях', 'ов', 'ев', 'ия', 'ии', 'ию', 'ью', 'ья',
        'ье', 'ьи', 'ів', 'їв', 'ою', 'єю', 'ої', 'ій', 'ім', 'ає', 'ує', 'ы', 'и', 'а', 'я', 'о', 'е', 'у', 'ю',
        'ь', 'й', 'і', 'ї', 'є',
    ];

    /** окончания латиницы — длинные раньше коротких */
    private const LATIN = ['ations', 'ation', 'ings', 'ing', 'ies', 'ied', 'es', 'ed', 'ly', 's', 'e'];

    /** самая короткая основа */
    private const MIN = 3;

    /** основа слова */
    public static function stem(string $word): string {
        $word = str_replace('ё', 'е', mb_strtolower($word));
        if (mb_strlen($word) <= self::MIN || preg_match('~\d~', $word)) {
            return $word;
        }
        static $sorted = [];
        $kind = preg_match('~\p{Cyrillic}~u', $word) ? 'cyrillic' : 'latin';
        if (!isset($sorted[$kind])) {
            // самое длинное окончание — первым
            $sorted[$kind] = $kind === 'cyrillic' ? self::CYRILLIC : self::LATIN;
            usort($sorted[$kind], fn(string $a, string $b) => mb_strlen($b) <=> mb_strlen($a));
        }
        foreach ($sorted[$kind] as $ending) {
            $cut = mb_strlen($word) - mb_strlen($ending);
            if ($cut >= self::MIN && mb_substr($word, $cut) === $ending) {
                return mb_substr($word, 0, $cut);
            }
        }
        return $word;
    }

    /**
     * Слова текста (буквы и цифры, апостроф внутри слова — часть слова: «п'ять»), в нижнем регистре, ё → е.
     *
     * @return string[]
     */
    public static function words(string $text): array {
        $text = str_replace(['ё', 'Ё', '’', 'ʼ'], ['е', 'е', "'", "'"], $text);
        preg_match_all("~[\\p{L}\\p{N}]+(?:'[\\p{L}]+)*~u", mb_strtolower($text), $m);
        return $m[0];
    }

    /**
     * Основы всех слов текста через пробел (для FULLTEXT).
     */
    public static function stems(string $text): string {
        return implode(' ', array_map([self::class, 'stem'], self::words($text)));
    }
}
