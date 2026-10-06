<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- «Поиск по сайту» в админке (SearchLog): журнал поиска — запрос, язык, сколько раз, сколько нашлось, когда;
         сначала запросы без результатов (число найденного — красным) -->
    <xsl:template match="component[@class='SearchLog']">
        <p class="a:text-sm a:text-muted"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_HINT']"/></p>
        <xsl:choose>
            <xsl:when test="searchlog/entry">
                <div class="a:overflow-x-auto">
                    <table class="a:w-full a:border-collapse a:text-sm">
                        <thead><tr>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_QUERY']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_LANG']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-right"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_COUNT']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-right"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_RESULTS']"/></th>
                            <th class="a:border-b a:border-border a:p-2 a:text-left"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_LAST']"/></th>
                        </tr></thead>
                        <tbody>
                            <xsl:for-each select="searchlog/entry">
                                <tr>
                                    <td class="a:border-b a:border-border a:p-2 a:break-all"><xsl:value-of select="@query"/></td>
                                    <td class="a:border-b a:border-border a:p-2"><xsl:value-of select="@lang"/></td>
                                    <td class="a:border-b a:border-border a:p-2 a:text-right"><xsl:value-of select="@count"/></td>
                                    <td class="a:border-b a:border-border a:p-2 a:text-right">
                                        <xsl:if test="@results = 0"><xsl:attribute name="class">a:border-b a:border-border a:p-2 a:text-right a:text-danger</xsl:attribute></xsl:if>
                                        <xsl:value-of select="@results"/>
                                    </td>
                                    <td class="a:border-b a:border-border a:p-2 a:whitespace-nowrap"><xsl:value-of select="@last"/></td>
                                </tr>
                            </xsl:for-each>
                        </tbody>
                    </table>
                </div>
            </xsl:when>
            <xsl:otherwise>
                <p class="a:rounded-ui a:bg-ok-bg a:px-4 a:py-3"><xsl:value-of select="$TRANSLATION[@const='TXT_SEARCH_LOG_NONE']"/></p>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
