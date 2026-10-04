<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!--
        Компоненты интерфейса сайта на утилитах Tailwind (подпроект 1): строки утилит живут здесь, шаблоны
        страниц вызывают компоненты. Цвета и радиусы — переменные дизайна (@theme в tailwind.css):
        цвета bg, fg, muted, border, primary, danger, ok; радиус rounded-ui; ширина страницы UI_CONTAINER.
    -->

    <!-- ширина страницы с полями по бокам -->
    <xsl:variable name="UI_CONTAINER">mx-auto w-full max-w-(--container-page) px-4</xsl:variable>

    <!-- кнопка: variant = primary | plain | link -->
    <xsl:template name="ui-button-class">
        <xsl:param name="variant" select="'primary'"/>
        <xsl:choose>
            <xsl:when test="$variant = 'link'">cursor-pointer border-0 bg-transparent p-0 font-[inherit] text-primary underline underline-offset-2</xsl:when>
            <xsl:when test="$variant = 'plain'">inline-flex cursor-pointer items-center gap-2 rounded-ui border border-border bg-bg px-4 py-2 font-semibold text-fg hover:border-primary</xsl:when>
            <xsl:otherwise>inline-flex cursor-pointer items-center gap-2 rounded-ui border border-primary bg-primary px-5 py-2.5 font-semibold text-primary-fg hover:brightness-110</xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="ui-button">
        <xsl:param name="text"/>
        <xsl:param name="variant" select="'primary'"/>
        <xsl:param name="type" select="'submit'"/>
        <xsl:param name="name"/>
        <xsl:param name="value"/>
        <button type="{$type}">
            <xsl:attribute name="class"><xsl:call-template name="ui-button-class"><xsl:with-param name="variant" select="$variant"/></xsl:call-template></xsl:attribute>
            <xsl:if test="$name"><xsl:attribute name="name"><xsl:value-of select="$name"/></xsl:attribute></xsl:if>
            <xsl:if test="$value"><xsl:attribute name="value"><xsl:value-of select="$value"/></xsl:attribute></xsl:if>
            <xsl:value-of select="$text"/>
        </button>
    </xsl:template>

    <xsl:template name="ui-link-button">
        <xsl:param name="href"/>
        <xsl:param name="text"/>
        <xsl:param name="variant" select="'primary'"/>
        <a href="{$href}">
            <xsl:attribute name="class">no-underline <xsl:call-template name="ui-button-class"><xsl:with-param name="variant" select="$variant"/></xsl:call-template></xsl:attribute>
            <xsl:value-of select="$text"/>
        </a>
    </xsl:template>

    <!-- сообщение: kind = ok | error -->
    <xsl:template name="ui-alert">
        <xsl:param name="kind" select="'ok'"/>
        <xsl:param name="text"/>
        <div>
            <xsl:attribute name="class">mb-4 rounded-ui px-4 py-3 <xsl:choose>
                <xsl:when test="$kind = 'error'">bg-danger-bg text-danger</xsl:when>
                <xsl:otherwise>bg-ok-bg text-fg</xsl:otherwise>
            </xsl:choose></xsl:attribute>
            <xsl:if test="$kind = 'error'"><xsl:attribute name="role">alert</xsl:attribute></xsl:if>
            <xsl:value-of select="$text"/>
        </div>
    </xsl:template>

    <!-- заголовок секции -->
    <xsl:template name="ui-section-title">
        <xsl:param name="text"/>
        <h2 class="mt-0 mb-4 text-2xl font-bold leading-tight"><xsl:value-of select="$text"/></h2>
    </xsl:template>

    <!-- класс карточки (обёртка содержимого вызывающего шаблона) -->
    <xsl:variable name="UI_CARD">rounded-ui border border-border bg-bg-soft p-4</xsl:variable>

</xsl:stylesheet>
