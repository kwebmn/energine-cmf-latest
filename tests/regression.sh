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
. ./suite-lib.sh
suite "smoke-final (read-only, all pages)" bash smoke-final.sh
suite smoke-write bash smoke-write.sh
suite smoke-roundtrip php8.5 smoke-roundtrip.php
suite smoke-editing php8.5 smoke-editing.php
suite smoke-upload php8.5 smoke-upload.php
suite csrf php8.5 smoke-csrf.php
suite smoke-profile php8.5 smoke-profile.php
suite session-id php8.5 session-id.php
suite site-address php8.5 site-address.php
suite field-dates php8.5 field-dates.php
suite site-settings php8.5 site-settings.php
suite rights php8.5 smoke-rights.php
suite errors php8.5 smoke-errors.php
suite css bash css-build.sh
suite menu php8.5 menu.php
suite sections php8.5 sections.php
suite escaping php8.5 xslt-escaping.php
suite xslt-lint php8.5 xslt-lint.php
suite new-site-doc bash new-site-doc.sh
suite unused-constants php8.5 unused-constants.php
suite config-template php8.5 config-template.php
suite dbworker-call php8.5 dbworker-call.php
suite component-states php8.5 component-states.php
suite dev-tools php8.5 dev-tools.php
suite untranslated php8.5 untranslated.php
suite links php8.5 links.php
suite config-extends php8.5 config-extends.php
suite textblock-langs php8.5 textblock-langs.php
suite pages-delete php8.5 pages-delete.php
suite perimeter php8.5 perimeter.php
suite delete-guards php8.5 delete-guards.php
suite phpstan bash phpstan.sh
suite js-dead php8.5 js-dead.php
suite jscheck bash jscheck.sh
suite wrappers-selftest bash wrappers-selftest.sh
suite regression-selftest bash regression-selftest.sh
suite text-history php8.5 text-history.php
suite lang-inactive php8.5 lang-inactive.php
suite db php8.5 db.php
suite queries php8.5 queries.php
suite translator php8.5 translator.php
suite schema-info php8.5 schema-info.php
suite field-type php8.5 field-type.php
suite json-builder php8.5 json-builder.php
suite registry php8.5 registry.php
suite urls php8.5 urls.php
suite page-aliases php8.5 page-aliases.php
suite resizer php8.5 resizer.php
suite text-links php8.5 text-links.php
suite file-guard php8.5 file-guard.php
suite page-templates php8.5 page-templates.php
suite lang-switcher php8.5 lang-switcher.php
suite page-link php8.5 page-link.php

suite mail php8.5 smoke-mail.php
suite antispam php8.5 smoke-antispam.php
suite smtp php8.5 smoke-smtp.php
echo "--- mailbox recipients:"; grep -h "^To: " "$MAILBOX_FILE" 2>/dev/null | sort | uniq -c
echo "--- cleanup-mail"; php8.5 cleanup-mail.php mailbox

# последним: набор запирает IP этой машины (и убирает за собой) — прочим наборам он не мешает
suite login-limit php8.5 smoke-login-limit.php

sleep 1
echo "### PHP log since line $start"; bash smoke-log.sh $start
echo "### page order restored"
mysql --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$ORDER" && rm -f "$ORDER"

echo "### done"
