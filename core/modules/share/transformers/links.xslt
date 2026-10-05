<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- «Битые ссылки» (BrokenLinks): таблица битых ссылок и отдельный список ссылок на страницы только для вошедших -->
    <xsl:template match="component[@class='BrokenLinks']">
        <xsl:variable name="BROKEN" select="links/link[@members='0']"/>
        <xsl:variable name="MEMBERS" select="links/link[@members='1']"/>
        <p class="a:text-sm a:text-muted"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_HINT']"/></p>
        <xsl:choose>
            <xsl:when test="$BROKEN">
                <div class="a:overflow-x-auto">
                    <table class="a:w-full a:border-collapse a:text-sm">
                        <thead><tr>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_PAGE']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_LANG']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_LINK']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_REASON']"/></th>
                        </tr></thead>
                        <tbody>
                            <xsl:for-each select="$BROKEN">
                                <xsl:variable name="R" select="@reason"/>
                                <tr>
                                    <td class="a:border-b a:border-border a:p-2"><a href="{$BASE}{@page}"><xsl:value-of select="@page"/></a></td>
                                    <td class="a:border-b a:border-border a:p-2"><xsl:value-of select="@lang"/></td>
                                    <td class="a:border-b a:border-border a:p-2 a:break-all"><code><xsl:value-of select="@link"/></code></td>
                                    <td class="a:border-b a:border-border a:p-2 a:text-danger"><xsl:value-of select="$TRANSLATION[@const=$R]"/></td>
                                </tr>
                            </xsl:for-each>
                        </tbody>
                    </table>
                </div>
            </xsl:when>
            <xsl:otherwise>
                <p class="a:rounded-ui a:bg-ok-bg a:px-4 a:py-3"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_NONE']"/></p>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="$MEMBERS">
            <details class="a:mt-6">
                <summary class="a:cursor-pointer"><xsl:value-of select="$TRANSLATION[@const='TXT_LINKS_MEMBERS']"/> (<xsl:value-of select="count($MEMBERS)"/>)</summary>
                <ul class="a:mt-2 a:text-sm">
                    <xsl:for-each select="$MEMBERS">
                        <li><a href="{$BASE}{@page}"><xsl:value-of select="@page"/></a> [<xsl:value-of select="@lang"/>]: <code><xsl:value-of select="@link"/></code></li>
                    </xsl:for-each>
                </ul>
            </details>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
