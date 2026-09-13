<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

    <!-- Blogs (Energine\blog\components\BlogPost). Forms of the post (create, edit) use the common form templates. -->

    <xsl:variable name="BLOGS_URL" select="concat($BASE, $LANG_ABBR, $COMPONENTS[@class='BlogPost']/@blogs_url)"/>

    <!-- lists: latest posts, posts of a blog -->
    <xsl:template match="component[@class='BlogPost'][@type='list']">
        <div class="feed blog">
            <xsl:apply-templates select="$COMPONENTS[@name='blogCalendar']"/>
            <div class="blog_header">
                <xsl:if test="@blog_id">
                    <p class="blog_author"><xsl:value-of select="@blog_author"/></p>
                    <a class="blog_all_posts" href="{$BLOGS_URL}"><xsl:value-of select="$TRANSLATION[@const='TXT_BLOG_ALL_POSTS']"/></a>
                </xsl:if>
                <xsl:if test="@curr_user_blog_id">
                    <a class="blog_new_post btn btn-primary" href="{$BLOGS_URL}post/create/"><xsl:value-of select="$TRANSLATION[@const='TXT_BLOG_NEW_POST']"/></a>
                </xsl:if>
            </div>
            <xsl:choose>
                <xsl:when test="recordset/@empty">
                    <div class="empty_message"><xsl:value-of select="$TRANSLATION[@const='TXT_BLOG_EMPTY']"/></div>
                </xsl:when>
                <xsl:otherwise>
                    <ul class="feed_list blog_list">
                        <xsl:apply-templates select="recordset/record"/>
                    </ul>
                    <xsl:apply-templates select="toolbar[@name='pager']"/>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>

    <xsl:template match="record[ancestor::component[@class='BlogPost'][@type='list']]">
        <xsl:variable name="POST_URL" select="concat($BLOGS_URL, 'post/', field[@name='post_id'], '/')"/>
        <li class="feed_item blog_item">
            <div class="feed_date"><xsl:value-of select="field[@name='post_created']"/></div>
            <div class="blog_info">
                <a href="{$BLOGS_URL}blog/{field[@name='blog_id']}/"><xsl:value-of select="field[@name='blog_name']"/></a>
                <xsl:text>, </xsl:text>
                <span class="blog_author"><xsl:value-of select="field[@name='u_fullname']"/></span>
            </div>
            <h4 class="feed_name"><a href="{$POST_URL}"><xsl:value-of select="field[@name='post_name']"/></a></h4>
            <div class="feed_announce"><xsl:value-of select="field[@name='post_text_rtf']" disable-output-escaping="yes"/></div>
            <div class="blog_links">
                <a href="{$POST_URL}#comments"><xsl:value-of select="$TRANSLATION[@const='TXT_BLOG_COMMENTS']"/>: <xsl:value-of select="field[@name='comments_num']"/></a>
                <xsl:call-template name="BLOG_POST_EDIT_LINK"/>
            </div>
        </li>
    </xsl:template>

    <!-- post -->
    <xsl:template match="component[@class='BlogPost'][@componentAction='view']">
        <xsl:for-each select="recordset/record">
            <div class="feed_view blog_view">
                <div class="feed_date"><xsl:value-of select="field[@name='post_created']"/></div>
                <div class="blog_info">
                    <a href="{$BLOGS_URL}blog/{field[@name='blog_id']}/"><xsl:value-of select="field[@name='blog_name']"/></a>
                    <xsl:text>, </xsl:text>
                    <span class="blog_author"><xsl:value-of select="field[@name='u_fullname']"/></span>
                </div>
                <div class="feed_text"><xsl:value-of select="field[@name='post_text_rtf']" disable-output-escaping="yes"/></div>
                <div class="blog_links">
                    <xsl:call-template name="BLOG_POST_EDIT_LINK"/>
                </div>
                <div class="go_back">
                    <a href="{$BLOGS_URL}blog/{field[@name='blog_id']}/"><xsl:value-of select="$TRANSLATION[@const='TXT_BACK_TO_LIST']"/></a>
                </div>
                <a name="comments"/>
            </div>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="BLOG_POST_EDIT_LINK">
        <xsl:variable name="COMPONENT" select="ancestor::component[@class='BlogPost']"/>
        <xsl:if test="$COMPONENT/@curr_user_is_admin or ($COMPONENT/@curr_user_id = field[@name='u_id'])">
            <a class="blog_edit" href="{$BLOGS_URL}post/{field[@name='post_id']}/edit/"><xsl:value-of select="$TRANSLATION[@const='BTN_EDIT']"/></a>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
