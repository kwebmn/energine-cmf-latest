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

</xsl:stylesheet>
