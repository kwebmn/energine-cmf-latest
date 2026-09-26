#!/bin/bash
# Write-path smoke test: every created record is deleted again. Prints OK/FAIL per step.
SCR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
envsh=$(php8.5 "$SCR/env.php" --shell) || exit 1; eval "$envsh"
A=$B/admin
J=$SCR/smoke-write-cookies.txt
R=$SCR/smoke-write.json
q() { mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }
ADMIN_ID=$(q "SELECT u_id FROM user_users WHERE u_name='$ADMIN_EMAIL'")
# добавление страницы сдвигает smap_order_num всему сайту (так устроено ядро): порядок запоминается
# и возвращается при выходе, чтобы и одиночный прогон не оставлял сдвига
ORDER=$(mktemp)
q "SELECT CONCAT('UPDATE share_sitemap SET smap_order_num=', smap_order_num, ' WHERE smap_id=', smap_id, ';') FROM share_sitemap" > $ORDER
trap 'mysql --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < $ORDER && rm -f $ORDER' EXIT
fail=0
ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1: $(head -c 300 $R | tr '\n' ' ')"; fail=$((fail+1)); }
# ответ прошлого запроса стирается: запрос, который не дошёл, не должен засчитываться по нему
post() { : > $R; curl -sS -c $J -b $J -X POST -H 'X-Request: JSON' -H "X-CSRF-Token: $TOK" -o $R "$@"; }
# токен страницы (Csrf): у гостя — для входа, после входа — для всех POST админки
tok() { curl -sS -c $J -b $J "$1" | sed -n 's/.*<meta name="csrf-token" content="\([0-9a-f]*\)".*/\1/p' | head -1; }
isok() { php8.5 -r '$d=json_decode(file_get_contents($argv[1]),true); exit(is_array($d) && !empty($d["result"]) ? 0 : 1);' $R; }

rm -f $J
TOK=$(tok $B/login/)
curl -sS -c $J -b $J -o /dev/null -e "$B/login/" --data-urlencode "csrf_token=$TOK" --data-urlencode 'user[login]=1' \
  --data-urlencode "user[username]=$ADMIN_EMAIL" --data-urlencode "user[password]=$ADMIN_PASSWORD" $B/auth.php
grep -q NRGNSID $J && ok "login" || { echo "FAIL login"; exit 1; }
TOK=$(tok $B/)

# --- page: add, edit with SET column, delete
S=$A/structure/single/divEditor/
pagefields() {
  echo --data-urlencode "share_sitemap[smap_pid]=80" --data-urlencode "share_sitemap[site_id]=1" \
    --data-urlencode "share_sitemap[smap_layout]=default.layout.xml" --data-urlencode "share_sitemap[smap_content]=textblock.content.xml" \
    --data-urlencode "share_sitemap[smap_segment]=claude-test" --data-urlencode "share_sitemap[smap_redirect_url]=" \
    --data-urlencode "share_sitemap[smap_in_menu]=1" \
    --data-urlencode "right_id[1]=3" --data-urlencode "right_id[3]=1" --data-urlencode "right_id[4]=1"
}
tr_fields() { for l in 1 2; do for f in smap_title smap_html_title smap_meta_keywords smap_meta_description smap_description_rtf; do
  printf -- '--data-urlencode\nshare_sitemap_translation[%s][%s]=\n' $l $f; done; done; }
mapfile -t TR < <(tr_fields)
post "${S}save" --data-urlencode "componentAction=add" --data-urlencode "share_sitemap[smap_id]=" $(pagefields) "${TR[@]}" \
  --data-urlencode "share_sitemap_translation[1][smap_name]=Тест установки" --data-urlencode "share_sitemap_translation[2][smap_name]=Тест"
ID=$(q "SELECT smap_id FROM share_sitemap WHERE smap_segment='claude-test'")
isok && [ -n "$ID" ] && ok "page add ($ID)" || bad "page add"
[ "$(curl -sS -o /dev/null -w '%{http_code}' $B/claude-test/)" = 200 ] && ok "page view" || bad "page view"
if [ -n "$ID" ]; then
  post "${S}save" --data-urlencode "componentAction=edit" --data-urlencode "share_sitemap[smap_id]=$ID" $(pagefields) "${TR[@]}" \
    --data-urlencode "share_sitemap[smap_meta_robots][]=NOINDEX" --data-urlencode "share_sitemap[smap_meta_robots][]=NOFOLLOW" \
    --data-urlencode "share_sitemap_translation[1][smap_name]=Тест установки (ред.)" --data-urlencode "share_sitemap_translation[2][smap_name]=Тест"
  isok && [ "$(q "SELECT smap_meta_robots FROM share_sitemap WHERE smap_id=$ID")" = "NOINDEX,NOFOLLOW" ] && ok "page edit" || bad "page edit"
  curl -sS $B/claude-test/ | grep -q '<meta name="robots" content="NOINDEX,NOFOLLOW">' && ok "page meta robots" || bad "page meta robots"
  post "${S}${ID}/delete/"
  isok && [ "$(q "SELECT COUNT(*) FROM share_sitemap WHERE smap_id=$ID")" = 0 ] && ok "page delete" || bad "page delete"
