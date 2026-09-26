#!/bin/bash
# Full regression of the site from env.php: every smoke test, cleanups, PHP log summary.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsh=$(php8.5 "$S/env.php" --shell) || exit 1; eval "$envsh"
M() { mysql -N -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }
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
echo "### smoke-profile"; php8.5 smoke-profile.php
echo "### session-id"; php8.5 session-id.php

echo "### mail (recipients -> local mailbox)"
RCP_ORIG=$(M "SELECT rcp_recipients FROM apps_feedback_recipient WHERE rcp_id=5")
restore() {
  M "UPDATE apps_feedback_recipient SET rcp_recipients='$RCP_ORIG' WHERE rcp_id=5;"
  echo "recipients restored: $(M "SELECT rcp_recipients FROM apps_feedback_recipient WHERE rcp_id=5")"
}
trap restore EXIT
M "UPDATE apps_feedback_recipient SET rcp_recipients='$MAILBOX' WHERE rcp_id=5;"
php8.5 smoke-mail.php
echo "--- mailbox recipients:"; grep -h "^To: " "$MAILBOX_FILE" 2>/dev/null | sort | uniq -c
echo "--- cleanup-mail"; php8.5 cleanup-mail.php mailbox
restore; trap - EXIT

sleep 1
echo "### PHP log since line $start"; bash smoke-log.sh $start
echo "### page order restored"
mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$ORDER" && rm -f "$ORDER"

echo "### done"
