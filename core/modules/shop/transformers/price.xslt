<?xml version="1.0" encoding="utf-8" ?>
<!-- Шаблон цены. Вынесен отдельно, потому что его зовут и cart.xslt, и
     wishlist.xslt, и compare.xslt, а в режиме single эти файлы подключаются
     без shop.xslt: без общего файла вызов шаблона обрывал преобразование,
     и компонент отдавал пустой ответ. -->
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">
    <!-- Разделители для цен: пробел между разрядами -->
    <xsl:decimal-format name="price" grouping-separator="&#160;" decimal-separator="."/>

    <!-- Цена с обозначением валюты. Компонент отдаёт обозначение и его сторону
         в свойствах currency / currency-order, но раньше шаблоны их не читали
         и цена выводилась как «9999.00». -->
    <xsl:template name="PRICE">
        <xsl:param name="VALUE"/>
        <xsl:variable name="CUR" select="ancestor-or-self::component[@currency][1]/@currency"/>
        <xsl:variable name="ORDER" select="ancestor-or-self::component[@currency][1]/@currency-order"/>
        <xsl:variable name="NUM" select="format-number($VALUE, '#&#160;##0.##', 'price')"/>
        <xsl:choose>
            <xsl:when test="$CUR != '' and $ORDER = 'before'">
                <xsl:value-of select="concat($CUR, '&#160;', $NUM)"/>
            </xsl:when>
            <xsl:when test="$CUR != ''">
                <xsl:value-of select="concat($NUM, '&#160;', $CUR)"/>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="$NUM"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
