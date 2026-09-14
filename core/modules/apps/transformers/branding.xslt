<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
        version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- Оформление раздела (Energine\apps\components\Branding).
         Компонент находит ближайший раздел-предок, которому назначен бренд,
         и отдаёт его оформление. Без шаблона это выводилось формой полей. -->

    <xsl:template match="component[@class='Branding']">
        <xsl:if test="recordset/record">
            <xsl:for-each select="recordset/record">
                <div class="branding">
                    <xsl:attribute name="style">
                        <xsl:if test="field[@name='brand_bgcolor'] != ''">background-color: <xsl:value-of select="field[@name='brand_bgcolor']"/>;</xsl:if>
                        <xsl:if test="field[@name='brand_min_height'] != ''">min-height: <xsl:value-of select="field[@name='brand_min_height']"/>px;</xsl:if>
                    </xsl:attribute>
                    <xsl:if test="field[@name='brand_main_img'] != ''">
                        <img class="branding_image"
                             src="{$MEDIA_URL}{field[@name='brand_main_img']}"
                             alt="{field[@name='brand_name']}"/>
                    </xsl:if>
                </div>
                <!-- собственные правила оформления раздела -->
                <xsl:if test="field[@name='brand_css_rule'] != ''">
                    <style type="text/css"><xsl:value-of select="field[@name='brand_css_rule']" disable-output-escaping="yes"/></style>
                </xsl:if>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
