<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
        version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- Облако тегов (Energine\apps\components\TagCloud).
         Ссылка ведёт в состояние tag связанной ленты. Компонент задаёт свойство template,
         когда фильтрует по родительскому разделу; иначе лента на этой же странице. -->

    <xsl:template match="component[@class='TagCloud']">
        <xsl:if test="recordset/record">
            <div class="tag_cloud">
                <h3 class="tag_cloud_title">
                    <xsl:choose>
                        <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="$TRANSLATION[@const='TXT_TAGS']"/></xsl:otherwise>
                    </xsl:choose>
                </h3>
                <ul class="tag_cloud_list">
                    <xsl:apply-templates select="recordset/record"/>
                </ul>
            </div>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='TagCloud']]">
        <xsl:variable name="FEED">
            <xsl:choose>
                <xsl:when test="ancestor::component/@template"><xsl:value-of select="ancestor::component/@template"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$TEMPLATE"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <li class="tag_cloud_item">
            <a class="tag_cloud_link"
               href="{$BASE}{$LANG_ABBR}{$FEED}tag/{field[@name='tag_id']}/"
               data-frequency="{field[@name='tag_id']/@frequency}">
                <xsl:value-of select="field[@name='tag_name']"/>
            </a>
        </li>
    </xsl:template>

    <xsl:template match="field[ancestor::component[@class='TagCloud']]"/>

</xsl:stylesheet>