fi

# --- news: add, view, delete
N=$A/news-editor/single/newsRepo/
# новости, оставшиеся от прерванных прогонов, мешают найти свою
stale=$(q "SELECT COUNT(*) FROM apps_news WHERE news_segment='claude-test-news'")
[ "$stale" != 0 ] && { q "DELETE FROM apps_news WHERE news_segment='claude-test-news'"; echo "note removed stale claude-test-news: $stale"; }
post "${N}save" --data-urlencode "componentAction=add" --data-urlencode "apps_news[news_id]=" --data-urlencode "apps_news[smap_id]=3594" \
  --data-urlencode "apps_news[news_date]=2026-09-13 17:00:00" --data-urlencode "apps_news[news_segment]=claude-test-news" \
  --data-urlencode "apps_news[news_is_active]=1" \
  --data-urlencode "apps_news_translation[1][news_title]=Тестовая новость" --data-urlencode "apps_news_translation[1][news_announce_rtf]=<p>анонс</p>" \
  --data-urlencode "apps_news_translation[1][news_text_rtf]=<p>текст</p>" --data-urlencode "apps_news_translation[2][news_title]=Тест" \
  --data-urlencode "apps_news_translation[2][news_announce_rtf]=" --data-urlencode "apps_news_translation[2][news_text_rtf]="
NID=$(php8.5 -r '$d=json_decode(file_get_contents($argv[1]),true); echo is_array($d) && ($d["mode"] ?? "") === "insert" ? (int)$d["data"] : "";' $R)
isok && [ -n "$NID" ] && ok "news add ($NID)" || bad "news add"
if [ -n "$NID" ]; then
  [ "$(curl -sS -o /dev/null -w '%{http_code}' $B/news/${NID}--claude-test-news/)" = 200 ] && ok "news view" || bad "news view"
  post "${N}${NID}/delete/"; isok && ok "news delete" || bad "news delete"
fi

# --- translation: add, delete
T=$A/translations/single/transEditor/
post "${T}save" --data-urlencode "componentAction=add" --data-urlencode "share_lang_tags[ltag_id]=" --data-urlencode "share_lang_tags[ltag_name]=TXT_CLAUDE_TEST" \
  --data-urlencode "share_lang_tags_translation[1][ltag_value_rtf]=Тест" --data-urlencode "share_lang_tags_translation[2][ltag_value_rtf]=Тест"
TID=$(q "SELECT ltag_id FROM share_lang_tags WHERE ltag_name='TXT_CLAUDE_TEST'")
isok && [ -n "$TID" ] && ok "translation add" || bad "translation add"
[ -n "$TID" ] && { post "${T}${TID}/delete/"; isok && ok "translation delete" || bad "translation delete"; }

# --- user profile: filled, then empty values, then restore
U=$A/users/single/userEditor/save
usave() { post "$U" --data-urlencode "componentAction=edit" --data-urlencode "user_users[u_id]=$ADMIN_ID" --data-urlencode "user_users[u_is_active]=1" \
  --data-urlencode "user_users[u_name]=$ADMIN_EMAIL" --data-urlencode "user_users[u_password]=" --data-urlencode "user_users[u_fullname]=Admin" \
  --data-urlencode "user_users[u_phone]=123-45-67" --data-urlencode "user_users[u_country]=" --data-urlencode "user_users[u_city]=" \
  --data-urlencode "group_id[]=1" "$@"; }
usave --data-urlencode "user_users[u_person_name]=Тест" --data-urlencode "user_users[u_bdate]=1990-05-01" --data-urlencode "user_users[u_sex]=M" \
  --data-urlencode "user_users[u_address]=ул. Тестовая, 1" --data-urlencode "user_users[u_gooid]=" --data-urlencode "user_users[u_avatar_img]="
isok && [ "$(q "SELECT CONCAT_WS('|', u_person_name, u_bdate, u_sex) FROM user_users WHERE u_id=$ADMIN_ID")" = "Тест|1990-05-01|M" ] && ok "user save filled" || bad "user save filled"
usave --data-urlencode "user_users[u_person_name]=" --data-urlencode "user_users[u_bdate]=" --data-urlencode "user_users[u_sex]=" \
  --data-urlencode "user_users[u_address]=" --data-urlencode "user_users[u_gooid]=" --data-urlencode "user_users[u_avatar_img]="
isok && [ "$(q "SELECT COUNT(*) FROM user_users WHERE u_id=$ADMIN_ID AND u_person_name IS NULL AND u_bdate IS NULL AND u_sex IS NULL")" = 1 ] && ok "user save empty" || bad "user save empty"
q "UPDATE user_users SET u_phone='123-45-67' WHERE u_id=$ADMIN_ID"
H=$(q "SELECT u_password FROM user_users WHERE u_id=$ADMIN_ID")
php8.5 -r 'exit(password_verify(getenv("ADMIN_PASSWORD"), $argv[1]) ? 0 : 1);' "$H" && ok "password intact" || bad "password intact"

