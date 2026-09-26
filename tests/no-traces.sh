#!/bin/bash
# Этап 1: в коде и в базе не осталось следов вырезанных модулей.
#   bash tests/no-traces.sh [code|db|all] [модуль...]
#   модули: mail-core mail calendar comments forms ads blog shop (по умолчанию все)
# mail-core — отправка писем живёт в ядре: класс Energine\share\gears\Mail есть,
# а оставшийся код не ссылается на Energine\mail\gears\Mail*.
# Выход 0 — следов нет, 1 — найденное печатается.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scope=${1:-all}; shift
mods=("$@"); [ ${#mods[@]} -eq 0 ] && mods=(mail-core mail calendar comments forms ads blog shop)

# код: весь репозиторий, кроме истории (docs), переходного SQL (sql) и инструментов чистки
CODE_DIRS=(core site htdocs configs cli setup tests)
EXCLUDE=(--exclude=no-traces.sh --exclude-dir=tools)
# оставшиеся модули: для mail-core, пока каталог mail ещё не удалён
KEPT_DIRS=(core/modules/share core/modules/user core/modules/apps core/modules/seo site htdocs configs tests)

declare -A CODE TABLES PAGES
CODE[mail-core]='Energine\\mail\\(gears\\(Mail|MailTemplate)|components\\MailTemplateEditor)\b'
CODE[mail]='Energine\\mail\\|modules/mail/|MailProcessor|MailSource|mail_sender|mail_subscri|mail_crm|mail_email|mailout\.txt'
CODE[calendar]='Energine\\calendar\\|modules/calendar/|NewsCalendar|hasCalendar|CalendarObject|CalendarBuilder'
CODE[comments]='Energine\\comments\\|modules/comments/|Comments(Form|List|Editor)|\b(apps_news|share_sitemap|blog_post)_comment\b|comment_tables'
CODE[forms]='Energine\\forms\\|modules/forms/|frm_forms|\bform_[0-9]+\b|form-builder|FormEditor|FormResults'
CODE[ads]='Energine\\ads\\|modules/ads/|ads_items|ads_types|topBanner|leftAdBlock|left_adblock'
CODE[blog]='Energine\\blog\\|modules/blog/|blog_post|blog_title|Blog(Form|Editor)'
CODE[shop]='Energine\\shop\\|modules/shop/|\bshop_[a-z]|site_country|site_address|currency_id|country_id|countryId|smap_features_multi|share_sites_uploads|GridExtender|redirectToReferer'

# база: таблицы (REGEXP), шаблоны содержимого страниц
TABLES[mail]='^mail_(?!templates)'
TABLES[comments]='^(share_sitemap_comment|apps_news_comment)$'
TABLES[forms]='^(frm_|form_[0-9])'
TABLES[ads]='^ads_'
TABLES[blog]='^blog_'
TABLES[shop]='^(shop_|site_address$|site_country|share_sites_uploads$)'
PAGES[mail]='email_subscription mail_crm_editor mail_email_subscription_editor mail_subscription_editor subscriptions'
PAGES[comments]='comments_editor textblock_comments'
PAGES[forms]='form form_editor form_results'
PAGES[ads]='ads_item_editor ads_type_editor'
PAGES[blog]='blog_comments_editor blog_editor blog_post blog_post_editor'
PAGES[shop]='cart catalog catalog_products category_editor country_editor currency_editor delivery_types_editor feature_editor feature_group_editor goods_editor order_editor order_list order_status_editor payment_types_editor producer_editor promotion_editor search shop_editor wishlist'

M() { ( envsh=$(php8.5 "$R/tests/env.php" --shell) || exit 2; eval "$envsh"
        mysql -N -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1" ); }

fail=0
report() { # module scope found
  if [ -n "$3" ]; then echo "FAIL $1 $2:"; echo "$3" | head -8 | sed 's/^/     /'; fail=1
  else echo "ok   $1 $2"; fi
}

for m in "${mods[@]}"; do
  if [ "$scope" != db ]; then
    if [ "$m" = mail-core ]; then
      found=$(cd "$R" && grep -rnIE "${EXCLUDE[@]}" "${CODE[$m]}" "${KEPT_DIRS[@]}" 2>/dev/null)
      [ -f "$R/core/modules/share/gears/Mail.php" ] || found="$found"$'\n'"нет core/modules/share/gears/Mail.php"
      report "$m" code "$(echo "$found" | sed '/^$/d')"
    else
      report "$m" code "$(cd "$R" && grep -rnIE "${EXCLUDE[@]}" "${CODE[$m]}" "${CODE_DIRS[@]}" 2>/dev/null | cut -c1-160)"
    fi
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
    case $m in
      ads)  found+=$(M "SELECT CONCAT('page-xml leftAdBlock ', smap_id) FROM share_sitemap
                WHERE CONCAT_WS(' ', smap_content_xml, smap_layout_xml) LIKE '%leftAdBlock%'")$'\n' ;;
      mail) found+=$(M "SELECT CONCAT('mail template ', template_sysname) FROM mail_templates
                WHERE template_sysname LIKE 'mail\_news%' OR template_sysname LIKE 'mail\_crm%'")$'\n' ;;
      shop) found+=$(M "SELECT CONCAT('column ', TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND ((TABLE_NAME = 'share_sites' AND COLUMN_NAME IN ('currency_id', 'country_id'))
                   OR (TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'smap_features_multi'))")$'\n' ;;
    esac
    report "$m" db "$(echo "$found" | sed '/^$/d')"
  fi
done
exit $fail
