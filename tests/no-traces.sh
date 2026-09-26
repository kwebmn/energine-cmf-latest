#!/bin/bash
# В коде и в базе не осталось следов вырезанного.
#   bash tests/no-traces.sh [code|db|all] [категория...]
# Этап 1 — модули: mail-core mail calendar comments forms ads blog shop
# Этап 2 — части apps: pageads branding tops vote feed tagcloud similar rss sockets htmlcap
# i18n — в справочнике переводов нет ни одной константы из списков удаления в sql/cut/*.sql.
# mail-core — отправка писем живёт в ядре: класс Energine\share\gears\Mail есть,
# а оставшийся код не ссылается на Energine\mail\gears\Mail*.
# Выход 0 — следов нет, 1 — найденное печатается, 2 — база недоступна.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scope=${1:-all}; shift
mods=("$@")
[ ${#mods[@]} -eq 0 ] && mods=(mail-core mail calendar comments forms ads blog shop
                                pageads branding tops vote feed tagcloud similar rss sockets htmlcap i18n)

# код: весь репозиторий, кроме истории (docs), переходного SQL (sql) и инструментов чистки
CODE_DIRS=(core site htdocs configs cli setup tests)
EXCLUDE=(--exclude=no-traces.sh --exclude-dir=tools)
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
CODE[pageads]='apps\\components\\Ads\b|AdsManager|\bapps_ads\b|pageAds|ad_top_728_90|top_adblock'
CODE[branding]='apps\\components\\Branding|\bapps_branding\b|\bbrand_id\b|branding_editor|branding\.xslt|brand_main_img'
CODE[tops]='TopOfThePops|\bapps_tops|apps_top_groups|totp|TOTP'
CODE[vote]='apps\\components\\Vote|VoteEditor|VoteQuestionEditor|\bapps_vote|Vote\.js|single_vote|vote\.xslt|voteEditor|vote_repository|vote_question'
CODE[feed]='\bapps_feed\b|apps_feed_(tags|translation|uploads)|test_feed|extfeed|ExtendedFeed\.component|ExtendedFeedEditor\.component'
CODE[tagcloud]='TagCloud|tagcloud'
CODE[similar]='SimilarNews|similarNews'
CODE[rss]='rss\.xslt|state name="rss"|function rss\(|/rss/'
CODE[sockets]='MooSocket|web_socket|WebSocketMain'
CODE[htmlcap]='HTMLCap'
FILES[sockets]='core/modules/apps/scripts/swfobject.js core/modules/apps/scripts/MooSocket.js core/modules/apps/scripts/web_socket.js core/modules/apps/scripts/WebSocketMain.swf'
FILES[vote]='core/modules/apps/scripts/Vote.js'
FILES[tops]='core/modules/apps/scripts/TOTP.js'

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

# ошибка доступа к базе печатается строкой с меткой __DBERROR__: пустой ответ не должен
# засчитываться как «следов нет»
M() { ( envsh=$(php8.5 "$R/tests/env.php" --shell 2>&1) || { echo "__DBERROR__ $envsh"; exit 0; }
        eval "$envsh"
        mysql -N -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1" 2>&1 || echo "__DBERROR__ mysql" ); }

fail=0
dberror=0
report() { # category scope found
  if [ -n "$3" ]; then echo "FAIL $1 $2:"; echo "$3" | head -8 | sed 's/^/     /'; fail=1
  else echo "ok   $1 $2"; fi
  grep -q '__DBERROR__' <<<"$3" && dberror=1
}

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
      found=$(cd "$R" && grep -rnIE "${EXCLUDE[@]}" "${CODE[$m]}" "${KEPT_DIRS[@]}" 2>/dev/null)
      [ -f "$R/core/modules/share/gears/Mail.php" ] || found="$found"$'\n'"нет core/modules/share/gears/Mail.php"
    else
      found=$(cd "$R" && grep -rnIE "${EXCLUDE[@]}" "${CODE[$m]}" "${CODE_DIRS[@]}" 2>/dev/null | cut -c1-160)
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
        UNION SELECT CONCAT('widget ', widget_id) FROM share_widgets WHERE LOCATE('Energine\\\\$m\\\\', widget_xml) > 0")$'\n'
    if [ -n "${XMLCLASS[$m]}" ]; then
      cls=${XMLCLASS[$m]//\\/\\\\}
      found+=$(M "SELECT CONCAT('page-xml ', smap_id) FROM share_sitemap
          WHERE LOCATE('$cls', CONCAT_WS(' ', smap_content_xml, smap_layout_xml)) > 0
          UNION SELECT CONCAT('widget ', widget_id) FROM share_widgets WHERE LOCATE('$cls', widget_xml) > 0")$'\n'
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
      branding) found+=$(M "SELECT CONCAT('column ', TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'brand_id'")$'\n' ;;
    esac
    report "$m" db "$(echo "$found" | sed '/^$/d')"
  fi
done
[ $dberror = 1 ] && { echo "база недоступна: проверка по базе не выполнена"; exit 2; }
exit $fail
