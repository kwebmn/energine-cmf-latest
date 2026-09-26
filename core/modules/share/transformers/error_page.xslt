<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!--
        Страница ошибки вне раскладки сайта (ErrorDocument): исключение до того, как страница собрана,
        отказ по адресу single-режима. Каркас — как у темы: ссылка «к содержимому», шапка, main#content;
        стили — main.css темы. Заголовок — текст ошибки, под ним ссылка на главную на языке страницы.
        Файл, строка и цепочка вызовов — только в режиме отладки. Переводов у ErrorDocument нет:
        подписи — здесь, на русском и украинском.
    -->

    <xsl:output method="html" doctype-system="about:legacy-compat" encoding="utf-8" indent="yes"/>

    <xsl:variable name="BASE" select="/document/properties/property[@name='base']"/>
    <xsl:variable name="FOLDER" select="$BASE/@folder"/>
    <xsl:variable name="LANG" select="/document/properties/property[@name='lang']"/>
    <xsl:variable name="HOME" select="concat($BASE, $LANG/@abbr)"/>
    <xsl:variable name="UA" select="$LANG/@real_abbr = 'ua'"/>
    <xsl:variable name="IN_DEBUG_MODE" select="string(/document/@debug)"/>

    <xsl:template match="/document">
        <html>
            <xsl:attribute name="lang">
                <xsl:choose>
                    <xsl:when test="$UA">uk</xsl:when>
                    <xsl:otherwise><xsl:value-of select="$LANG/@real_abbr"/></xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
            <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <meta name="robots" content="noindex"/>
                <title><xsl:value-of select="errors/error[1]/message"/></title>
                <base href="{$BASE}"/>
                <link rel="icon" type="image/x-icon" href="{$BASE}images/energine.ico"/>
                <link rel="stylesheet" href="{$BASE}stylesheets/{$FOLDER}/main.css"/>
            </head>
            <body>
                <a class="skip-link" href="#content">
                    <xsl:choose><xsl:when test="$UA">До змісту</xsl:when><xsl:otherwise>К содержимому</xsl:otherwise></xsl:choose>
                </a>
                <header class="site-header">
                    <div class="wrap site-header__inner">
                        <a class="site-name" href="{$HOME}">
                            <xsl:value-of select="substring-before(concat(substring-after($BASE, '://'), '/'), '/')"/>
                        </a>
                    </div>
                </header>
                <div class="wrap site-body">
                    <main id="content" class="site-main error_page" tabindex="-1">
                        <xsl:apply-templates select="errors/error"/>
                        <p class="error_home">
                            <a href="{$HOME}">
                                <xsl:choose><xsl:when test="$UA">На головну сторінку</xsl:when><xsl:otherwise>На главную страницу</xsl:otherwise></xsl:choose>
                            </a>
                        </p>
                        <xsl:if test="$IN_DEBUG_MODE = '1'">
                            <xsl:apply-templates select="errors/backtrace"/>
                        </xsl:if>
                    </main>
                </div>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="error">
        <xsl:choose>
            <xsl:when test="position() = 1"><h1 class="error_title"><xsl:value-of select="message"/></h1></xsl:when>
            <xsl:otherwise><p class="error_title"><xsl:value-of select="message"/></p></xsl:otherwise>
        </xsl:choose>
        <xsl:if test="$IN_DEBUG_MODE = '1'">
            <p class="error_debug"><code><xsl:value-of select="@file"/>:<xsl:value-of select="@line"/></code></p>
            <xsl:if test="customMessage">
                <ul class="error_debug">
                    <xsl:apply-templates select="customMessage"/>
                </ul>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="customMessage">
        <li><pre><xsl:value-of select="."/></pre></li>
    </xsl:template>

    <xsl:template match="backtrace">
        <ol class="error_debug">
            <xsl:apply-templates select="call"/>
        </ol>
    </xsl:template>

    <xsl:template match="backtrace/call">
        <li>
            <code><xsl:value-of select="file"/>(<xsl:value-of select="line"/>)</code><br/>
            <xsl:value-of select="class"/><xsl:value-of select="type"/><xsl:value-of select="function"/>()
        </li>
    </xsl:template>

</xsl:stylesheet>
