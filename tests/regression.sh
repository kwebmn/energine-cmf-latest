#!/bin/bash
# Full regression of the site from env.php: every smoke test, cleanups, PHP log summary.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsh=$(php8.5 "$S/env.php" --shell) || exit 1; eval "$envsh"
M() { mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }
start=$(wc -l < $LOG)
echo "log start line: $start"
# Добавление страницы через админку сдвигает smap_order_num всему сайту (так устроено ядро),
# поэтому запоминаем порядок разделов и возвращаем его после прогона.
ORDER=$(mktemp)
M "SELECT CONCAT('UPDATE share_sitemap SET smap_order_num=', smap_order_num, ' WHERE smap_id=', smap_id, ';') FROM share_sitemap" > "$ORDER"
cd $S
echo "### smoke-final (read-only, all pages)"; bash smoke-final.sh
echo "### smoke-write"; bash smoke-write.sh
echo "### smoke-roundtrip"; php8.5 smoke-roundtrip.php
echo "### smoke-editing"; php8.5 smoke-editing.php
echo "### smoke-upload"; php8.5 smoke-upload.php
echo "### csrf"; php8.5 smoke-csrf.php
echo "### smoke-profile"; php8.5 smoke-profile.php
echo "### session-id"; php8.5 session-id.php
echo "### site-address"; php8.5 site-address.php
echo "### field-dates"; php8.5 field-dates.php
echo "### site-settings"; php8.5 site-settings.php
echo "### rights"; php8.5 smoke-rights.php
echo "### errors"; php8.5 smoke-errors.php
echo "### css"; bash css-build.sh
echo "### menu"; php8.5 menu.php
echo "### sections"; php8.5 sections.php
echo "### escaping"; php8.5 xslt-escaping.php
echo "### xslt-lint"; php8.5 xslt-lint.php
echo "### new-site-doc"; bash new-site-doc.sh
echo "### unused-constants"; php8.5 unused-constants.php
echo "### config-template"; php8.5 config-template.php
echo "### dbworker-call"; php8.5 dbworker-call.php
echo "### component-states"; php8.5 component-states.php
echo "### dev-tools"; php8.5 dev-tools.php
echo "### untranslated"; php8.5 untranslated.php
echo "### links"; php8.5 links.php
echo "### config-extends"; php8.5 config-extends.php
echo "### textblock-langs"; php8.5 textblock-langs.php
echo "### pages-delete"; php8.5 pages-delete.php
echo "### perimeter"; php8.5 perimeter.php
echo "### delete-guards"; php8.5 delete-guards.php
echo "### phpstan"; bash phpstan.sh
echo "### js-dead"; php8.5 js-dead.php
echo "### jscheck"; bash jscheck.sh
echo "### wrappers-selftest"; bash wrappers-selftest.sh
echo "### text-history"; php8.5 text-history.php
echo "### lang-inactive"; php8.5 lang-inactive.php
echo "### db"; php8.5 db.php
echo "### queries"; php8.5 queries.php

echo "### mail"
php8.5 smoke-mail.php
echo "### antispam"; php8.5 smoke-antispam.php
echo "### smtp"; php8.5 smoke-smtp.php
echo "--- mailbox recipients:"; grep -h "^To: " "$MAILBOX_FILE" 2>/dev/null | sort | uniq -c
echo "--- cleanup-mail"; php8.5 cleanup-mail.php mailbox

# последним: набор запирает IP этой машины (и убирает за собой) — прочим наборам он не мешает
echo "### login-limit"; php8.5 smoke-login-limit.php

sleep 1
echo "### PHP log since line $start"; bash smoke-log.sh $start
echo "### page order restored"
mysql --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$ORDER" && rm -f "$ORDER"

echo "### done"
