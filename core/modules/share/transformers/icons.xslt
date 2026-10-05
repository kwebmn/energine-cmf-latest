<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!--
        Значок админки из спрайта images/icons.svg (UI-подпроект 3). Значок — украшение (aria-hidden): доступное имя
        даёт кнопка (текст, title или aria-label). Размер — 1em, цвет — цвет текста. То же в JS — Energine.icon(имя).
    -->
    <xsl:template name="admin-icon">
        <xsl:param name="name"/>
        <svg class="a:inline-block a:size-[1.15em] a:shrink-0 a:align-[-.2em]" aria-hidden="true" focusable="false">
            <use href="{$STATIC_URL}images/icons.svg#{$name}"/>
        </svg>
    </xsl:template>

    <!-- Подсказка экрана админки «?» (свойство help компонента — константа HELP_<КЛАСС>_<СОСТОЯНИЕ>): кнопка в правом
         углу верхней панели, по щелчку — текст; без подсказки ничего не выводится -->
    <xsl:template name="admin-help">
        <xsl:variable name="C" select="ancestor-or-self::component[1]"/>
        <xsl:if test="$C/@help">
            <details class="e-help a:absolute a:top-1 a:right-1 a:z-20">
                <summary aria-label="{$C/@help_title}" title="{$C/@help_title}"
                         class="a:flex a:size-7 a:cursor-pointer a:list-none a:items-center a:justify-center a:rounded-full a:border a:border-border a:bg-bg a:font-semibold a:text-primary a:focus-visible:outline-2 a:focus-visible:outline-primary">?</summary>
                <div class="e-help-text a:absolute a:right-0 a:mt-1 a:w-80 a:max-w-[calc(100vw-2rem)] a:rounded-ui a:border a:border-border a:bg-bg a:p-3 a:text-sm a:leading-relaxed a:shadow-lg a:whitespace-pre-line">
                    <xsl:value-of select="$C/@help"/>
                </div>
            </details>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
