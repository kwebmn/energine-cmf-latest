#!/bin/bash
# setup linker на общей раскладке: модули остаются настоящими каталогами, в web/ появляются ссылки.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$(dirname "$(dirname "$R")")/web"
USER_="$(stat -c %U "$R")"
fail=0
out=$(cd "$WEB" && runuser -u "$USER_" -- php8.5 index.php setup linker 2>&1)
echo "$out" | grep -qiE 'warning|exception|fatal' && { echo "FAIL linker output: $(echo "$out" | grep -iE 'warning|exception|fatal' | head -3)"; fail=1; }
for m in share user apps seo; do
  [ -d "$R/core/modules/$m" ] && [ ! -L "$R/core/modules/$m" ] || { echo "FAIL core/modules/$m is not a real directory"; fail=1; }
done
[ -f "$R/core/modules/share/components/Grid.php" ] || { echo "FAIL core files missing"; fail=1; }
t=$(readlink -f "$WEB/scripts/Energine.js")
[ "$t" = "$R/core/modules/share/scripts/Energine.js" ] || { echo "FAIL web/scripts/Energine.js -> $t"; fail=1; }
[ $fail = 0 ] && echo "== setup-linker: ok"
exit $fail
