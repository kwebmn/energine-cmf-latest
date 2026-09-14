<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:set="http://exslt.org/sets"
        extension-element-prefixes="set"
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

    <!-- Переключатель валют: ссылка задаёт валюту на время сессии -->
    <xsl:template match="component[@class='Currencies']">
        <xsl:if test="count(recordset/record) &gt; 1">
            <ul class="currencies">
                <xsl:for-each select="recordset/record">
                    <li>
                        <xsl:if test="field[@name='currency_is_current'] = 1">
                            <xsl:attribute name="class">current</xsl:attribute>
                        </xsl:if>
                        <a href="{$BASE}{$LANG_ABBR}{ancestor::component/@single_template}set/{field[@name='currency_id']}/"
                           title="{field[@name='currency_name']}">
                            <xsl:value-of select="field[@name='currency_code']"/>
                        </a>
                    </li>
                </xsl:for-each>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="component[@class='GoodsList' and @type='list']">
        <div class="products" id="{generate-id(recordset)}">
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <xsl:template match="component[@class='GoodsList' and @type='form']">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="toolbar[parent::component[@class='GoodsList'] and @name='list_type']">
        <div class="goods_view_type">
            <ul class="inline">
                <xsl:for-each select="control">
                    <li><xsl:apply-templates select="."/></li>
                </xsl:for-each>
            </ul>
        </div>
    </xsl:template>

    <!-- GoodsCompare.js слушает ссылки с name=to_compare и data-goods-id -->
    <xsl:template match="control[@id='compare' and ancestor::component[@sample='GoodsList']]">
        <xsl:param name="ID"/>
        <a href="#" name="to_compare" data-goods-id="{$ID}" class="to_compare"><xsl:value-of select="@title"/></a>
    </xsl:template>

    <xsl:template match="control[@id='wishlist' and ancestor::component[@sample='GoodsList']]">
        <xsl:param name="ID"/>
        <a href="#" onClick="{generate-id($COMPONENTS[@sample='Wishlist' and @componentAction='main']/recordset)}.add(event, {$ID});"><xsl:value-of select="@title"/></a>
    </xsl:template>

    <xsl:template match="control[@id='buy' and ancestor::component[@sample='GoodsList']]">
        <xsl:param name="ID"/>
        <button  onClick="{generate-id($COMPONENTS[@sample='Cart' and @componentAction='main']/recordset)}.add(event, {$ID});"><xsl:value-of select="@title"/></button>
    </xsl:template>


    <xsl:template match="toolbar[parent::component[@class='GoodsList'] and @name='product']" />

    <xsl:template match="toolbar[parent::component[@class='GoodsList'] and @name='product']" mode="list">
        <xsl:param name="ID"/>
        <div class="goods_controls clearfix">
            <ul class="inline wo-separator">
                <xsl:for-each select="control">
                    <li><xsl:apply-templates select=".">
                        <xsl:with-param name="ID" select="$ID"/>
                    </xsl:apply-templates></li>
                </xsl:for-each>
                <!--<button type="button" class="buy_goods">BUY</button>
                <a href="#" class="add_to_wishlist">ADD_TO_WISHLIST</a>-->
            </ul>
        </div>
    </xsl:template>

    <xsl:template match="recordset[parent::component[@class='GoodsList' and @type='list']]">
        <xsl:apply-templates select="." mode="goods_list"/>
    </xsl:template>

    <!-- Сохранённые фильтры пользователя: ссылки на отфильтрованный список -->
    <xsl:template match="component[@class='SavedFilters']">
        <div class="saved_filters">
            <h3><xsl:value-of select="$TRANSLATION[@const='TXT_SAVED_FILTERS']"/></h3>
            <xsl:if test="recordset/record">
                <ul class="saved_filters_list">
                    <xsl:for-each select="recordset/record">
                        <li>
                            <a href="{$BASE}{$LANG_ABBR}{field[@name='sf_link']}">
                                <xsl:value-of select="field[@name='sf_name']"/>
                            </a>
                            <a class="saved_filter_delete"
                               href="{$BASE}{$LANG_ABBR}{ancestor::component/@single_template}{field[@name='sf_id']}/delete/"
                               title="{$TRANSLATION[@const='BTN_DELETE']}">×</a>
                        </li>
                    </xsl:for-each>
                </ul>
            </xsl:if>
        </div>
    </xsl:template>

    <!-- форма сохранения текущего фильтра: видна авторизованному пользователю,
         когда фильтр применён -->
    <xsl:template match="component[@class='GoodsFilter']" mode="save_form">
        <xsl:if test="$COMPONENTS[@class='SavedFilters'] and contains($DOC_PROPS[@name='url'], 'filter=')">
            <form class="save_filter_form" method="post"
                  action="{$BASE}{$LANG_ABBR}{@single_template}save-filter/?{substring-after($DOC_PROPS[@name='url'], '?')}">
                <input type="text" name="name" placeholder="{$TRANSLATION[@const='TXT_SAVE_FILTER_NAME']}"/>
                <button type="submit"><xsl:value-of select="$TRANSLATION[@const='BTN_SAVE_FILTER']"/></button>
            </form>
        </xsl:if>
    </xsl:template>

    <!-- «вы недавно смотрели»: прокси-билдер отдаёт записи списка товаров,
         обёртка остаётся GoodsLastSeenList, поэтому шаблон нужен отдельный -->
    <xsl:template match="component[@class='GoodsLastSeenList']">
        <xsl:if test="recordset/record">
            <div class="products last_seen_goods">
                <h3><xsl:value-of select="$TRANSLATION[@const='TXT_LAST_SEEN_GOODS']"/></h3>
                <xsl:apply-templates select="recordset" mode="goods_list"/>
            </div>
        </xsl:if>
    </xsl:template>

    <!-- GoodsLastSeen только запоминает просмотр, выводить его нечего -->
    <xsl:template match="component[@class='GoodsLastSeen']"/>

    <!-- related goods under the goods page -->
    <xsl:template match="component[@class='RelatedGoodsList']">
        <xsl:if test="recordset/record">
            <div class="products related_goods">
                <h3><xsl:value-of select="@title"/></h3>
                <xsl:apply-templates select="recordset" mode="goods_list"/>
            </div>
        </xsl:if>
    </xsl:template>

    <!-- search results page: the found goods as a list -->
    <xsl:template match="component[@class='SearchResults']">
        <div class="products search_results">
            <xsl:choose>
                <xsl:when test="recordset/record">
                    <xsl:apply-templates select="recordset" mode="goods_list"/>
                </xsl:when>
                <xsl:otherwise>
                    <div class="empty_message"><xsl:value-of select="recordset/@empty"/></div>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>

    <xsl:template match="recordset" mode="goods_list">
    <div class="goods_list wide_list clearfix"> <!-- клас .wide_list для списка -->
        <xsl:for-each select="record">
            <xsl:variable name="URL">
                <xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of
                    select="field[@name='smap_id']"/>view/<xsl:value-of
                    select="field[@name='goods_segment']"/>/</xsl:variable>
            <div class="goods_block">
	            <div class="goods_block_inner clearfix">
	                <div class="goods_image">
	                    <xsl:if test="field[@name='attachments']/recordset/record">
	                        <a href="{$URL}">
	                            <img src="{$RESIZER_URL}w200-h150/{field[@name='attachments']/recordset/record[1]/field[@name='file']}"
	                                 alt="{field[@name='attachments']/recordset/record[1]/field[@name='title']}"/>
	                        </a>
	                    </xsl:if>
	                </div>
                    <div class="goods_info">
                        <div class="goods_name">
                            <a href="{$URL}">
                                <xsl:value-of select="field[@name='goods_name']"/>
                            </a>
                        </div>
                        <div class="goods_producer">
                            <xsl:value-of select="field[@name='producer_id']/value"/>
                        </div>
                        <div class="goods_status available">
                            <xsl:value-of select="field[@name='sell_status_id']/value"/>
                        </div>
                        <div class="goods_price">
                            <xsl:if test="field[@name='goods_price_old'] &gt; 0">
                                <span class="goods_price_old">
                                    <xsl:call-template name="PRICE">
                                        <xsl:with-param name="VALUE" select="field[@name='goods_price_old']"/>
                                    </xsl:call-template>
                                </span>
                            </xsl:if>
                            <xsl:call-template name="PRICE">
                                <xsl:with-param name="VALUE" select="field[@name='goods_price']"/>
                            </xsl:call-template>
                        </div>
                        <xsl:apply-templates select="../../toolbar[@name='product']" mode="list">
                            <xsl:with-param name="ID" select="field[@name='goods_id']"/>
                        </xsl:apply-templates>
                    </div>

	            </div>
            </div>
        </xsl:for-each>
    </div>
    </xsl:template>

    <xsl:template match="recordset[parent::component[@class='GoodsList' and @type='list']][@empty]">
            <div><xsl:value-of select="@empty"/></div>
    </xsl:template>

	<xsl:template match="recordset[parent::component[(@class='GoodsList') and (@type='list') and (descendant::javascript/behavior/@name = 'ProductCarousel')]]">
        <xsl:if test="not(@empty)">
            <div class="multiple-items">
                <xsl:for-each select="record">
                    <xsl:variable name="URL">
                        <xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of
                            select="field[@name='smap_id']"/>view/<xsl:value-of
                            select="field[@name='goods_segment']"/>/
                    </xsl:variable>
                    <div class="item goods_block">
                        <a href="{$URL}" class="goods_block_inner">
                            <div class="goods_image">
                                <img src="{$RESIZER_URL}w200-h150/{field[@name='attachments']/recordset/record[1]/field[@name='file']}"
                                     alt="{field[@name='attachments']/recordset/record[1]/field[@name='title']}"/>
                            </div>
                            <div class="goods_name">
                                <xsl:value-of select="field[@name='goods_name']"/>
                            </div>
                            <div class="goods_price">
                                <xsl:call-template name="PRICE">
                                    <xsl:with-param name="VALUE" select="field[@name='goods_price']"/>
                                </xsl:call-template>
                            </div>
                        </a>
                    </div>
                </xsl:for-each>
            </div>
        </xsl:if>

    </xsl:template>

    <xsl:template match="component[@class='GoodsSort']">
        <div class="goods_sort">
            <xsl:variable name="GET"><xsl:if test="@get!=''">?<xsl:value-of select="@get"/></xsl:if></xsl:variable>
            <xsl:variable name="RECORDS" select="recordset/record"/>
            <ul class="inline">
            <xsl:for-each select="$RECORDS/field[@name='field']/options/option">
                <li><a href="{$BASE}{$LANG_ABBR}{$TEMPLATE}sort-{@id}-{$RECORDS/field[@name='dir']/options/option[not(@selected)]/@id}/{$GET}"><xsl:value-of select="."/>
                    <xsl:if test="@selected">
                        <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
	                    <i class="fa ficon_{$RECORDS/field[@name='dir']/options/option[@selected]}"></i>
                    </xsl:if>
                </a></li>
            </xsl:for-each>
            </ul>
        </div>
    </xsl:template>

    <xsl:template match="component[@class='GoodsFilter']">
        <xsl:if test="count(recordset/record)&gt;0">
            <form method="get" action="{$BASE}{$LANG_ABBR}{$TEMPLATE}{@action}" data-filter-name="{@filter-name}">
                <xsl:apply-templates/>
            </form>
            <xsl:apply-templates select="." mode="save_form"/>
        </xsl:if>
    </xsl:template>

     <xsl:template match="field[ancestor::component[@type='form'] and (@subtype='RANGE')]" mode="field_input">
        <xsl:variable name="NAME"><xsl:value-of select="@tableName"/>[<xsl:value-of select="@name"/>]</xsl:variable>
            <div class="range">
                <xsl:if test="@range-begin">
                    <xsl:attribute name="data-start"><xsl:value-of select="@range-begin"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="@range-end">
                    <xsl:attribute name="data-end"><xsl:value-of select="@range-end"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="@range-min">
                    <xsl:attribute name="data-min"><xsl:value-of select="@range-min"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="@range-max">
                    <xsl:attribute name="data-max"><xsl:value-of select="@range-max"/></xsl:attribute>
                </xsl:if>
                <xsl:if test="@range-step">
                    <xsl:attribute name="data-step"><xsl:value-of select="@range-step"/></xsl:attribute>
                </xsl:if>
                <input type="hidden" name="{$NAME}[begin]" class="lower">
                    <xsl:if test="@range-begin">
                        <xsl:attribute name="value"><xsl:value-of select="@range-begin"/></xsl:attribute>
                    </xsl:if>
                </input>
                <input type="hidden" name="{$NAME}[end]" class="upper">
                    <xsl:if test="@range-end">
                        <xsl:attribute name="value"><xsl:value-of select="@range-end"/></xsl:attribute>
                    </xsl:if>
                </input>
            </div>
        </xsl:template>

	<xsl:template match="recordset[parent::component[@class='GoodsList' and @type='form']]">
		<div class="goods_view clearfix" id="{generate-id(.)}" data-id="{record/field[@name='goods_id']}">
            <xsl:for-each select="record">
                <div class="goods_image_block">
                    <div id="goodsGalleryLarge" class="single-item slider ">

                                <xsl:for-each select="field[@name='attachments']/recordset/record">
                                    <div >
                                        <img src="{$RESIZER_URL}w400-h300/{field[@name='file']}" alt="{field[@name='name']}" />
                                    </div>
                                </xsl:for-each>
                    </div>
                    <div id="goodsGallerySmall" class="multiple-items slider ">
                        <xsl:for-each select="field[@name='attachments']/recordset/record">
                            <div >
                                <img src="{$RESIZER_URL}w100-h75/{field[@name='file']}" alt="{field[@name='name']}" />
                            </div>
                        </xsl:for-each>
                    </div>
                </div>
                <div class="goods_info">
                    <div class="goods_name">
                        <xsl:value-of select="field[@name='goods_name']" />
                    </div>
                    <div class="goods_price">
                        <xsl:if test="field[@name='goods_price_old'] &gt; 0">
                            <span class="goods_price_old">
                                <xsl:call-template name="PRICE">
                                    <xsl:with-param name="VALUE" select="field[@name='goods_price_old']"/>
                                </xsl:call-template>
                            </span>
                        </xsl:if>
                        <xsl:call-template name="PRICE">
                            <xsl:with-param name="VALUE" select="field[@name='goods_price']" />
                        </xsl:call-template>
                    </div>
                    <div class="goods_status available">
                        <xsl:value-of select="field[@name='sell_status_id']/value" />
                    </div>
                    <div class="goods_buy">
                        <xsl:apply-templates select="../../toolbar[@name='product']" mode="list">
                            <xsl:with-param name="ID" select="field[@name='goods_id']"/>
                        </xsl:apply-templates>
                    </div>
                    <div class="goods_description">
                        <xsl:value-of select="field[@name='goods_description_rtf']" disable-output-escaping="yes" />
                    </div>
                </div>
                <xsl:variable name="RECORDSET" select="field[@name='features']/recordset"/>
                <xsl:if test="not($RECORDSET/@empty)">
                    <div class="goods_features_block">
                        <table class="goods_features">
                            <thead>
                                <tr>
                                    <th colspan="2">
                                        <xsl:value-of select="field[@name='features']/@title"/>
                                    </th>
                                </tr>
                            </thead>
                            <tbody>
                                <xsl:for-each select="set:distinct($RECORDSET/record/field[@name='group_id'])">
                                    <xsl:variable name="GROUP_ID" select="."/>
                                    <xsl:if test="$GROUP_ID!=''">
                                        <tr>
                                            <td colspan="2" class="group">
                                                <xsl:value-of select="../field[@name='group_title']"/>
                                            </td>
                                        </tr>
                                    </xsl:if>
                                    <xsl:for-each select="$RECORDSET/record[field[@name='group_id'] =$GROUP_ID]">
                                        <tr>
                                            <th>
                                                <xsl:value-of select="field[@name='feature_title']"/>
                                            </th>
                                            <td>
                                                <xsl:value-of select="field[@name='feature_value']"/>
                                            </td>
                                        </tr>
                                    </xsl:for-each>
                                </xsl:for-each>
                            </tbody>
                        </table>
                    </div>
                </xsl:if>
            </xsl:for-each>
        </div>
	</xsl:template>

    <xsl:template match="control[ancestor::component[@class='GoodsFilter']]">
        <button id="{@id}" type="{@type}"><xsl:value-of select="@title"/></button>
    </xsl:template>

	<xsl:template match="component[@class='PageList' and @name='categoriesMenu']">
		<div class="categories_list clearfix">
			<xsl:for-each select="recordset/record">
				<div class="category">
					<a href="{field[@name='Segment']}">
						<div class="category_image">
							<div class="category_image_inner"> <!-- optional block for vertical align -->
								<img src="{field[@name='attachments']/recordset/record[1]/field[@name='file']}" alt="{field[@name='attachments']/recordset/record[1]/field[@name='name']}" />
							</div>
						</div>
						<div class="category_name">
							<xsl:value-of select="field[@name='Name']" />
						</div>
						<div class="category_description">
							<xsl:value-of select="field[@name='DescriptionRtf']" disable-output-escaping="yes" />
						</div>
					</a>
				</div>
			</xsl:for-each>
		</div>
	</xsl:template>

    <xsl:template match="component[@class='Categories']">
        <xsl:if test="not(@empty)">
                <xsl:apply-templates/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@class='Categories']]">
        <ul class="main_menu clearfix">
            <xsl:apply-templates select="record"/>
        </ul>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='Categories']]">
        <li class="main_menu_item">
            <xsl:attribute name="class">main_menu_item<xsl:if test="field[@name='Id']=$ID"> active</xsl:if></xsl:attribute>
            <a>
                <xsl:if test="$DOC_PROPS[@name='ID']!=field[@name='Id']">
                    <xsl:attribute name="href"><xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of select="field[@name='Segment']"/></xsl:attribute>
                </xsl:if>
                <xsl:value-of select="field[@name='Name']"/>
            </a>
            <xsl:if test="recordset">
                <xsl:apply-templates select="recordset"/>
            </xsl:if>


        </li>
    </xsl:template>

</xsl:stylesheet>
