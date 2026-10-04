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
        <a class="skip-link print:hidden sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:rounded-ui focus:bg-primary focus:px-4 focus:py-2 focus:text-primary-fg" href="#content"><xsl:value-of select="$TRANSLATION[@const='TXT_SKIP_TO_CONTENT']"/></a>
        <header class="site-header print:border-0 border-b border-border bg-bg">
            <div class="{$UI_CONTAINER} site-header__inner flex flex-wrap items-center gap-x-6 gap-y-2 py-3">
                <a class="site-name mr-auto text-xl font-bold text-fg no-underline hover:text-primary">
                    <xsl:if test="$DOC_PROPS[@name='default'] != 1">
                        <xsl:attribute name="href"><xsl:value-of select="$BASE"/><xsl:value-of select="$LANG_ABBR"/></xsl:attribute>
                    </xsl:if>
                    <xsl:value-of select="$SITE_NAME"/>
                </a>
                <xsl:apply-templates select="$COMPONENTS[@name='mainMenu']"/>
                <div class="site-tools print:hidden flex flex-wrap items-center gap-x-4 gap-y-2 md:order-2">
                    <xsl:apply-templates select="$COMPONENTS[@class='LangSwitcher']"/>
                    <xsl:apply-templates select="$COMPONENTS[@name='userMenu']"/>
                </div>
            </div>
        </header>
        <div class="{$UI_CONTAINER} site-body grid gap-8 pt-6 pb-12 print:block print:p-0">
            <xsl:if test="content/container[@name='aside']">
                <xsl:attribute name="class"><xsl:value-of select="$UI_CONTAINER"/> site-body grid gap-8 pt-6 pb-12 print:block print:p-0 min-[60rem]:grid-cols-[minmax(0,1fr)_18rem]</xsl:attribute>
            </xsl:if>
            <main id="content" class="site-main min-w-0 outline-none" tabindex="-1">
                <xsl:apply-templates select="$COMPONENTS[@name='breadCrumbs']"/>
                <!-- страница ошибки: компонент добавляется в корень документа, а не в content -->
                <xsl:apply-templates select="$COMPONENTS[@class='ErrorComponent']"/>
                <xsl:apply-templates select="content/node()[not(self::container[@name='aside'])]"/>
            </main>
            <xsl:if test="content/container[@name='aside']">
                <aside class="site-aside min-w-0 print:hidden blocks:rounded-ui blocks:bg-bg-soft blocks:p-4 block-titles:text-lg">
                    <xsl:apply-templates select="content/container[@name='aside']/node()"/>
                </aside>
            </xsl:if>
        </div>
        <footer class="site-footer print:border-0 border-t border-border py-6 text-sm text-muted last-para:mb-0">
            <div class="{$UI_CONTAINER}">
                <xsl:apply-templates select="$COMPONENTS[@name='footerTextBlock']"/>
            </div>
        </footer>
    </xsl:template>

    <!-- главное меню: на телефоне сворачивается -->
    <xsl:template match="component[@name='mainMenu']" priority="1">
        <nav class="site-nav print:hidden order-3 basis-full" aria-label="{$TRANSLATION[@const='TXT_MAIN_MENU']}">
            <details class="site-menu ui-menu">
                <summary class="supports-[selector(::details-content)]:md:hidden inline-flex cursor-pointer list-none items-center gap-2 rounded-ui border border-border px-3.5 py-1.5 select-none"><xsl:value-of select="$TRANSLATION[@const='TXT_MENU']"/></summary>
                <xsl:apply-templates select="recordset"/>
            </details>
        </nav>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@name='mainMenu']]" priority="1">
        <xsl:if test="not(@empty) and record">
            <ul class="main_menu mt-2 mb-0 list-none p-0 md:mt-0 md:flex md:flex-wrap md:gap-x-6">
                <xsl:if test="parent::record">
                    <xsl:attribute name="class">main_menu main_menu--sub ui-submenu my-0 ml-4 list-none p-0 md:absolute md:top-full md:-left-3 md:z-20 md:ml-0 md:min-w-56 md:rounded-ui md:border md:border-border md:bg-bg md:py-1.5 md:shadow-lg</xsl:attribute>
                </xsl:if>
                <xsl:apply-templates select="record"/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@name='mainMenu']]" priority="1">
        <li>
            <xsl:attribute name="class">main_menu_item relative<xsl:if test="field[@name='Id'] = $ID"> active</xsl:if></xsl:attribute>
            <a class="flex px-1 py-2 no-underline aria-[current]:font-bold aria-[current]:text-fg md:px-0 md:py-1 in-[.ui-submenu]:md:px-3 in-[.ui-submenu]:md:py-1.5 in-[.ui-submenu]:md:whitespace-nowrap">
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
        <div class="user-menu flex items-center gap-2">
            <xsl:choose>
                <xsl:when test="@componentAction = 'showLogoutForm'">
                    <span class="user-menu__name text-muted"><xsl:value-of select="recordset/record/field[@name='u_fullname']"/></span>
                    <form method="post" action="{@action}" class="user-menu__logout m-0">
                        <input type="hidden" name="csrf_token" value="{$CSRF}"/>
                        <xsl:call-template name="ui-button">
                            <xsl:with-param name="variant" select="'link'"/>
                            <xsl:with-param name="name" select="'user[logout]'"/>
                            <xsl:with-param name="value" select="'1'"/>
                            <xsl:with-param name="text" select="$TRANSLATION[@const='BTN_LOGOUT']"/>
                        </xsl:call-template>
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
            <ul class="lang_switcher m-0 flex flex-wrap list-none gap-3 p-0">
                <xsl:apply-templates/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='LangSwitcher']]" priority="1">
        <li class="lang_switcher_item">
            <a class="aria-[current]:font-semibold aria-[current]:text-fg aria-[current]:no-underline">
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
            <nav class="breadcrumbs print:hidden" aria-label="{$TRANSLATION[@const='TXT_BREADCRUMBS']}">
                <ol class="m-0 mb-4 flex flex-wrap list-none gap-1 p-0 text-sm text-muted">
                    <xsl:apply-templates select="recordset/record"/>
                </ol>
            </nav>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@name='breadCrumbs']]" priority="1">
        <li class="crumb-next:before:mr-1 crumb-next:before:content-['/']">
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

    <!-- формы сайта (вход, регистрация, профиль, восстановление пароля): обёртка и подпись поля на утилитах;
         поля админки — fields.xslt ядра, как были -->
    <xsl:template match="field[not(@name='message')][ancestor::component[@type='form'][@sample='LoginForm' or @class='Register' or @class='UserProfile' or @class='RestorePassword']]" priority="2">
        <div>
            <xsl:attribute name="class">form-group field <xsl:value-of select="@name"/><xsl:if test="not(@nullable) and @type!='boolean'"> required</xsl:if><xsl:text> </xsl:text><xsl:value-of select="$UI_FIELD"/></xsl:attribute>
            <xsl:apply-templates select="." mode="field_name"/>
            <xsl:apply-templates select="." mode="field_content"/>
        </div>
    </xsl:template>

    <xsl:template match="field[not(@name='message')][ancestor::component[@type='form'][@sample='LoginForm' or @class='Register' or @class='UserProfile' or @class='RestorePassword']]" mode="field_name" priority="2">
        <xsl:if test="@title and @type!='boolean'">
            <div class="name">
                <label for="{@name}"><xsl:value-of select="@title" disable-output-escaping="yes"/></label>
                <xsl:if test="not(@nullable)"><span class="ml-0.5 text-danger" aria-hidden="true">*</span></xsl:if>
            </div>
        </xsl:if>
    </xsl:template>

    <!-- PageList: подразделы -->
    <xsl:template match="component[@class='PageList']">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="recordset[ancestor::component[@class='PageList']]">
        <xsl:if test="not(@empty)">
            <ul class="menu m-0 mb-6 grid list-none gap-4 p-0">
                <xsl:if test="parent::record">
                    <xsl:attribute name="class">menu mt-2 mb-0 ml-4 grid list-none gap-4 p-0</xsl:attribute>
                </xsl:if>
                <xsl:apply-templates/>
            </ul>
        </xsl:if>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='PageList']]">
        <li class="menu_item grid gap-1">
            <div class="menu_name text-[1.05rem] font-semibold">
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
                <div class="menu_announce text-muted">
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
        <ul class="sitemap_tree my-1 pl-5">
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
