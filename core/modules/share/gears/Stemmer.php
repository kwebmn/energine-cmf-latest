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

    /** слово текста: буквы и цифры; апостроф внутри слова (п'ять, м’ясо, комп'ютер) — часть слова */
    const WORD = "~[\\p{L}\\p{N}]+(?:['’ʼ][\\p{L}]+)*~u";

    /**
     * Слово для основы: нижний регистр, ё → е, без апострофов — FULLTEXT делит слово по апострофу («п'ять» — «п» и
     * «ять», обе части короче трёх букв и в индекс не попадают), а «пять» — одно слово.
     */
    public static function normal(string $word): string {
        return str_replace(['ё', "'", '’', 'ʼ'], ['е', '', '', ''], mb_strtolower($word));
    }

    /** основа слова */
    public static function stem(string $word): string {
        $word = self::normal($word);
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
     * Слова текста (WORD) в виде normal(): нижний регистр, ё → е, без апострофов («П'ять» — «пять»).
     *
     * @return string[]
     */
    public static function words(string $text): array {
        preg_match_all(self::WORD, $text, $m);
        return array_map([self::class, 'normal'], $m[0]);
    }

    /**
     * Основы всех слов текста через пробел (для FULLTEXT).
     */
    public static function stems(string $text): string {
        return implode(' ', array_map([self::class, 'stem'], self::words($text)));
    }
}
