<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">
    <xsl:template match="component[(@class='Cart')]">
        <xsl:variable name="DELETE_URL"><xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of
                select="@single_template"/><xsl:value-of select="@delete"/></xsl:variable>
        <xsl:variable name="EDIT_URL"><xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of
                select="@single_template"/><xsl:value-of select="@edit"/></xsl:variable>
        <div id="{generate-id(recordset)}" data-delete-url="{$DELETE_URL}" data-edit-url="{$EDIT_URL}" data-count="{@count}">
            <table style="border:1px solid black;">
                <thead>
                <tr>
                    <th colspan="2"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text></th>
                    <th><xsl:value-of select="recordset/record[1]/field[@name='goods_name']/@title"/></th>
                    <th><xsl:value-of select="recordset/record[1]/field[@name='cart_goods_count']/@title"/></th>
                    <th><xsl:value-of select="recordset/record[1]/field[@name='goods_price']/@title"/></th>
                    <th><xsl:value-of select="recordset/record[1]/field[@name='cart_goods_sum']/@title"/></th>
                </tr>
                </thead>
            <xsl:for-each select="recordset/record">
                <tr>
                    <td><a href="#" class="delete" data-id="{field[@name='cart_id']}">X</a></td>
                    <td><xsl:if test="field[@name='attachments']/recordset/record"><img src="{$RESIZER_URL}w90-h68/{field[@name='attachments']/recordset/record[1]/field[@name='file']}" alt=""/></xsl:if></td>
                    <td><a href="{$BASE}{$LANG_ABBR}{field[@name='smap_id']}view/{field[@name='goods_segment']}/"><xsl:value-of
                            select="field[@name='goods_name']"/></a></td>
                    <td><input type="text" class="edit" data-id="{field[@name='cart_id']}" value="{field[@name='cart_goods_count']}"/></td>
                    <td><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="field[@name='goods_price']"/></xsl:call-template></td>
                    <td><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="field[@name='cart_goods_sum']"/></xsl:call-template></td>
                </tr>
            </xsl:for-each>
                <tfoot>
                    <tr>
                        <td colspan="5"><xsl:value-of select="recordset/record[1]/field[@name='cart_goods_sum']/@title"/>:</td>
                        <td><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="sum(recordset/record/field[@name='cart_goods_sum'])"/></xsl:call-template></td>
                    </tr>
                </tfoot>
            </table>
            <xsl:apply-templates select="toolbar"/>
        </div>

    </xsl:template>

    <!-- informer: CartDaemon.js adds goods by data-add-url and shows the new count (data-count of the answer) -->
    <xsl:template match="component[(@class='Cart') and (@componentAction='main')]">
        <div id="{generate-id(recordset)}" class="cart_informer" data-url="{$BASE}{$LANG_ABBR}{@single_template}{@action}"
             data-add-url="{$BASE}{$LANG_ABBR}{@single_template}{@action}" data-load-url="{$BASE}{$LANG_ABBR}{@single_template}{@load}">
            <xsl:value-of select="@title"/>:
            <a href="{$BASE}{$LANG_ABBR}cart/" class="count">
                <xsl:choose>
                    <xsl:when test="@count!=''"><xsl:value-of select="@count"/></xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>
                </xsl:choose>
            </a>
        </div>
    </xsl:template>

</xsl:stylesheet>
