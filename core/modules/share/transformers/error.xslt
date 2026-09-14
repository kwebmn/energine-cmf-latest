<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
        version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- Страница ошибки 404/403 (Energine\share\components\ErrorComponent).
         Компонент подставляется в error.layout.xml вместо содержимого страницы.
         Без этого шаблона текст ошибки терялся, и посетитель видел пустую страницу. -->

    <xsl:template match="component[@class='ErrorComponent']">
        <div class="error_page">
            <xsl:apply-templates select="recordset/record"/>
        </div>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='ErrorComponent']]">
        <h1 class="error_title"><xsl:value-of select="field[@name='title']"/></h1>
        <p class="error_message"><xsl:value-of select="field[@name='message']"/></p>
        <xsl:if test="field[@name='hint'] != ''">
            <p class="error_hint"><xsl:value-of select="field[@name='hint']"/></p>
        </xsl:if>
        <p class="error_home">
            <a href="{$BASE}{$LANG_ABBR}"><xsl:value-of select="$TRANSLATION[@const='TXT_ERROR_GO_HOME']"/></a>
        </p>
    </xsl:template>

</xsl:stylesheet>
