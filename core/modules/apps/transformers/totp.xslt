<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <xsl:template match="component[@class='TopOfThePops']">
        <div id="{generate-id(recordset)}" class="simple-tabs">
            <xsl:apply-templates />
        </div>
    </xsl:template>

    <xsl:template match="recordset[parent::component[@class='TopOfThePops']]">
        <xsl:for-each select="record[field[@name='data']/recordset]">
            <div id="tab-{position()}" class="tab-content">
                <xsl:if test="position()=1">
                    <xsl:attribute name="class">tab-content current</xsl:attribute>
                </xsl:if>
                <div class="items">
                    <xsl:for-each select="field[@name='data']/recordset/record">
                        <div class="totp_item">
                            <xsl:if test="field[@name='attachments']/recordset/record">
                                <div class="totp_image">
                                    <img src="{$RESIZER_URL}w200-h150/{field[@name='attachments']/recordset/record[1]/field[@name='file']}"
                                         alt="{field[@name='title']}"/>
                                </div>
                            </xsl:if>
                            <div class="totp_title">
                                <!-- ссылка позиции раньше никуда не выводилась -->
                                <xsl:choose>
                                    <xsl:when test="field[@name='link'] != ''">
                                        <a href="{field[@name='link']}"><xsl:value-of select="field[@name='title']"/></a>
                                    </xsl:when>
                                    <xsl:otherwise><xsl:value-of select="field[@name='title']"/></xsl:otherwise>
                                </xsl:choose>
                            </div>
                            <div class="totp_text">
                                <xsl:value-of select="field[@name='text']" disable-output-escaping="yes"/>
                            </div>
                        </div>
                    </xsl:for-each>
                </div>
            </div>
        </xsl:for-each>
        <ul class="tabs">
        <xsl:for-each select="record[field[@name='data']/recordset]">
            <li class="tab-link" data-tab="tab-{position()}">
                <xsl:if test="position()=1">
                    <xsl:attribute name="class">tab-link current</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="field[@name='name']"/>
            </li>
        </xsl:for-each>
        </ul>
    </xsl:template>

</xsl:stylesheet>
