<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!--
        Тема сайта (этап 5в): шапка (название, меню, язык, вход), содержимое, боковая колонка, подвал.
        Меню и вход — компоненты раскладки (default.layout.xml), шаблоны содержимого несут только своё.
        Меню на телефоне свёрнуто в <details>, на широком экране раскрыто стилями (::details-content) —
        без JS. Содержимое в исходном порядке раньше боковой колонки (container name="aside").
    -->

    <xsl:variable name="SITE_NAME" select="$COMPONENTS[@name='breadCrumbs']/@site"/>
    <!-- код языка для lang: у украинского в Energine аббревиатура ua, стандартный код — uk -->
    <xsl:variable name="HTML_LANG">
        <xsl:choose>
            <xsl:when test="$DOC_PROPS[@name='lang']/@real_abbr = 'ua'">uk</xsl:when>
            <xsl:otherwise><xsl:value-of select="$DOC_PROPS[@name='lang']/@real_abbr"/></xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/">
        <html lang="{$HTML_LANG}">
            <head>
                <!-- title, base, стили, скрипты, meta — document.xslt -->
                <xsl:apply-templates select="." mode="head"/>
            </head>
            <body>
                <xsl:apply-templates select="document"/>
            </body>
        </html>
    </xsl:template>

    <!-- страница -->
    <xsl:template match="document">
        <a class="skip-link" href="#content"><xsl:value-of select="$TRANSLATION[@const='TXT_SKIP_TO_CONTENT']"/></a>
        <header class="site-header">
            <div class="wrap site-header__inner">
                <a class="site-name">
                    <xsl:if test="$DOC_PROPS[@name='default'] != 1">
                        <xsl:attribute name="href"><xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/></xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="$SITE_NAME"/>
                </a>
                <xsl:apply-templates select="$COMPONENTS[@name='mainMenu']"/>
                <div class="site-tools">
                    <xsl:apply-templates select="$COMPONENTS[@class='LangSwitcher']"/>
                    <xsl:apply-templates select="$COMPONENTS[@name='userMenu']"/>
                </div>
            </div>
        </header>
        <div class="wrap site-body">
            <xsl:if test="content/container[@name='aside']">
                <xsl:attribute name="class">wrap site-body site-body--aside</xsl:attribute>
            </xsl:if>
            <main id="content" class="site-main" tabindex="-1">
                <xsl:apply-templates select="$COMPONENTS[@name='breadCrumbs']"/>
                <!-- страница ошибки: компонент добавляется в корень документа, а не в content -->
                <xsl:apply-templates select="$COMPONENTS[@class='ErrorComponent']"/>
                <xsl:apply-templates select="content/node()[not(self::container[@name='aside'])]"/>
            </main>
            <xsl:if test="content/container[@name='aside']">
                <aside class="site-aside">
                    <xsl:apply-templates select="content/container[@name='aside']/node()"/>
                </aside>
            </xsl:if>
        </div>
        <footer class="site-footer">
            <div class="wrap">
                <xsl:apply-templates select="$COMPONENTS[@name='footerTextBlock']"/>
            </div>
        </footer>
    </xsl:template>

    <!-- главное меню: на телефоне сворачивается -->
    <xsl:template match="component[@name='mainMenu']" priority="1">
        <nav class="site-nav" aria-label="{$TRANSLATION[@const='TXT_MAIN_MENU']}">
            <details class="site-menu">
                <summary><xsl:value-of select="$TRANSLATION[@const='TXT_MENU']"/></summary>
                <xsl:apply-templates select="recordset"/>
            </details>
        </nav>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@name='mainMenu']]" priority="1">
        <xsl:if test="not(@empty) and record">
            <ul class="main_menu">
                <xsl:if test="parent::record">
                    <xsl:attribute name="class">main_menu main_menu--sub</xsl:attribute>
                </xsl:if>
                <xsl:apply-templates select="record"/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@name='mainMenu']]" priority="1">
        <li>
            <xsl:attribute name="class">main_menu_item<xsl:if test="field[@name='Id'] = $ID"> active</xsl:if></xsl:attribute>
            <a>
                <xsl:attribute name="href"><xsl:choose>
                    <xsl:when test="field[@name='Redirect'] = ''"><xsl:value-of select="$LANG_ABBR"/><xsl:value-of select="field[@name='Segment']"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="field[@name='Redirect']"/></xsl:otherwise>
                </xsl:choose></xsl:attribute>
                <xsl:if test="field[@name='Id'] = $ID">
                    <xsl:attribute name="aria-current">page</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="field[@name='Name']"/>
            </a>
            <xsl:apply-templates select="recordset"/>
        </li>
    </xsl:template>

    <!-- вход в шапке: ссылка для гостя, имя и выход (POST с токеном) для вошедшего -->
    <xsl:template match="component[@name='userMenu']" priority="1">
        <div class="user-menu">
            <xsl:choose>
                <xsl:when test="@componentAction = 'showLogoutForm'">
                    <span class="user-menu__name"><xsl:value-of select="recordset/record/field[@name='u_fullname']"/></span>
                    <form method="post" action="{@action}" class="user-menu__logout">
                        <input type="hidden" name="csrf_token" value="{$CSRF}"/>
                        <button type="submit" name="user[logout]" value="1"><xsl:value-of select="$TRANSLATION[@const='BTN_LOGOUT']"/></button>
                    </form>
                </xsl:when>
                <xsl:otherwise>
                    <a href="{$BASE}{$LANG_ABBR}login/"><xsl:value-of select="$TRANSLATION[@const='TXT_LOGIN_FORM']"/></a>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>

    <!-- LangSwitcher -->
    <xsl:template match="component[@class='LangSwitcher']" priority="1">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="recordset[parent::component[@class='LangSwitcher']]" priority="1">
        <xsl:if test="count(record) &gt; 1">
            <ul class="lang_switcher">
                <xsl:apply-templates/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='LangSwitcher']]" priority="1">
        <li class="lang_switcher_item">
            <a>
                <xsl:choose>
                    <xsl:when test="$LANG_ID != field[@name='lang_id']">
                        <xsl:attribute name="href"><xsl:value-of select="field[@name='lang_url']"/></xsl:attribute>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:attribute name="aria-current">true</xsl:attribute>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="field[@name='lang_name']"/>
            </a>
        </li>
    </xsl:template>
    <!-- /LangSwitcher -->

    <!-- BreadCrumbs -->
    <xsl:template match="component[@name='breadCrumbs']" priority="1">
        <xsl:if test="count(recordset/record) &gt; 1">
            <nav class="breadcrumbs" aria-label="{$TRANSLATION[@const='TXT_BREADCRUMBS']}">
                <ol>
                    <xsl:apply-templates select="recordset/record"/>
                </ol>
            </nav>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@name='breadCrumbs']]" priority="1">
        <li>
            <xsl:choose>
                <xsl:when test="position() = last()">
                    <span aria-current="page"><xsl:value-of select="field[@name='Name']"/></span>
                </xsl:when>
                <xsl:when test="position() = 1">
                    <a href="{$BASE}{$LANG_ABBR}"><xsl:value-of select="field[@name='Name']"/></a>
                </xsl:when>
                <xsl:when test="field[@name='Id'] != ''">
                    <a href="{$BASE}{$LANG_ABBR}{field[@name='Segment']}"><xsl:value-of select="field[@name='Name']"/></a>
                </xsl:when>
            </xsl:choose>
        </li>
    </xsl:template>
    <!-- /BreadCrumbs -->

    <!-- PageList: подразделы -->
    <xsl:template match="component[@class='PageList']">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@class='PageList']]">
        <xsl:if test="not(@empty)">
            <ul class="menu">
                <xsl:apply-templates/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='PageList']]">
        <li class="menu_item">
            <div class="menu_name">
                <a>
                    <xsl:if test="$DOC_PROPS[@name='ID'] != field[@name='Id']">
                        <xsl:attribute name="href">
                            <xsl:choose>
                                <xsl:when test="field[@name='Redirect'] = ''"><xsl:value-of select="$LANG_ABBR"/><xsl:value-of select="field[@name='Segment']"/></xsl:when>
                                <xsl:otherwise><xsl:value-of select="field[@name='Redirect']"/></xsl:otherwise>
                            </xsl:choose>
                        </xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="field[@name='Name']"/>
                </a>
            </div>
            <xsl:if test="field[@name='DescriptionRtf'] != ''">
                <div class="menu_announce">
                    <xsl:value-of select="field[@name='DescriptionRtf']" disable-output-escaping="yes"/>
                </div>
            </xsl:if>
            <xsl:if test="recordset">
                <xsl:apply-templates/>
            </xsl:if>
        </li>
    </xsl:template>
    <!-- /PageList -->

    <!-- SitemapTree: карта сайта — вложенные списки -->
    <xsl:template match="component[@class='SitemapTree']">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@class='SitemapTree']]">
        <ul class="sitemap_tree">
            <xsl:apply-templates/>
        </ul>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='SitemapTree']]">
        <li>
            <a href="{$BASE}{$LANG_ABBR}{field[@name='Segment']}">
                <xsl:if test="field[@name='Id'] = $DOC_PROPS[@name='ID']">
                    <xsl:attribute name="aria-current">page</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="field[@name='Name']"/>
            </a>
            <xsl:apply-templates/>
        </li>
    </xsl:template>

    <xsl:template match="field[ancestor::component[@class='SitemapTree']]"/>
    <!-- /SitemapTree -->

</xsl:stylesheet>
