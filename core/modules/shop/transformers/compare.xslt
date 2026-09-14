<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        version="1.0">

	<!-- информер сравнения: пустой контейнер, содержимое подгружает GoodsCompare.js -->
	<xsl:template match="component[@class='GoodsCompare' and @componentAction='main']">
		<div id="{generate-id(recordset)}"
			 class="header_compare_block"
			 data-compare-url="{$BASE}{$LANG_ABBR}{@single_template}compare/"
			 data-informer-url="{$BASE}{$LANG_ABBR}{@single_template}informer/"
			 data-add-url="{$BASE}{$LANG_ABBR}{@single_template}add/"
			 data-remove-url="{$BASE}{$LANG_ABBR}{@single_template}remove/"
			 data-clear-url="{$BASE}{$LANG_ABBR}{@single_template}clear/"
				>
			<!-- контейнер для содержимого информера -->
		</div>
		<xsl:apply-templates select="javascript"/>
	</xsl:template>

	<!-- содержимое информера: сколько товаров выбрано и кнопка сравнения по каждому разделу -->
	<xsl:template match="component[@class='GoodsCompare' and (@componentAction='informer' or @componentAction='add' or @componentAction='remove' or @componentAction='clear')]">
		<xsl:if test="@goods_count &gt; 0">
			<a href="#" class="compare_link">
				<xsl:value-of select="$TRANSLATION[@const='TXT_COMPARE']"/>
				<xsl:text> (</xsl:text>
				<xsl:value-of select="@goods_count"/>
				<xsl:text>)</xsl:text>
			</a>
			<div class="popup_compare hidden">
				<div class="compare_text"><xsl:value-of select="$TRANSLATION[@const='TXT_COMPARE_SELECTED']"/></div>
				<!-- раньше здесь стояло жёстко вписанное «5» -->
				<div class="compare_count"><xsl:value-of select="@goods_count"/></div>
				<a href="#" class="clear_compare_list"><xsl:value-of select="$TRANSLATION[@const='TXT_COMPARE_CLEAR']"/></a>
				<ul class="compare_sections">
					<xsl:for-each select="recordset/record">
						<li>
							<span class="compare_section_name"><xsl:value-of select="field[@name='smap_name']"/></span>
							<xsl:text>: </xsl:text>
							<span class="compare_section_count"><xsl:value-of select="field[@name='goods_count']"/></span>
							<xsl:if test="field[@name='goods_count'] &gt; 1">
								<!-- класс должен совпадать с тем, что слушает GoodsCompare.js -->
								<button type="button" class="compare" data-goods-ids="{field[@name='goods_ids']}">
									<xsl:value-of select="$TRANSLATION[@const='BTN_COMPARE']"/>
								</button>
							</xsl:if>
						</li>
					</xsl:for-each>
				</ul>
			</div>
		</xsl:if>
	</xsl:template>

	<!-- Сама таблица сравнения: строки - объединение характеристик выбранных товаров.
	     Раньше на этом месте стоял «todo». -->
	<xsl:template match="component[@class='GoodsCompare' and @componentAction='compare']">
		<div class="compare_table_wrapper">
			<h2><xsl:value-of select="$TRANSLATION[@const='TXT_COMPARE']"/></h2>
			<xsl:choose>
				<xsl:when test="recordset/record">
					<table class="compare_table">
						<tr class="compare_row_goods">
							<th class="compare_feature_name"></th>
							<xsl:for-each select="recordset/record">
								<xsl:variable name="URL"
								              select="concat($BASE, $LANG_ABBR, field[@name='smap_id'], 'view/', field[@name='goods_segment'], '/')"/>
								<td class="compare_goods">
									<xsl:if test="field[@name='attachments']/recordset/record">
										<a href="{$URL}">
											<img src="{$RESIZER_URL}w150-h110/{field[@name='attachments']/recordset/record[1]/field[@name='file']}"
											     alt="{field[@name='goods_name']}"/>
										</a>
									</xsl:if>
									<div class="goods_name"><a href="{$URL}"><xsl:value-of select="field[@name='goods_name']"/></a></div>
									<div class="goods_price">
										<xsl:call-template name="PRICE">
											<xsl:with-param name="VALUE" select="field[@name='goods_price']"/>
										</xsl:call-template>
									</div>
								</td>
							</xsl:for-each>
						</tr>
						<!-- сопоставляем характеристики по системному имени, подпись берём из заголовка -->
						<xsl:for-each select="recordset/record[1]/field[@name='features']/recordset/record">
							<xsl:variable name="SYS" select="field[@name='feature_sysname']"/>
							<tr class="compare_row_feature">
								<th class="compare_feature_name"><xsl:value-of select="field[@name='feature_title']"/></th>
								<xsl:for-each select="ancestor::component/recordset/record">
									<td>
										<xsl:variable name="V"
										              select="field[@name='features']/recordset/record[field[@name='feature_sysname'] = $SYS]/field[@name='feature_value']"/>
										<xsl:choose>
											<xsl:when test="$V != ''"><xsl:value-of select="$V"/></xsl:when>
											<xsl:otherwise><xsl:text>&#8212;</xsl:text></xsl:otherwise>
										</xsl:choose>
									</td>
								</xsl:for-each>
							</tr>
						</xsl:for-each>
					</table>
				</xsl:when>
				<xsl:otherwise>
					<div class="empty_message"><xsl:value-of select="$TRANSLATION[@const='TXT_COMPARE_EMPTY']"/></div>
				</xsl:otherwise>
			</xsl:choose>
		</div>
	</xsl:template>

</xsl:stylesheet>
