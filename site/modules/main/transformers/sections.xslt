<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!--
        Секции визиток (подпроект 2): контейнер шаблона содержимого с атрибутом section и текстовым блоком внутри.
        <container name="hero" section="hero"><component class="Energine\share\components\TextBlock">
            <params><param name="num">11</param><param name="section_sample">TXT_SECTION_SAMPLE_HERO</param></params></component></container>
        num — число (нечисловой num у TextBlock — глобальный блок, общий для всех страниц).
        Вид текста владельца — правила .ui-section-<имя> в tailwind.css (@layer components): классы в тексте не нужны.
        Пустая секция гостю не выводится; в режиме правки вместо пустоты — образец (константа section_sample).
    -->


    <xsl:template match="container[contains(' hero services prices reviews gallery faq contacts cta ', concat(' ', @section, ' '))]" priority="2">
        <xsl:variable name="TB" select="component[@sample='TextBlock'][1]"/>
        <xsl:if test="$TB/@editable or $TB/recordset/record/field != ''">
            <section data-section="{@section}" class="ui-section ui-section-{@section} {$UI_SECTION}">
                <div class="{$UI_CONTAINER}">
                    <xsl:apply-templates select="$TB/recordset/record"/>
                </div>
            </section>
        </xsl:if>
    </xsl:template>

    <!-- пустая секция в режиме правки: редактор с образцом вместо прочерка -->
    <xsl:template match="container[@section]/component[@sample='TextBlock' and @editable]/recordset/record[not(field != '')]" priority="2">
        <xsl:variable name="TB" select="../.."/>
        <div id="{generate-id(.)}" class="nrgnEditor" single_template="{$BASE}{$LANG_ABBR}{$TB/@single_template}" num="{$TB/@num}" eID="{$ID}">
            <xsl:value-of select="$TRANSLATION[@const = $TB/@section_sample]" disable-output-escaping="yes"/>
        </div>
    </xsl:template>

</xsl:stylesheet>
