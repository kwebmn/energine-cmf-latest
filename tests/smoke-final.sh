#!/bin/bash
# Read-only smoke test (all pages of the sitemap incl. modules) of the site from env.php; prints HTTP/page failures and new PHP log messages.
SCR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsh=$(php8.5 "$SCR/env.php" --shell) || exit 1; eval "$envsh"
J=$SCR/smoke-final-cookies.txt
T=$SCR/smoke-final-page.out
start=$(wc -l < $LOG)
fail=0
marker='Fatal error|Warning: |Notice: |Deprecated: |Uncaught |object\([A-Za-z\\]+Exception\)|<title>Errors</title>'

check() { # label url expected_code [curl args...]
  local label=$1 url=$2 exp=$3; shift 3
  local code; code=$(curl -sS -c $J -b $J -o $T -w '%{http_code}' "$@" "$url")
  local err; err=$(grep -m1 -oE "$marker" $T)
  if [ "$code" != "$exp" ] || [ -n "$err" ]; then
    echo "FAIL [$label] $code (want $exp) ${url#$B} $err"; fail=$((fail+1))
  fi
}
# токен страницы (Csrf): у гостя — для входа, после входа — для всех POST админки
tok() { curl -sS -c $J -b $J "$1" | sed -n 's/.*<meta name="csrf-token" content="\([0-9a-f]*\)".*/\1/p' | head -1; }
checkjson() { # label url
  local label=$1 url=$2
  curl -sS -c $J -b $J -X POST -H 'X-Request: JSON' -H "X-CSRF-Token: $TOK" -o $T "$url"
  if ! php8.5 -r '$d=json_decode(file_get_contents($argv[1]),true); exit(is_array($d) && !empty($d["result"]) ? 0 : 1);' $T; then
    echo "FAIL [$label] ${url#$B} $(head -c 160 $T | tr '\n' ' ')"; fail=$((fail+1))
  fi
}

rm -f $J
# public pages, both languages; главная — отдельно: в списках путей её нет (пустые строки пропускаются)
for lang in "" "ua/"; do
  check "public" "$B/${lang}" 200
  while read p; do
    case "$p" in admin*) continue;; esac
    check "public" "$B/${lang}${p}" 200
  done < $SCR/paths-guest.txt
done
check "404" "$B/no-such-page/" 404
check "robots" "$B/robots.txt/" 200
# карта сайта (её список, не меню в шапке) перечисляет разделы, а не одну главную
check "sitemap" "$B/sitemap/" 200
miss=$(php8.5 -r '$d = new DOMDocument(); @$d->loadHTML(file_get_contents($argv[1])); $x = new DOMXPath($d); $h = [];
  foreach ($x->query("//ul[contains(concat(\" \", normalize-space(@class), \" \"), \" sitemap_tree \")]//a/@href") as $a) $h[] = trim(preg_replace("~^https?://[^/]+/~", "", $a->value), "/");
  echo implode(" ", array_diff(["info", "features"], $h)), "|", implode(" ", array_intersect(["login", "restore-password", "robots.txt", "google-sitemap"], $h));' $T)
[ "${miss%%|*}" = "" ] || { echo "FAIL [sitemap] в карте сайта нет: ${miss%%|*}"; fail=$((fail+1)); }
# служебные страницы (закрыты от индексации) в карте для людей не показываются
[ "${miss#*|}" = "" ] || { echo "FAIL [sitemap] в карте сайта служебные страницы: ${miss#*|}"; fail=$((fail+1)); }
check "resizer" "$B/resizer/w90-h68/uploads/public/13662314846.png" 200
check "static" "$B/scripts/Energine.js" 200

# login
TOK=$(tok $B/login/)
curl -sS -c $J -b $J -o /dev/null -e "$B/login/" --data-urlencode "csrf_token=$TOK" --data-urlencode 'user[login]=1' \
  --data-urlencode "user[username]=$ADMIN_EMAIL" --data-urlencode "user[password]=$ADMIN_PASSWORD" $B/auth.php
grep -q NRGNSID $J || { echo "FAIL [login] no session cookie"; fail=$((fail+1)); }
TOK=$(tok $B/)

# admin pages and public pages as admin
check "admin" "$B/" 200
while read p; do check "admin" "$B/$p" 200; done < $SCR/paths-all.txt
# grids: тот же список, что у обхода браузером; без списка проверка не проходит
L=$SCR/audit/crawl-singles.txt
[ -s "$L" ] || { echo "FAIL [grid] нет списка ${L#$SCR/}"; fail=$((fail+1)); }
while read s; do
  [ -z "$s" ] && continue
  case "$s" in *[dD]ivEditor*) checkjson "grid" "$B/${s}get-data/";; *) checkjson "grid" "$B/${s}get-data/page-1";; esac
done < "$L"
checkjson "filelib" "$B/admin/users/single/adminPanel/file-library/1/get-data/"
# forms; записи — из базы, а не номера одной площадки: раздел демо «Информация» и пользователь,
# который не входит в этот тест администратором
q() { mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }
page=$(q "SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info'
  AND smap_pid = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL)")
user=$(q "SELECT MIN(u_id) FROM user_users WHERE u_name <> '$ADMIN_EMAIL'")
A=$B/admin
for u in structure/single/divEditor/80/edit/ structure/single/divEditor/$page/edit/ structure/single/divEditor/add/80/ \
  users/single/userEditor/$user/edit/ users/single/userEditor/add/ users/roles/single/roleEditor/1/edit/ \
  settings/single/settings/1/edit/ translations/single/transEditor/14/edit/ translations/single/transEditor/add/ \
  translations/languages/single/langEditor/1/edit/ \
  users/single/adminPanel/file-library users/single/adminPanel/file-library/1/add/; do
  check "form" "$A/$u" 200
done

sleep 1
echo "== failures: $fail"
echo "== new PHP log messages:"
tail -n +$((start+1)) $LOG | grep -oE 'PHP (message: )?(Deprecated|Warning|Notice|Fatal error|error [0-9]+ thrown as SystemException)[^"]*' \
  | sed -E 's/^PHP message: //; s/ while reading.*//' | sort | uniq -c | sort -rn | cut -c1-330
