<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:dyn="http://exslt.org/dynamic"
        extension-element-prefixes="dyn"
        version="1.0">

    <xsl:template match="layout | content | container">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <!--
    Контейнер может иметь следующие атрибуты:
	1) name (значение: *) - уникальное имя контейнера, обязательный атрибут
	2) html_class (значение: *) - контейнер с таким атрибутом будет выведен как div с указанным классом
	3) block (значение: alfa | beta) - указывает, что контейнер является "блоком", т.е. визуально целостным объектом, служит именно для визуального оформления, контейнер с таким атрибутом будет выведен как кусок html-кода, создающий нужное форматирование
		alfa - блок, который является "главным" на странице
		beta - любой другой блок
    -->

    <!-- Контейнеры с атрибутом html_class выводятся в виде div с соответствующим классом -->
    <xsl:template match="content[@html_class] | container[@html_class]">
        <div class="{@html_class}">
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!-- Блок - контейнер для визуального отделения одного или группы компонентов -->
    <xsl:template match="container[@block]">
        <xsl:if test="($COMPONENTS[@name='adminPanel']) or (@block='alfa') or (component[not(@sample='TextBlock') and not(recordset[@empty])]) or (component[@sample='TextBlock' and (@editable or recordset/record/field != '')])">
            <div>
                <xsl:attribute name="class">block<xsl:if test="@block='alfa'"> alfa_block</xsl:if><xsl:if test="@html_class"><xsl:text> </xsl:text><xsl:value-of select="@html_class"/></xsl:if></xsl:attribute>
                <xsl:apply-templates select="." mode="block_header"/>
                <xsl:apply-templates select="." mode="block_content"/>
            </div>
        </xsl:if>
    </xsl:template>

    <!--
        Контейнер с атрибутом contains - это холдер, куда вставляется другой контейнер или компонент. 
        Например, можно в любое место в контентном файле вызвать нужный компонент/контейнер из лейаута.
    -->
    <xsl:template match="container[@contains]">
        <xsl:variable name="CONTAINS" select="@contains"/>
        <xsl:apply-templates select="//container[@name=$CONTAINS] | $COMPONENTS[@name=$CONTAINS]"/>
    </xsl:template>

    <xsl:template match="container[@evaluate]">
        <xsl:variable name="EXPRESSION" select="@evaluate"/>
        <xsl:choose>
            <xsl:when test="@value">
                <xsl:value-of select="dyn:evaluate($EXPRESSION)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="dyn:evaluate($EXPRESSION)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Заголовок блока по-умолчанию -->
    <xsl:template match="container[@block]" mode="block_header">
        <xsl:variable name="MAIN_COMPONENT" select="component[1]"/>
        <xsl:if test="$MAIN_COMPONENT/@title">
            <div class="block_header clearfix">                
                <h2 class="block_title"><xsl:value-of select="$MAIN_COMPONENT/@title" disable-output-escaping="yes"/></h2>
            </div>
        </xsl:if>
    </xsl:template>

    <!-- Контент блока по-умолчанию -->
    <xsl:template match="container[@block]" mode="block_content">
        <div class="block_content clearfix">
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!-- Заголовок alfa-блока -->
    <xsl:template match="container[@block='alfa']" mode="block_header">
        <xsl:if test="$DOC_PROPS[@name='default'] != 1">
            <div class="block_header clearfix">
                <h1 class="block_title"><xsl:value-of select="$DOC_PROPS[@name='title']" disable-output-escaping="yes"/></h1>
            </div>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
