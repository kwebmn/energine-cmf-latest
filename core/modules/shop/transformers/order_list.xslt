<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">

	<!-- «Мои заказы» (Energine\shop\components\OrderList).
	     Без этого шаблона страница вываливала все поля заказа подряд. -->

	<xsl:template match="component[@class='OrderList']">
		<div class="orders">
			<xsl:choose>
				<xsl:when test="recordset/record">
					<xsl:apply-templates select="recordset/record"/>
				</xsl:when>
				<xsl:otherwise>
					<div class="empty_message">
						<xsl:choose>
							<xsl:when test="recordset/@empty"><xsl:value-of select="recordset/@empty"/></xsl:when>
							<xsl:otherwise><xsl:value-of select="$TRANSLATION[@const='TXT_MY_ORDERS_EMPTY']"/></xsl:otherwise>
						</xsl:choose>
					</div>
				</xsl:otherwise>
			</xsl:choose>
		</div>
	</xsl:template>

	<xsl:template match="record[ancestor::component[@class='OrderList']]">
		<div class="order_block">
			<div class="order_header clearfix">
				<span class="order_number">
					<xsl:value-of select="field[@name='order_id']/@title"/>
					<xsl:text> </xsl:text>
					<xsl:value-of select="field[@name='order_id']"/>
				</span>
				<span class="order_date"><xsl:value-of select="field[@name='order_created']"/></span>
				<span class="order_status"><xsl:value-of select="field[@name='status_id']/value"/></span>
			</div>

			<table class="order_goods">
				<xsl:for-each select="field[@name='order_goods']/recordset/record">
					<tr>
						<td class="order_goods_title"><xsl:value-of select="field[@name='goods_title']"/></td>
						<td class="order_goods_qty"><xsl:value-of select="field[@name='goods_quantity']"/><xsl:text>&#160;×&#160;</xsl:text><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="field[@name='goods_price']"/></xsl:call-template></td>
						<td class="order_goods_amount"><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="field[@name='goods_amount']"/></xsl:call-template></td>
					</tr>
				</xsl:for-each>
			</table>

			<div class="order_footer">
				<div class="order_delivery">
					<xsl:value-of select="field[@name='delivery_type_id']/@title"/>
					<xsl:text>: </xsl:text>
					<xsl:value-of select="field[@name='delivery_type_id']/value"/>
					<xsl:if test="field[@name='order_city'] != ''">
						<xsl:text>, </xsl:text>
						<xsl:value-of select="field[@name='order_city']"/>
						<xsl:if test="field[@name='order_address'] != ''">
							<xsl:text>, </xsl:text><xsl:value-of select="field[@name='order_address']"/>
						</xsl:if>
					</xsl:if>
				</div>
				<div class="order_payment">
					<xsl:value-of select="field[@name='payment_type_id']/@title"/>
					<xsl:text>: </xsl:text>
					<xsl:value-of select="field[@name='payment_type_id']/value"/>
				</div>
				<div class="order_total">
					<xsl:value-of select="field[@name='order_total']/@title"/>
					<xsl:text>: </xsl:text>
					<strong><xsl:call-template name="PRICE"><xsl:with-param name="VALUE" select="field[@name='order_total']"/></xsl:call-template></strong>
				</div>
			</div>
		</div>
	</xsl:template>

</xsl:stylesheet>
