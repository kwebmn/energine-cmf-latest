<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet 
    version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:og="http://ogp.me/ns#"
    xmlns:nrgn="http://energine.net#"
    exclude-result-prefixes="og nrgn"
    >
    <xsl:variable name="DOC_PROPS" select="/document/properties/property"/>
    <xsl:variable name="COMPONENTS" select="//component[@name]"/>
    <xsl:variable name="TRANSLATION" select="/document/translations/translation"/>
    <xsl:variable name="ID" select="$DOC_PROPS[@name='ID']"/>
	<xsl:variable name="BASE" select="$DOC_PROPS[@name='base']"/>
    <xsl:variable name="FOLDER" select="$DOC_PROPS[@name='base']/@folder"/>
	<xsl:variable name="LANG_ID" select="$DOC_PROPS[@name='lang']"/>
	<xsl:variable name="LANG_ABBR" select="$DOC_PROPS[@name='lang']/@abbr"/>
	<xsl:variable name="NBSP">&#160;</xsl:variable>
    <xsl:variable name="STATIC_URL"><xsl:value-of select="$BASE/@static"/></xsl:variable>
    <xsl:variable name="MEDIA_URL"><xsl:value-of select="$BASE/@media"/></xsl:variable>
    <xsl:variable name="RESIZER_URL"><xsl:value-of select="$BASE/@resizer"/></xsl:variable>
    <xsl:variable name="MAIN_SITE"><xsl:value-of select="$DOC_PROPS[@name='base']"/><xsl:value-of select="$LANG_ABBR"/></xsl:variable>
    <xsl:variable name="TEMPLATE"><xsl:value-of select="$DOC_PROPS[@name='template']"/></xsl:variable>
    <!-- токен против подделки запросов: скрытое поле csrf_token в каждой POST-форме, заголовок у запросов из JS -->
    <xsl:variable name="CSRF" select="string($DOC_PROPS[@name='csrf'])"/>


    <xsl:template match="/" mode="title">
        <title><xsl:choose>
            <!-- на странице ошибки крошки ведут на страницу, найденную до ошибки,
                 поэтому заголовок берём из свойства документа -->
            <xsl:when test="$COMPONENTS[@class='ErrorComponent']">
                <xsl:value-of select="$DOC_PROPS[@name='title']"/>
            </xsl:when>
            <xsl:when test="$DOC_PROPS[@name='title']/@alt = ''">
                <xsl:for-each select="$COMPONENTS[@name='breadCrumbs']/recordset/record">
                    <xsl:sort data-type="text" order="descending" select="position()"/>
                    <xsl:choose>
                        <xsl:when test="position() = last()">
                            <xsl:if test="$ID = field[@name='Id'] and (field[@name='Name'] != '' or field[@name='Title'] != '')">
                                <xsl:choose>
                                    <xsl:when test="field[@name='Title'] != ''">
                                        <xsl:value-of select="field[@name='Title']"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="field[@name='Name']"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xsl:text> / </xsl:text>
                            </xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:if test="field[@name='Name'] != '' or field[@name='Title'] != ''">
                                <xsl:choose>
                                    <xsl:when test="field[@name='Title'] != ''">
                                        <xsl:value-of select="field[@name='Title']"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="field[@name='Name']"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xsl:text> / </xsl:text>
                            </xsl:if>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:value-of select="$COMPONENTS[@name='breadCrumbs']/@site"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$DOC_PROPS[@name='title']/@alt"/>
            </xsl:otherwise>
        </xsl:choose></title>
    </xsl:template>

    <xsl:template match="/" mode="favicon">
        <link rel="shortcut icon" type="image/x-icon" href="{$STATIC_URL}images/energine.ico"/>
    </xsl:template>

    <xsl:template match="/" mode="stylesheets">
        <!-- стили темы: один файл, печать — в нём же (@media print) -->
        <link href="{$STATIC_URL}stylesheets/{$FOLDER}/main.css" rel="stylesheet" type="text/css"/>
    </xsl:template>

    <xsl:template match="/" mode="scripts">
        <xsl:if test="not($DOC_PROPS[@name='single'])"><!-- User JS is here--></xsl:if>
    </xsl:template>

    <xsl:template match="/" mode="og">
        <meta property="og:url" content="{$DOC_PROPS[@name='url']}" />
    </xsl:template>

    <xsl:template match="/" mode="head">
        <xsl:apply-templates select="." mode="title"/>
        <base href="{$BASE}"/>
        <xsl:apply-templates select="." mode="favicon"/>

        <!-- стили админки: панель администратора, режим правки, окна; гостю не нужны -->
        <xsl:if test="$COMPONENTS[@componentAction='showPageToolbar'] or $DOC_PROPS[@name='single']">
            <link rel="stylesheet" type="text/css" href="{$STATIC_URL}stylesheets/admin.css"/>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="not($DOC_PROPS[@name='single'])">
                <xsl:apply-templates select="." mode="stylesheets"/>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <meta name="csrf-token" content="{$CSRF}"/>
        <xsl:if test="$DOC_PROPS[@name='keywords']">
            <meta name="keywords" content="{$DOC_PROPS[@name='keywords']}"/>
        </xsl:if>
        <xsl:if test="$DOC_PROPS[@name='description']">
            <meta name="description" content="{$DOC_PROPS[@name='description']}"/>
        </xsl:if>
        <xsl:if test="$DOC_PROPS[@name='robots']">
            <meta name="robots" content="{$DOC_PROPS[@name='robots']}"/>
        </xsl:if>
        <xsl:apply-templates select="." mode="og"/>
        <script type="importmap">{"imports": {<xsl:for-each select="/document/javascript/module">"<xsl:value-of select="@name"/>": "<xsl:value-of select="$STATIC_URL"/>scripts/<xsl:value-of select="@name"/>.js?v=<xsl:value-of select="@version"/>"<xsl:if test="position() != last()">, </xsl:if></xsl:for-each>}}</script>
        <script type="module">
            import {Energine} from 'Energine';
            Object.assign(Energine, {
            <xsl:if test="document/@debug=1">'debug' :true,</xsl:if>
            'base' : '<xsl:value-of select="$BASE"/>',
            'static' : '<xsl:value-of select="$STATIC_URL"/>',
            'resizer' : '<xsl:value-of select="$RESIZER_URL"/>',
            'media' : '<xsl:value-of select="$MEDIA_URL"/>',
            'root' : '<xsl:value-of select="$MAIN_SITE"/>',
            'lang' : '<xsl:value-of select="$DOC_PROPS[@name='lang']/@real_abbr"/>',
            'csrf' : '<xsl:value-of select="$CSRF"/>'
            });
        </script>
        <xsl:apply-templates select="." mode="scripts"/>
        <script type="module">
            <xsl:for-each select="//javascript/behavior[not(@name = preceding::behavior/@name)]">
                import {<xsl:value-of select="@name"/>} from '<xsl:if test="@path"><xsl:value-of select="@path"/>/</xsl:if><xsl:value-of select="@name"/>';
            </xsl:for-each>
            window.componentToolbars = [];
            <xsl:for-each select="$COMPONENTS[recordset]/javascript[behavior[(@name!='PageEditor')]]/behavior">
                window['<xsl:value-of select="generate-id(../../recordset)"/>'] = null;
            </xsl:for-each>
            document.addEventListener('DOMContentLoaded', function () {
                <xsl:if test="$COMPONENTS[@componentAction='showPageToolbar']">
                    try {
                    <xsl:variable name="PAGE_TOOLBAR" select="$COMPONENTS[@componentAction='showPageToolbar']"></xsl:variable>
                    var pageToolbar = new <xsl:value-of select="$PAGE_TOOLBAR/javascript/behavior/@name" />('<xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/><xsl:value-of select="$PAGE_TOOLBAR/@single_template" />', <xsl:value-of select="$ID" />, '<xsl:value-of select="$PAGE_TOOLBAR/toolbar/@name"/>', [
                    <xsl:for-each select="$PAGE_TOOLBAR/toolbar/control">
                        {
                        <xsl:for-each select="@*[name()!='mode']">
                            '<xsl:value-of select="name()"/>':'<xsl:call-template name="js-string"><xsl:with-param name="s" select="."/></xsl:call-template>'<xsl:if test="position()!=last()">,</xsl:if>
                        </xsl:for-each><xsl:if test="options">, 'options':{
                            <xsl:for-each select="options/option">'<xsl:value-of select="@id"/>':'<xsl:call-template name="js-string"><xsl:with-param name="s" select="."/></xsl:call-template>'<xsl:if test="position()!=last()">,</xsl:if>
                            </xsl:for-each>},
                        'initialValue':'<xsl:value-of select="options/option[@selected]/@id"/>'
                        </xsl:if>
                        }<xsl:if test="position()!=last()">,</xsl:if></xsl:for-each>
                    ]<xsl:if test="$PAGE_TOOLBAR/toolbar/properties/property">, <xsl:for-each select="$PAGE_TOOLBAR/toolbar/properties/property">{'<xsl:value-of select="@name"/>':'<xsl:call-template name="js-string"><xsl:with-param name="s" select="."/></xsl:call-template>'<xsl:if test="position()!=last()">,</xsl:if>}</xsl:for-each></xsl:if>);
                    }
                    catch (e) {
                        console.error(e);
                    }
                </xsl:if>
                <xsl:for-each select="$COMPONENTS[@componentAction!='showPageToolbar']/javascript/behavior[@name!='PageEditor']">
                    <xsl:call-template name="INIT_JS" />
                </xsl:for-each>
                <xsl:if test="$COMPONENTS/javascript/behavior[@name='PageEditor']">
                    <xsl:if test="position()=1">
                        <xsl:variable name="objectID" select="generate-id($COMPONENTS[javascript/behavior[@name='PageEditor']]/recordset)"/>
                        try {
                            window['<xsl:value-of select="$objectID"/>'] = new PageEditor();
                        }
                        catch (e) {
                            console.error(e);
                        }
                    </xsl:if>
                </xsl:if>
            });
        </script>
        <xsl:apply-templates select="document/translations"/>
    </xsl:template>

    <xsl:template name="INIT_JS">
        <xsl:variable name="objectID" select="generate-id(../../recordset[not(@name)])"/>
        <xsl:choose>
            <xsl:when test="$objectID!=''">
                if(document.getElementById('<xsl:value-of select="$objectID"/>')){
                    window['<xsl:value-of select="$objectID"/>'] = new <xsl:value-of select="@name"/>('<xsl:value-of select="$objectID"/>');
                }
            </xsl:when>
            <xsl:otherwise>
                new <xsl:value-of select="@name"/>();
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="document">
        <xsl:apply-templates select="layout"/>
    </xsl:template>

    <!-- Single mode document -->
    <xsl:template match="document[properties/property[@name='single']]">
        <xsl:attribute name="class">e-singlemode-layout</xsl:attribute>
        <xsl:apply-templates select="container | component"/>
    </xsl:template>

    <xsl:template match="/document/translations"/>

    <xsl:template match="component/javascript"/>
    
    <!-- переводы для скриптов: данными в <template> (допустим и в <head>), а не строками в коде скрипта — апостроф
         («Повне iм'я») и </script> его не ломают; скрипт читает textContent. ITEMS — узлы translation -->
    <xsl:template name="js-translations">
        <xsl:param name="ITEMS"/>
        <template class="e-translations">
            <xsl:for-each select="$ITEMS">
                <span data-const="{@const}"><xsl:value-of select="."/></span>
            </xsl:for-each>
        </template>
        <script type="module">
            import {Energine} from 'Energine';
            document.querySelectorAll('template.e-translations').forEach((t) => t.content.querySelectorAll('[data-const]')
                .forEach((s) => Energine.translations.set(s.dataset.const, s.textContent)));
        </script>
    </xsl:template>

    <!-- строка для кода JS в одинарных кавычках: экранируются «\», «'», переводы строк и «</» (подписи кнопок —
         переводы, в украинских есть апостроф: «Повне iм'я») -->
    <xsl:template name="str-replace">
        <xsl:param name="s"/>
        <xsl:param name="from"/>
        <xsl:param name="to"/>
        <xsl:choose>
            <xsl:when test="contains($s, $from)">
                <xsl:value-of select="substring-before($s, $from)"/><xsl:value-of select="$to"/>
                <xsl:call-template name="str-replace">
                    <xsl:with-param name="s" select="substring-after($s, $from)"/>
                    <xsl:with-param name="from" select="$from"/>
                    <xsl:with-param name="to" select="$to"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="js-string">
        <xsl:param name="s"/>
        <xsl:variable name="a"><xsl:call-template name="str-replace"><xsl:with-param name="s" select="string($s)"/><xsl:with-param name="from" select="'\'"/><xsl:with-param name="to" select="'\\'"/></xsl:call-template></xsl:variable>
        <xsl:variable name="b"><xsl:call-template name="str-replace"><xsl:with-param name="s" select="$a"/><xsl:with-param name="from">'</xsl:with-param><xsl:with-param name="to">\'</xsl:with-param></xsl:call-template></xsl:variable>
        <xsl:variable name="c"><xsl:call-template name="str-replace"><xsl:with-param name="s" select="$b"/><xsl:with-param name="from" select="'&#13;'"/><xsl:with-param name="to" select="''"/></xsl:call-template></xsl:variable>
        <xsl:variable name="d"><xsl:call-template name="str-replace"><xsl:with-param name="s" select="$c"/><xsl:with-param name="from" select="'&#10;'"/><xsl:with-param name="to" select="'\n'"/></xsl:call-template></xsl:variable>
        <xsl:call-template name="str-replace"><xsl:with-param name="s" select="$d"/><xsl:with-param name="from" select="'&lt;/'"/><xsl:with-param name="to" select="'&lt;\/'"/></xsl:call-template>
    </xsl:template>

    <!-- Выводим переводы для WYSIWYG -->
    <xsl:template match="/document/translations[translation[@component=//component[@editable]/@name]]">
            <xsl:call-template name="js-translations">
                <xsl:with-param name="ITEMS" select="translation[@component=$COMPONENTS[@editable]/@name]"/>
            </xsl:call-template>
    </xsl:template>

    <xsl:template match="/document/javascript"/>
    <!-- запросы к базе (?debug): только для чтения в XML -->
    <xsl:template match="/document/queries"/>
    <!-- время блоков при отладке (Document::timing) — только в XML страницы -->
    <xsl:template match="/document/timings"/>


</xsl:stylesheet>