# --- file repository: dir, upload into it, breadcrumbs, delete
F=$A/users/single/adminPanel/file-library/
php8.5 -r '$im=imagecreatetruecolor(120,80); imagefill($im,0,0,imagecolorallocate($im,30,120,200)); imagepng($im,$argv[1]);' $SCR/claude-test.png
post "${F}save-dir" --data-urlencode "componentAction=addDir" --data-urlencode "share_uploads[upl_id]=" --data-urlencode "share_uploads[upl_pid]=1" \
  --data-urlencode "share_uploads[upl_title]=claude-test-dir"
DID=$(q "SELECT upl_id FROM share_uploads WHERE upl_title='claude-test-dir'")
isok && [ -n "$DID" ] && ok "dir create" || bad "dir create"
curl -sS -c $J -b $J -X POST -H 'X-Request: JSON' -H "X-CSRF-Token: $TOK" -F "key=file" -F "file=@$SCR/claude-test.png;type=image/png" -o $R "${F}upload-temp/"
isok && ok "upload temp" || bad "upload temp"
post "${F}save" --data-urlencode "componentAction=add" --data-urlencode "share_uploads[upl_id]=" --data-urlencode "share_uploads[upl_pid]=$DID" \
  --data-urlencode "share_uploads[upl_path]=uploads/temp/claude-test.png" --data-urlencode "share_uploads[upl_title]=claude-test" \
  --data-urlencode "share_uploads[upl_name]=claude-test" --data-urlencode "share_uploads[upl_filename]=claude-test.png"
isok && ok "file save" || bad "file save"
FPATH=$(q "SELECT upl_path FROM share_uploads WHERE upl_pid='$DID' LIMIT 1")
[ -n "$FPATH" ] && [ "$(curl -sS -o /dev/null -w '%{http_code}' "$B/resizer/w40-h30/$FPATH")" = 200 ] && ok "file via resizer" || bad "file via resizer"
# видеофайл — обычный файл: без плеера и перекодировки, тип unknown (раньше video)
MP4=$(mktemp); printf '\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom' > $MP4
curl -sS -c $J -b $J -X POST -H 'X-Request: JSON' -H "X-CSRF-Token: $TOK" -F "key=file" -F "file=@$MP4;filename=claude-test.mp4;type=video/mp4" -o $R "${F}upload-temp/"
isok && ok "upload temp mp4" || bad "upload temp mp4"
rm -f $MP4
post "${F}save" --data-urlencode "componentAction=add" --data-urlencode "share_uploads[upl_id]=" --data-urlencode "share_uploads[upl_pid]=$DID" \
  --data-urlencode "share_uploads[upl_path]=uploads/temp/claude-test.mp4" --data-urlencode "share_uploads[upl_title]=claude-test-mp4" \
  --data-urlencode "share_uploads[upl_name]=claude-test-mp4" --data-urlencode "share_uploads[upl_filename]=claude-test.mp4"
isok && ok "mp4 save" || bad "mp4 save"
MID=$(q "SELECT upl_id FROM share_uploads WHERE upl_title='claude-test-mp4'")
[ "$(q "SELECT CONCAT(upl_mime_type, ' ', upl_internal_type) FROM share_uploads WHERE upl_title='claude-test-mp4'")" = "video/mp4 unknown" ] \
  && ok "mp4 stored as a plain file" || { echo "FAIL mp4 stored as a plain file: $(q "SELECT CONCAT(upl_mime_type, ' ', upl_internal_type) FROM share_uploads WHERE upl_title='claude-test-mp4'")"; fail=$((fail+1)); }
[ -n "$MID" ] && { post "${F}${MID}/delete/"; isok && ok "mp4 delete" || bad "mp4 delete"; }
rm -f $WEB/uploads/temp/claude-test.mp4
post "${F}${DID}/get-data/"
php8.5 -r '$d=json_decode(file_get_contents($argv[1]),true); exit(isset($d["breadcrumbs"]) && count($d["breadcrumbs"]) == 2 ? 0 : 1);' $R && ok "dir listing breadcrumbs" || bad "dir listing breadcrumbs"
FID=$(q "SELECT upl_id FROM share_uploads WHERE upl_pid='$DID' LIMIT 1")
[ -n "$FID" ] && { post "${F}${FID}/delete/"; isok && ok "file delete" || bad "file delete"; }
[ -n "$DID" ] && { post "${F}${DID}/delete/"; isok && ok "dir delete" || bad "dir delete"; }
rm -f $WEB/uploads/temp/claude-test.png
[ "$(q "SELECT COUNT(*) FROM share_uploads WHERE upl_title LIKE 'claude-test%'")" = 0 ] && [ ! -e $WEB/uploads/public/claude-test-dir ] && ok "repo cleanup" || bad "repo cleanup"


# --- logout
curl -sS -c $J -b $J -o /dev/null -e "$B/" --data-urlencode "csrf_token=$TOK" --data-urlencode 'user[logout]=1' $B/auth.php
[ "$(curl -sS -c $J -b $J -o /dev/null -w '%{http_code}' $A/users/)" = 404 ] && ok "logout" || bad "logout"

echo "== write failures: $fail"
