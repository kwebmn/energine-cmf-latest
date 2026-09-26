#!/bin/bash
# В коде и в базе не осталось следов вырезанного.
#   bash tests/no-traces.sh [code|db|all] [категория...]
# Этап 1 — модули: mail-core mail calendar comments forms ads blog shop
# Этап 2 — части apps: pageads branding tops vote feed tagcloud similar rss sockets htmlcap
# Этап 3 — share: tags widgets storages watermark video flash lookup columns placehold
# i18n — в справочнике переводов нет ни одной константы из списков удаления в sql/cut/*.sql.
# mail-core — отправка писем живёт в ядре: класс Energine\share\gears\Mail есть,
# а оставшийся код не ссылается на Energine\mail\gears\Mail*.
# Выход 0 — следов нет, 1 — найденное печатается, 2 — проверка не выполнена: база недоступна
# или поиск по коду завершился ошибкой (например, сломано выражение).
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scope=${1:-all}; shift
mods=("$@")
[ ${#mods[@]} -eq 0 ] && mods=(mail-core mail calendar comments forms ads blog shop
                                pageads branding tops vote feed tagcloud similar rss sockets htmlcap
                                tags widgets storages watermark video flash lookup columns placehold i18n)

# код: весь репозиторий, кроме истории (docs), переходного SQL (sql) и инструментов чистки
CODE_DIRS=(core site htdocs configs cli setup tests)
# сторонние библиотеки: их слова (createElement('video'), строки lang) — не следы Energine; удаляемые
# каталоги ловит проверка FILES. Артефакты прогонов тестов (вне git) тоже не код.
EXCLUDE=(--exclude=no-traces.sh --exclude-dir=tools
         --exclude-dir=ckeditor --exclude-dir=codemirror --exclude-dir=FileAPI --exclude-dir=select2
         --exclude-dir=jwplayer --exclude-dir=resizer
         --exclude='*.out' --exclude='*cookies.txt' --exclude=smoke-write.json)
KEPT_DIRS=(core/modules/share core/modules/user core/modules/apps core/modules/seo site htdocs configs tests)

# CODE — выражение для кода; FILES — файлы, которых быть не должно
declare -A CODE FILES
CODE[mail-core]='Energine\\mail\\(gears\\(Mail|MailTemplate)|components\\MailTemplateEditor)\b'
CODE[mail]='Energine\\mail\\|modules/mail/|MailProcessor|MailSource|mail_sender|mail_subscri|mail_crm|mail_email|mailout\.txt'
CODE[calendar]='Energine\\calendar\\|modules/calendar/|NewsCalendar|hasCalendar|CalendarObject|CalendarBuilder'
CODE[comments]='Energine\\comments\\|modules/comments/|Comments(Form|List|Editor)|\b(apps_news|share_sitemap|blog_post)_comment\b|comment_tables'
CODE[forms]='Energine\\forms\\|modules/forms/|frm_forms|\bform_[0-9]+\b|form-builder|FormEditor|FormResults'
CODE[ads]='Energine\\ads\\|modules/ads/|ads_items|ads_types|topBanner|leftAdBlock|left_adblock'
CODE[blog]='Energine\\blog\\|modules/blog/|blog_post|blog_title|Blog(Form|Editor)'
CODE[shop]='Energine\\shop\\|modules/shop/|\bshop_[a-z]|site_country|site_address|currency_id|country_id|countryId|smap_features_multi|share_sites_uploads|GridExtender|redirectToReferer'
CODE[pageads]='apps\\components\\Ads\b|AdsManager|\bapps_ads\b|pageAds|ad_top_728_90|top_adblock|content_adblock|ad_content_468_60'
CODE[branding]='apps\\components\\Branding|\bBranding\b|\bapps_branding\b|\bbrand_id\b|branding_editor|branding\.xslt|brand_main_img'
CODE[tops]='TopOfThePops|\bapps_tops|apps_top_groups|totp|TOTP'
CODE[vote]='apps\\components\\Vote|\bVote\b|VoteEditor|QuestionEditor|\bapps_vote|Vote\.js|single_vote|vote\.xslt|voteEditor|vote_repository|vote_question'
CODE[feed]='\bapps_feed\b|apps_feed_(tags|translation|uploads)|test_feed|testFeed|extfeed|ExtendedFeed\.component|ExtendedFeedEditor\.component'
CODE[tagcloud]='TagCloud|tagcloud'
CODE[similar]='SimilarNews|similarNews'
CODE[rss]='rss\.xslt|state name="rss"|function rss\(|/rss/'
CODE[sockets]='MooSocket|web_socket|WebSocketMain'
CODE[htmlcap]='HTMLCap'
FILES[sockets]='core/modules/apps/scripts/swfobject.js core/modules/apps/scripts/MooSocket.js core/modules/apps/scripts/web_socket.js core/modules/apps/scripts/WebSocketMain.swf'
FILES[vote]='core/modules/apps/scripts/Vote.js'
FILES[tops]='core/modules/apps/scripts/TOTP.js'
# этап 3. Кавычки внутри выражений — точкой (.tags.): так их не нужно экранировать в bash.
# Сторонние библиотеки (CKEditor и т. п.) выражения не задевают: они ищут код Energine.
CODE[tags]='TagManager|TagEditor|TextboxList|DropBoxList|tag_acpl|\bTags\.js|new Tags\(|BooleanTag|tagEditor|tags\.css|\bshare_tags|share_(sitemap|sites|uploads)_tags|apps_news_tags|getTagsTablename|getPagesByTag|name="tags"|@name ?= ?.tags.|[^-a-z_]tags. ?=>|registerState\(.tags.|state name="tag"|function tag\(|/tag/\[tagID\]|TXT_NEWS_BY_TAG|hasTags|\btag_(code|name|id)\b'
CODE[widgets]='[Ww]idgetsRepository|admin/widgets/|share_widgets|widget_xml|widget_icon_img|LayoutManager|WidgetGridManager|ComponentParamsForm|NewTemplateForm|layout_manager\.css|editBlocks|EDIT_BLOCKS|showWidgetEditor|widgetEditor|e-widget|e-lm-|widget="(widget|static)"|column="column"|@widget|@column|widgets_repository|buildWidget|build-widget|revertTemplate|revert-template|saveTemplate|save-template|saveNewTemplate|new-template|NewTemplateForm|getTemplateInfo|get-template-info|TXT_SAVE_TO_CURRENT_CONTENT'
CODE[storages]='FileRepositoryFTP|repositories\.ftp|FileRepositoryRO|FTPRO|\bFTP\b|.ftp. ?=>|repo/ftp|repo/ro\b'
CODE[watermark]='[Ww]atermark'
CODE[video]="VideoUploader|UPL_IS_READY|UPL_NOT_READY|TXT_NOT_READY|NOT_VIDEO_FILE|seo_sitemap_videos|videomap|maxVideos|ogp\.me/ns/video|jwplayer|\bPlayer\.js|Playlist\.js|new Player\(|embedPlayer|embed_player|putVideo|put-video|getPlayerParams|energinevideo|EnergineVideo|META_TYPE_VIDEO|setVideo|upl_is_mp4|upl_is_webm|upl_is_flv|upl_duration|upl_is_ready|\bis_(mp4|webm|flv)\b|VIDEO_PLAYER|player_box|playerBox|INSERT_VIDEO|media\.xslt|media_type=[\"']video[\"']|case [\"']video[\"']|== *[\"']video[\"']|[\"']video[\"'] *\)|_video[\"']"
CODE[flash]='EXT_FLASH|Swiff\.Uploader|expressInstall|swfobject|.Flash. *,|Flash video|\*\.flv'
CODE[lookup]='\bLookup\b|LookupConfig|UserLookup|Lookup\.js|lookupEditor|FIELD_TYPE_LOOKUP|[Ss]elect2|\bacpl\b|/lookup/|registerState\(.lookup.|function lookup\('
# имена типов полей в кавычках (case 'lookup':, type == 'lookup', @type='lookup', 'textbox')
CODE[tags]+="|[\"']textbox[\"']"
CODE[lookup]+="|[\"']lookup[\"']|@type=.lookup."
CODE[columns]='\b(u_fbid|u_vkid|u_company|u_position|news_show_image|news_is_top|upl_views)\b'
CODE[placehold]='placehold\.it'
FILES[tags]='core/modules/share/gears/TagManager.php core/modules/share/components/TagEditor.php core/modules/share/scripts/Tags.js core/modules/share/scripts/TagEditor.js core/modules/share/transformers/tagEditor.xslt core/modules/share/config/TagEditorModal.component.xml core/modules/share/stylesheets/tags.css core/modules/share/scripts/TextboxList.js core/modules/share/scripts/DropBoxList.js core/modules/share/stylesheets/acpl.css core/modules/share/images/remove_item.gif'
FILES[widgets]='core/modules/share/components/WidgetsRepository.php core/modules/share/config/WidgetsRepository.component.xml core/modules/share/config/ModalWidgetsRepository.component.xml core/modules/share/scripts/LayoutManager.js core/modules/share/scripts/WidgetGridManager.js core/modules/share/scripts/ComponentParamsForm.js core/modules/share/scripts/NewTemplateForm.js core/modules/share/stylesheets/layout_manager.css site/modules/main/templates/content/widgets_repository.content.xml core/modules/share/images/default_90x68.png core/modules/share/images/toolbar/minimize.gif core/modules/share/images/toolbar/restore.gif'
FILES[storages]='core/modules/share/gears/FileRepositoryFTP.php core/modules/share/gears/FileRepositoryFTPRO.php core/modules/share/gears/FileRepositoryRO.php core/modules/share/gears/FTP.php'
FILES[watermark]='core/modules/share/gears/WatermarkDefault.php core/modules/share/gears/FileRepositoryWatermark.php core/modules/share/gears/IWatermark.php'
FILES[video]='core/modules/share/gears/VideoUploader.php core/modules/share/scripts/jwplayer core/modules/share/scripts/Player.js core/modules/share/scripts/Playlist.js core/modules/share/transformers/media.xslt core/modules/share/transformers/embed_player.xslt core/modules/share/scripts/ckeditor/plugins/energinevideo'
FILES[flash]='core/modules/share/scripts/Swiff.Uploader.js core/modules/share/scripts/Swiff.Uploader.swf core/modules/share/scripts/expressInstall.swf core/modules/share/scripts/swfobject.js core/modules/share/images/player.swf'
FILES[lookup]='core/modules/share/components/Lookup.php core/modules/share/gears/LookupConfig.php core/modules/user/components/UserLookup.php core/modules/share/config/Lookup.component.xml core/modules/share/scripts/Lookup.js core/modules/share/scripts/select2 core/modules/share/stylesheets/select2 core/modules/user/config/UserLookup.component.xml'

# база: TABLES — имена таблиц (REGEXP), PAGES — шаблоны содержимого страниц,
# XMLCLASS — класс компонента в XML страниц и виджетов
declare -A TABLES PAGES XMLCLASS
TABLES[mail]='^mail_(?!templates)'
TABLES[comments]='^(share_sitemap_comment|apps_news_comment)$'
TABLES[forms]='^(frm_|form_[0-9])'
TABLES[ads]='^ads_'
TABLES[blog]='^blog_'
TABLES[shop]='^(shop_|site_address$|site_country|share_sites_uploads$)'
TABLES[pageads]='^apps_ads$'
TABLES[branding]='^apps_branding$'
TABLES[tops]='^(apps_tops|apps_top_groups)'
TABLES[vote]='^apps_vote'
TABLES[feed]='^(apps_feed|apps_feed_tags|apps_feed_translation|apps_feed_uploads|test_feed)$'
PAGES[mail]='email_subscription mail_crm_editor mail_email_subscription_editor mail_subscription_editor subscriptions'
PAGES[comments]='comments_editor textblock_comments'
PAGES[forms]='form form_editor form_results'
PAGES[ads]='ads_item_editor ads_type_editor'
PAGES[blog]='blog_comments_editor blog_editor blog_post blog_post_editor'
PAGES[shop]='cart catalog catalog_products category_editor country_editor currency_editor delivery_types_editor feature_editor feature_group_editor goods_editor order_editor order_list order_status_editor payment_types_editor producer_editor promotion_editor search shop_editor wishlist'
PAGES[branding]='branding_editor'
PAGES[tops]='totp_editor totp_group_editor'
PAGES[vote]='main/vote_repository main/vote_question_editor'
PAGES[feed]='extfeed'
XMLCLASS[pageads]='Energine\apps\components\Ads"'
XMLCLASS[branding]='Energine\apps\components\Branding"'
XMLCLASS[tops]='Energine\apps\components\TopOfThePops"'
XMLCLASS[vote]='Energine\apps\components\Vote"'
XMLCLASS[tagcloud]='Energine\apps\components\TagCloud"'
XMLCLASS[similar]='Energine\apps\components\SimilarNews"'
XMLCLASS[feed]='Energine\apps\components\ExtendedFeed"'
TABLES[tags]='^(share_tags|share_tags_translation|share_sitemap_tags|share_sites_tags|share_uploads_tags|apps_news_tags)$'
TABLES[widgets]='^share_widgets$'
PAGES[widgets]='main/widgets_repository'

# содержимое сайта: ссылки на удалённые разделы, слова вырезанных функций в текстовых блоках,
# демо-новости о вырезанном
declare -A LINKS WORDS NEWS
LINKS[shop]='catalog|cart|wishlist|my-orders|search'
LINKS[blog]='blogs'
LINKS[mail]='subscribe|subscriptions'
LINKS[forms]='form-example'
LINKS[ads]='banners'
LINKS[vote]='admin/polls'
LINKS[branding]='admin/branding'
LINKS[tops]='admin/tops|admin/tops-groups'
LINKS[feed]='test-feed'
LINKS[rss]='news/rss'
WORDS[ads]='баннер|банер'
WORDS[calendar]='календар'
WORDS[shop]='товар|заказ|замовлен|кошик|корзин|каталог'
WORDS[blog]='блог'
WORDS[comments]='коммент|комент'
WORDS[mail]='рассылк|розсил|подписк|підписк'
WORDS[vote]='(^|[^вВ])опрос|опитуван'
WORDS[tops]='подборк|добірк'
WORDS[branding]='бренд|оформлени[ея] раздел|оформлення розділ'
WORDS[rss]='rss'
WORDS[tagcloud]='облак|хмар'
NEWS[shop]="'catalog-filtry', 'sravnenie-tovarov', 'dve-valyuty'"
NEWS[blog]="'blogi-otlozhennye'"
NEWS[mail]="'rassylki-bez-spama'"
NEWS[ads]="'bannery-adresno'"
NEWS[tops]="'podborki-na-glavnoj'"
LINKS[widgets]='admin/widgets'
LINKS[tags]='news/tag'
WORDS[tags]='(^|[^а-яёіїє])тег'
WORDS[widgets]='виджет|віджет|перетаск|перетяг'
WORDS[storages]='ftp|read-only'
WORDS[watermark]='водян'
WORDS[video]='видео|відео|ffmpeg'
WORDS[flash]='flash|флеш'

# ошибка доступа к базе печатается строкой с меткой __DBERROR__: пустой ответ не должен
# засчитываться как «следов нет»
M() { ( envsh=$(php8.5 "$R/tests/env.php" --shell 2>&1) || { echo "__DBERROR__ $envsh"; exit 0; }
        eval "$envsh"
        # кодировка соединения явно: без неё клиент берёт её из локали (LC_ALL=C — latin1),
        # и кириллица в запросах молча не совпадает
        mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1" 2>&1 || echo "__DBERROR__ mysql" ); }

# поиск по коду: код 2 у grep (ошибка в выражении, нечитаемый файл) печатается строкой с меткой
# __GREPERROR__ — как и с базой, пустой ответ не должен засчитываться как «следов нет»
# Строки конфигов площадок (configs/system.config.<домен>.php, в них пароли) печатаются без
# содержимого — только файл и номер строки; шаблон system.config.default.php — как есть.
G() { local out; out=$(cd "$R" && grep -rnIE "${EXCLUDE[@]}" "$@" 2>&1); [ $? -gt 1 ] && { echo "__GREPERROR__ $out"; return; }
      sed -E '/^configs\/system\.config\.default\.php:/! s#^(configs/[^:]+:[0-9]+):.*#\1: (строка конфига площадки не печатается)#' <<<"$out"; }

fail=0
dberror=0
greperror=0
report() { # category scope found
  if [ -n "$3" ]; then echo "FAIL $1 $2:"; echo "$3" | head -8 | sed 's/^/     /'; fail=1
  else echo "ok   $1 $2"; fi
  grep -q '__DBERROR__' <<<"$3" && dberror=1
  grep -q '__GREPERROR__' <<<"$3" && greperror=1
}

# репозиторий виджетов (share_widgets) вырезан на этапе 3: на его XML проверки смотрят, пока таблица есть
widgets_sql() { # выражение для LOCATE
  [ "$HAS_WIDGETS" = 1 ] && echo "UNION SELECT CONCAT('widget ', widget_id) FROM share_widgets WHERE LOCATE('$1', widget_xml) > 0"
}
HAS_WIDGETS=0
[ "$scope" != code ] && HAS_WIDGETS=$(M "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_widgets'")
case "$HAS_WIDGETS" in 0|1) ;; *) echo "FAIL db: $HAS_WIDGETS"; echo "база недоступна: проверка по базе не выполнена"; exit 2;; esac

for m in "${mods[@]}"; do
  if [ "$m" = i18n ]; then
    [ "$scope" = code ] && continue
    names=$(sed -n '/DELETE FROM `share_lang_tags` WHERE `ltag_name` IN (/,/);/p' "$R"/sql/cut/*.sql \
            | grep -oE "'[A-Za-z0-9_]+'" | sort -u | paste -sd, -)
    [ -z "$names" ] && { report i18n db "__DBERROR__ в sql/cut/*.sql нет списков удаления переводов"; continue; }
    report i18n db "$(M "SELECT CONCAT('constant ', ltag_name) FROM share_lang_tags WHERE ltag_name IN ($names)")"
    continue
  fi
  if [ "$scope" != db ]; then
    if [ "$m" = mail-core ]; then
      found=$(G "${CODE[$m]}" "${KEPT_DIRS[@]}")
      [ -f "$R/core/modules/share/gears/Mail.php" ] || found="$found"$'\n'"нет core/modules/share/gears/Mail.php"
    else
      found=$(G "${CODE[$m]}" "${CODE_DIRS[@]}" | cut -c1-160)
      for f in ${FILES[$m]}; do [ -e "$R/$f" ] && found+=$'\n'"file $f"; done
    fi
    report "$m" code "$(echo "$found" | sed '/^$/d')"
  fi
  if [ "$scope" != code ] && [ "$m" != mail-core ]; then
    found=""
    [ -n "${TABLES[$m]}" ] && found+=$(M "SELECT CONCAT('table ', TABLE_NAME) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME REGEXP '${TABLES[$m]}'")$'\n'
    if [ -n "${PAGES[$m]}" ]; then
      list=$(printf "'%s.content.xml'," ${PAGES[$m]}); list=${list%,}
      found+=$(M "SELECT CONCAT('page ', smap_id, ' ', smap_segment, ' ', smap_content) FROM share_sitemap
          WHERE smap_content IN ($list)")$'\n'
    fi
    found+=$(M "SELECT CONCAT('page-xml ', smap_id) FROM share_sitemap
        WHERE LOCATE('Energine\\\\$m\\\\', CONCAT_WS(' ', smap_content_xml, smap_layout_xml)) > 0
        $(widgets_sql "Energine\\\\$m\\\\")")$'\n'
    if [ -n "${XMLCLASS[$m]}" ]; then
      cls=${XMLCLASS[$m]//\\/\\\\}
      found+=$(M "SELECT CONCAT('page-xml ', smap_id) FROM share_sitemap
          WHERE LOCATE('$cls', CONCAT_WS(' ', smap_content_xml, smap_layout_xml)) > 0
          $(widgets_sql "$cls")")$'\n'
    fi
    if [ -n "${LINKS[$m]}" ]; then
      re="href=\"(/ua)?/(${LINKS[$m]})[/\"?]"
      found+=$(M "SELECT CONCAT('link tb ', tb_id, '/', lang_id) FROM share_textblocks_translation WHERE tb_content REGEXP '$re'
          UNION SELECT CONCAT('link news ', news_id, '/', lang_id) FROM apps_news_translation
          WHERE CONCAT_WS(' ', news_announce_rtf, news_text_rtf) REGEXP '$re'")$'\n'
    fi
    [ -n "${WORDS[$m]}" ] && found+=$(M "SELECT CONCAT('text tb ', tb_id, '/', lang_id) FROM share_textblocks_translation
        WHERE LOWER(tb_content) REGEXP '${WORDS[$m]}'")$'\n'
    [ -n "${NEWS[$m]}" ] && found+=$(M "SELECT CONCAT('news ', news_segment) FROM apps_news WHERE news_segment IN (${NEWS[$m]})")$'\n'
    case $m in
      ads)      found+=$(M "SELECT CONCAT('page-xml leftAdBlock ', smap_id) FROM share_sitemap
                    WHERE CONCAT_WS(' ', smap_content_xml, smap_layout_xml) LIKE '%leftAdBlock%'")$'\n' ;;
      mail)     found+=$(M "SELECT CONCAT('mail template ', template_sysname) FROM mail_templates
                    WHERE template_sysname LIKE 'mail\_news%' OR template_sysname LIKE 'mail\_crm%'")$'\n' ;;
      shop)     found+=$(M "SELECT CONCAT('column ', TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND ((TABLE_NAME = 'share_sites' AND COLUMN_NAME IN ('currency_id', 'country_id'))
                       OR (TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'smap_features_multi'))")$'\n' ;;
      tags)     found+=$(M "SELECT CONCAT('page-xml tags ', smap_id) FROM share_sitemap
                    WHERE LOCATE('<param name=\"tags\">', CONCAT_WS(' ', smap_content_xml, smap_layout_xml)) > 0")$'\n' ;;
      widgets)  found+=$(M "SELECT CONCAT('page-xml widget ', smap_id) FROM share_sitemap
                    WHERE CONCAT_WS(' ', smap_content_xml, smap_layout_xml) REGEXP ' (widget|column)=\"'")$'\n' ;;
      storages) found+=$(M "SELECT CONCAT('repository ', upl_id, ' ', upl_mime_type) FROM share_uploads
                    WHERE upl_mime_type IN ('repo/ftp', 'repo/ftpro', 'repo/ro')")$'\n' ;;
      video)    found+=$(M "SELECT CONCAT('column share_uploads.', COLUMN_NAME) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_uploads'
                      AND COLUMN_NAME IN ('upl_is_mp4', 'upl_is_webm', 'upl_is_flv', 'upl_duration', 'upl_is_ready')
                    UNION SELECT CONCAT('upload ', upl_id, ' video') FROM share_uploads WHERE upl_internal_type = 'video'")$'\n' ;;
      columns)  found+=$(M "SELECT CONCAT('column ', TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND ((TABLE_NAME = 'user_users' AND COLUMN_NAME IN ('u_fbid', 'u_vkid', 'u_company', 'u_position'))
                       OR (TABLE_NAME = 'apps_news' AND COLUMN_NAME IN ('news_show_image', 'news_is_top'))
                       OR (TABLE_NAME = 'share_uploads' AND COLUMN_NAME = 'upl_views'))")$'\n' ;;
      branding) found+=$(M "SELECT CONCAT('column ', TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'brand_id'")$'\n' ;;
    esac
    report "$m" db "$(echo "$found" | sed '/^$/d')"
  fi
done
[ $greperror = 1 ] && { echo "поиск по коду завершился ошибкой: проверка кода не выполнена"; exit 2; }
[ $dberror = 1 ] && { echo "база недоступна: проверка по базе не выполнена"; exit 2; }
exit $fail
