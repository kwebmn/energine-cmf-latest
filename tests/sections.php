<?php
// Секции визиток (site/modules/main/transformers/sections.xslt), без базы — XSLT на собранном вручную документе:
//  1. непустая секция — одна полоса section[data-section] с текстом;
//  2. пустая секция гостю не выводится;
//  3. пустая секция в режиме правки — полоса с редактором и образцом из константы TXT_SECTION_SAMPLE_<ИМЯ>;
//  4. контейнер с неизвестным именем секции выводится обычным блоком.
require __DIR__ . '/testlib.php';

const SECTIONS = ['hero', 'services', 'prices', 'reviews', 'gallery', 'faq', 'contacts', 'cta'];

// документ страницы с одним контейнером-секцией; $editable — режим правки, $sample — константа образца в документе
function sectionDoc(string $name, string $text, bool $editable): string {
    $num = 11 + (array_search($name, SECTIONS) === false ? 0 : array_search($name, SECTIONS));
    $ed = $editable ? ' editable="editable" section_sample="TXT_SECTION_SAMPLE_' . strtoupper($name) . '"' : '';
    $tr = $editable ? '<translation const="TXT_SECTION_SAMPLE_' . strtoupper($name) . '">&lt;h2&gt;Образец ' . $name . '&lt;/h2&gt;</translation>' : '';
    return '<?xml version="1.0" encoding="utf-8"?><document><properties><property name="ID">5</property>'
        . '<property name="base">https://example.org/</property><property name="lang" abbr="">1</property>'
        . '<property name="default">0</property><property name="title">Стр</property></properties>'
        . "<translations>$tr</translations><content>"
        . "<container name=\"s_$name\" section=\"$name\"><component name=\"tb_$name\" sample=\"TextBlock\" num=\"$num\"$ed>"
        . '<recordset><record><field name="tb_' . $name . '">' . htmlspecialchars($text) . '</field></record></recordset>'
        . '</component></container></content></document>';
}

function render(string $xml): DOMXPath {
    $T = ROOT . '/core/modules/share/transformers';
    $S = ROOT . '/site/modules/main/transformers';
    $xsl = '<?xml version="1.0" encoding="utf-8"?><xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">'
        . '<xsl:output method="html" encoding="utf-8"/>'
        . '<xsl:variable name="DOC_PROPS" select="/document/properties/property"/>'
        . '<xsl:variable name="COMPONENTS" select="//component[@name]"/>'
        . '<xsl:variable name="TRANSLATION" select="/document/translations/translation"/>'
        . '<xsl:variable name="ID" select="$DOC_PROPS[@name=\'ID\']"/>'
        . '<xsl:variable name="BASE" select="$DOC_PROPS[@name=\'base\']"/>'
        . '<xsl:variable name="LANG_ABBR" select="$DOC_PROPS[@name=\'lang\']/@abbr"/>'
        . "<xsl:include href=\"file://$T/container.xslt\"/><xsl:include href=\"file://$T/text.xslt\"/>"
        . "<xsl:include href=\"file://$S/ui.xslt\"/><xsl:include href=\"file://$S/sections.xslt\"/>"
        . '<xsl:template match="/"><html><body><xsl:apply-templates select="document/content"/></body></html></xsl:template>'
        . '</xsl:stylesheet>';
    $p = new XSLTProcessor();
    $s = new DOMDocument(); $s->loadXML($xsl);
    $p->importStylesheet($s);
    $d = new DOMDocument(); $d->loadXML($xml);
    $h = new DOMDocument();
    libxml_use_internal_errors(true);
    $out = $p->transformToXml($d);
    if (getenv("SECTIONS_DEBUG")) fwrite(STDERR, $out);
    $h->loadHTML('<?xml encoding="utf-8" ?>' . $out);
    libxml_clear_errors();
    return new DOMXPath($h);
}

if (!check('sections.xslt есть', is_file(ROOT . '/site/modules/main/transformers/sections.xslt'))) done('sections');

foreach (SECTIONS as $name) {
    // 1
    $x = render(sectionDoc($name, "<p>Текст $name</p>", false));
    $s = $x->query("//section[@data-section='$name']");
    check("$name: непустая — одна полоса с текстом", $s->length == 1 && str_contains($s->item(0)->textContent, "Текст $name")
        && str_contains(' ' . $s->item(0)->getAttribute('class') . ' ', " ui-section-$name "), "полос: {$s->length}");
    // 2
    $x = render(sectionDoc($name, '', false));
    check("$name: пустая гостю не выводится", $x->query('//section')->length == 0 && $x->query("//div[contains(@class,'block')]")->length == 0);
    // 3
    $x = render(sectionDoc($name, '', true));
    $ed = $x->query("//section[@data-section='$name']//div[contains(@class,'nrgnEditor')]");
    check("$name: пустая в режиме правки — редактор с образцом", $ed->length == 1
        && $x->query("//section[@data-section='$name']//div[contains(@class,'nrgnEditor')]/h2[.='Образец $name']")->length == 1
        && !str_contains($ed->item(0)->textContent, '--'), $ed->length ? trim($ed->item(0)->textContent) : 'нет редактора');
}
// 4
$x = render(str_replace('section="hero"', 'section="nope" block="beta"', sectionDoc('hero', '<p>Т</p>', false)));
check('неизвестная секция — обычный блок', $x->query('//section')->length == 0 && $x->query("//div[@class='block']")->length == 1);

done('sections');
