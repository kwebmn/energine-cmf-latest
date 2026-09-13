<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:set="http://exslt.org/sets"
		extension-element-prefixes="set"
		version="1.0">

	<xsl:template match="field[@name='ads_item_smap_multi' and ancestor::component[@class='AdsItemEditor']]" mode="field_content">
		<div class="control smap_features" id="control_{@language}_{@name}">
			<xsl:variable name="OPTIONS" select="options/option"/>
			<xsl:for-each select="$OPTIONS[@root]">
				<xsl:sort select="@site_id"/>
				<xsl:sort select="@smap_order_num" order="descending"/>
				<xsl:if test="preceding::option/@root != @root">
					<h4><xsl:value-of select="@root"/></h4>
				</xsl:if>

				<input id="{generate-id(.)}" type="checkbox" name="ads_items[ads_item_smap_multi][]" value="{@id}" class="checkbox">
					<xsl:if test="@selected"><xsl:attribute name="checked">checked</xsl:attribute></xsl:if>
				</input>
				<label for="{generate-id(.)}"><xsl:value-of select="."/></label>

				<xsl:call-template name="SMAP_ADS_ITEM_TREE">
					<xsl:with-param name="NODES" select="$OPTIONS"/>
					<xsl:with-param name="CURRENT" select="."/>
				</xsl:call-template>
			</xsl:for-each>
		</div>
	</xsl:template>

	<!-- Banner place: Energine\ads\components\Ads (the legacy apps Ads component has ad_* fields) -->
	<xsl:template match="component[@class='Ads'][not(recordset/record/field[starts-with(@name, 'ad_')])]">
		<xsl:if test="recordset/record">
			<div class="ads ads_{@type}">
				<xsl:for-each select="recordset/record">
					<xsl:variable name="TYPE" select="field[@name='ads_type_id']/options/option[@selected]"/>
					<div class="ads_item">
						<xsl:choose>
							<xsl:when test="field[@name='ads_item_mode'] = 'html'">
								<xsl:value-of select="field[@name='ads_item_html']" disable-output-escaping="yes"/>
							</xsl:when>
							<xsl:when test="field[@name='ads_item_img'] != '' and field[@name='ads_item_url'] != ''">
								<a href="{field[@name='ads_item_url']}">
									<xsl:call-template name="ADS_ITEM_IMAGE">
										<xsl:with-param name="TYPE" select="$TYPE"/>
									</xsl:call-template>
								</a>
							</xsl:when>
							<xsl:when test="field[@name='ads_item_img'] != ''">
								<xsl:call-template name="ADS_ITEM_IMAGE">
									<xsl:with-param name="TYPE" select="$TYPE"/>
								</xsl:call-template>
							</xsl:when>
						</xsl:choose>
					</div>
				</xsl:for-each>
			</div>
		</xsl:if>
	</xsl:template>

	<xsl:template name="ADS_ITEM_IMAGE">
		<xsl:param name="TYPE"/>
		<img src="{$MEDIA_URL}{field[@name='ads_item_img']}" alt="{field[@name='ads_item_name']}">
			<xsl:if test="$TYPE/@ads_type_width != ''">
				<xsl:attribute name="width"><xsl:value-of select="$TYPE/@ads_type_width"/></xsl:attribute>
			</xsl:if>
			<xsl:if test="$TYPE/@ads_type_height != ''">
				<xsl:attribute name="height"><xsl:value-of select="$TYPE/@ads_type_height"/></xsl:attribute>
			</xsl:if>
		</img>
	</xsl:template>

	<xsl:template name="SMAP_ADS_ITEM_TREE">
		<xsl:param name="NODES"/>
		<xsl:param name="CURRENT"/>

		<xsl:if test="count($NODES[@smap_pid = $CURRENT/@id]) &gt; 0">
			<ul>
				<xsl:for-each select="$NODES[@smap_pid = $CURRENT/@id]">
					<li>
						<input id="{generate-id(.)}" type="checkbox" name="ads_items[ads_item_smap_multi][]" value="{@id}" class="checkbox">
							<xsl:if test="@selected"><xsl:attribute name="checked">checked</xsl:attribute></xsl:if>
						</input>
						<label for="{generate-id(.)}"><xsl:value-of select="."/></label>
						<xsl:call-template name="SMAP_ADS_ITEM_TREE">
							<xsl:with-param name="NODES" select="$NODES"/>
							<xsl:with-param name="CURRENT" select="."/>
						</xsl:call-template>
					</li>
				</xsl:for-each>
			</ul>
		</xsl:if>
	</xsl:template>

</xsl:stylesheet>
