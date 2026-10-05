#!/usr/bin/env bash
# Clean-install check for Energine 2.13. Installs strictly as INSTALL.md describes — a fresh clone of the
# committed tree, a copy of starter/, composer, a database, SQL import, config, setup, your administrator,
# the site address — into a temporary directory with a temporary MariaDB (127.0.0.1, random port), serves
# htdocs with PHP's built-in server and checks the site. Nothing outside the temporary directory changes.
# Usage (as root): tools/install-check.sh empty|demo
#   RUN_AS — user that owns the installation and runs PHP (default web93); PHP — binary (default php8.5).
set -uo pipefail
VARIANT=${1:?usage: install-check.sh empty|demo}
case "$VARIANT" in empty|demo) ;; *) echo "usage: install-check.sh empty|demo" >&2; exit 2;; esac
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RUN_AS=${RUN_AS:-web93}
PHP=${PHP:-php8.5}
FAILS=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; FAILS=$((FAILS + 1)); }
die() { echo "FAIL $*"; echo "== install-check $VARIANT failures: $((FAILS + 1))"; exit 1; }

T=$(mktemp -d /tmp/e213.XXXX)
chmod 755 "$T"
WEBPORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
DBPORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
cleanup() {
  # KEEP=1 leaves the installation, its database and the web server running, for debugging
  if [ -n "${KEEP:-}" ]; then echo "kept: $T  web http://127.0.0.1:$WEBPORT/  db socket $T/db/s  (stop: pkill -f -- \"-S 127.0.0.1:$WEBPORT \"; kill \$(cat $T/db/pid); rm -rf $T)"; return; fi
  pkill -f -- "-S 127.0.0.1:$WEBPORT " 2>/dev/null
  [ -s "$T/db/pid" ] && kill "$(cat "$T/db/pid")" 2>/dev/null
  sleep 1
  rm -rf "$T"
}
trap cleanup EXIT
randpw() { head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20; }
DBPW=$(randpw)
ADMIN_EMAIL=admin@example.com
ADMIN_PW=$(randpw)
printf '%s' "$ADMIN_PW" > "$T/admin.pw"; chmod 600 "$T/admin.pw"
E="$T/energine"; P="$T/site"; S="$P/sql"

# 1. Get the code — the core and a copy of the starter as your project
install -d -o "$RUN_AS" "$E" && runuser -u "$RUN_AS" -- git clone -q --depth 1 "file://$REPO" "$E" || die "1. clone"
cp -a "$E/starter" "$P"
chown -R "$RUN_AS:" "$E" "$P"
ok "1. core clone and project copy"

# 2. Install PHP dependencies
( cd "$P" && runuser -u "$RUN_AS" -- env HOME="$T" COMPOSER_HOME="$T/.composer" \
    composer install --no-dev --no-interaction --no-progress --quiet ) > "$T/composer.log" 2>&1 \
  || { tail -5 "$T/composer.log"; die "2. composer install"; }
ok "2. composer install --no-dev"

# 3. Create the database and its user (here: a temporary MariaDB instance)
mkdir -p "$T/db"
mariadb-install-db --no-defaults --user=root --datadir="$T/db/data" --auth-root-authentication-method=socket \
  --skip-test-db > "$T/db/install.log" 2>&1 || die "3. mariadb-install-db"
mariadbd --no-defaults --user=root --datadir="$T/db/data" --socket="$T/db/s" --pid-file="$T/db/pid" \
  --port="$DBPORT" --bind-address=127.0.0.1 --log-error="$T/db/error.log" &
ROOTSQL() { mariadb --no-defaults --socket="$T/db/s" -u root "$@"; }
for _ in $(seq 150); do ROOTSQL -e 'SELECT 1' > /dev/null 2>&1 && break; sleep 0.2; done
ROOTSQL -e 'SELECT 1' > /dev/null 2>&1 || die "3. temporary MariaDB did not start"
ROOTSQL <<SQL || die "3. database and user"
CREATE DATABASE energine CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'energine'@'127.0.0.1' IDENTIFIED BY '$DBPW';
GRANT ALL PRIVILEGES ON energine.* TO 'energine'@'127.0.0.1';
SQL
# client options in a file: the password never appears in the process list
cat > "$T/db/client.cnf" <<CNF
[client]
host=127.0.0.1
port=$DBPORT
user=energine
password=$DBPW
default-character-set=utf8
CNF
chmod 600 "$T/db/client.cnf"
DB() { mariadb --defaults-extra-file="$T/db/client.cnf" energine "$@"; }
ok "3. database energine and user energine"

# 4. Import the SQL files in this order (the order is in INSTALL.md)
if [ "$VARIANT" = empty ]; then
  FILES="starter.structure.sql starter.routines.sql starter.data.empty.sql starter.structure.fixes.sql modules.structure.sql starter.data.admin.sql starter.data.sitemap.sql modules.data.sql"
else
  FILES="starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo/demo.content.sql"
fi
for f in $FILES; do
  DB < "$S/$f" > "$T/import.log" 2>&1 || { tail -3 "$T/import.log"; die "4. import $f"; }
done
ok "4. SQL import ($VARIANT)"

# 5. Write the configuration (placeholders of configs/system.config.default.php)
CFG="$P/htdocs/system.config.php"
CORE="$E" DBPORT="$DBPORT" DBPW="$DBPW" "$PHP" -r '
$c = file_get_contents($argv[1]);
$c = strtr($c, [
    "\x27PATH TO CORE\x27" => var_export(getenv("CORE"), true),
    "\x27DB HOST NAME\x27" => "\x27127.0.0.1\x27",
    "\x27port\x27 => \x273306\x27" => "\x27port\x27 => \x27" . getenv("DBPORT") . "\x27",
    "\x27DB NAME\x27" => "\x27energine\x27",
    "\x27DB LOGIN\x27" => "\x27energine\x27",
    "\x27DB PASSWORD\x27" => var_export(getenv("DBPW"), true),
    "\x27PROJECT DOMAIN NAME\x27" => "\x27127.0.0.1\x27",
    "\x27debug\x27 => 1" => "\x27debug\x27 => 0",
]);
file_put_contents($argv[2], $c);' "$P/configs/system.config.default.php" "$CFG" || die "5. config"
chown "$RUN_AS:" "$CFG"; chmod 640 "$CFG"
grep -q "'debug' => 0" "$CFG" && ! grep -q "PATH TO CORE\|DB PASSWORD\|PROJECT DOMAIN NAME" "$CFG" \
  && ok "5. htdocs/system.config.php (debug 0)" || bad "5. config placeholders left"

# 6. Run setup
( cd "$P/htdocs" && runuser -u "$RUN_AS" -- "$PHP" index.php setup install ) > "$T/setup.log" 2>&1 \
  || { tail -10 "$T/setup.log"; die "6. setup install"; }
ok "6. setup install"
# a failed setup says so through its exit status (scripts that follow INSTALL.md rely on it)
( cd "$P/htdocs" && runuser -u "$RUN_AS" -- "$PHP" index.php setup noSuchAction ) > "$T/setup-error.log" 2>&1 \
  && bad "setup exits 0 when it fails" || ok "setup exits non-zero when it fails"

# 7. Your administrator (the starter's account cannot sign in until this step)
HASH=$(ADMIN_PW="$ADMIN_PW" "$PHP" -r 'echo password_hash(getenv("ADMIN_PW"), PASSWORD_DEFAULT);')
DB <<SQL || die "7. administrator"
UPDATE user_users SET u_name = '$ADMIN_EMAIL', u_fullname = 'Administrator', u_password = '$HASH'
WHERE u_name = 'demo@energine.org';
SQL
[ "$(DB -N -e "SELECT COUNT(*) FROM user_users WHERE u_name = '$ADMIN_EMAIL'")" = 1 ] \
  && ok "7. administrator $ADMIN_EMAIL" || bad "7. administrator row not found"

# 8. The address the site answers on (here: the built-in server's port)
DB <<SQL || die "8. site address"
INSERT INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES ('http', $WEBPORT, '127.0.0.1', '/');
INSERT INTO share_domain2site (domain_id, site_id) VALUES (LAST_INSERT_ID(), 1);
SQL
ok "8. share_domains http://127.0.0.1:$WEBPORT/"

# 9. Demo images (only for the demo variant)
if [ "$VARIANT" = demo ]; then
  mkdir -p "$P/htdocs/uploads/public/demo"
  cp -a "$S/demo/uploads/." "$P/htdocs/uploads/public/demo/" && chown -R "$RUN_AS:" "$P/htdocs/uploads" \
    && ok "9. demo images" || bad "9. demo images"
fi

# 10. Web server (here: PHP's built-in server, running as the site's user with display_errors off)
touch "$T/php-error.log"; chown "$RUN_AS:" "$T/php-error.log"
runuser -u "$RUN_AS" -- "$PHP" -d log_errors=1 -d error_log="$T/php-error.log" -d display_errors=0 \
  -S "127.0.0.1:$WEBPORT" -t "$P/htdocs" "$E/tools/php-server-router.php" > "$T/web.log" 2>&1 &
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$WEBPORT/" && break; sleep 0.2; done
B="http://127.0.0.1:$WEBPORT"
get() { curl -s -o "$T/body" -w '%{http_code}' -b "$T/jar" -c "$T/jar" "$B$1"; }
clean() { ! grep -qiE 'Fatal error|Warning:|Notice:|Deprecated:|Uncaught' "$T/body"; }
# a page is a whole HTML document: a bootstrap failure answers 200 text/plain, an escaped exception an empty 200
html() { grep -qi '</html>' "$T/body"; }

# pages
[ "$(get /)" = 200 ] && html && clean && ok "home page" || bad "home page: $(head -c 200 "$T/body" | tr '\n' ' ')"
[ "$(get /login/)" = 200 ] && html && clean && ok "login page" || bad "login page"
[ "$(get /no-such-page-$$/)" = 404 ] && ok "404 for an unknown address" || bad "404 for an unknown address"
[ "$(get /google-sitemap/)" = 200 ] && grep -q '<sitemapindex' "$T/body" \
  && [ "$(get /google-sitemap/map)" = 200 ] && grep -q '<urlset' "$T/body" && ok "google sitemap (index and map)" || bad "google sitemap"
[ "$(get /templates/content/main.content.xml)" = 403 ] && ok "page XML not served" || bad "page XML is served"

# sign in: the administrator from step 7
code=$(curl -s -o /dev/null -w '%{http_code}' -b "$T/jar" -c "$T/jar" -e "$B/login/" -d 'user[login]=1' \
  --data-urlencode "user[username]=$ADMIN_EMAIL" --data-urlencode "user[password]@$T/admin.pw" "$B/auth.php")
[ "$(get /admin/)" = 200 ] && html && clean && grep -qi 'logout' "$T/body" \
  && ok "administrator signs in ($code), /admin/ opens" || bad "administrator sign-in (auth $code, admin $(get /admin/))"
[ "$(get /admin/structure/)" = 200 ] && html && clean && grep -q 'id="treeContainer"' "$T/body" \
  && ok "the sections editor opens" || bad "the sections editor (/admin/structure/)"

# nobody else signs in: no other usable password in the database, and the login form turns the others away
# (the starter's login included) — with an empty and with a random password
[ "$(DB -N -e "SELECT COUNT(*) FROM user_users WHERE u_name <> '$ADMIN_EMAIL' AND u_password LIKE '\$%'")" = 0 ] \
  && ok "only the administrator has a usable password" || bad "other users have usable passwords"
f0=$FAILS
DB -N -e "SELECT u_name FROM user_users WHERE u_name <> '$ADMIN_EMAIL' UNION SELECT 'demo@energine.org'" > "$T/others"
while read -r u; do
  for pw in '' "$(randpw)"; do
    : > "$T/jar-other"
    curl -s -o /dev/null -b "$T/jar-other" -c "$T/jar-other" -e "$B/login/" -d 'user[login]=1' \
      --data-urlencode "user[username]=$u" --data-urlencode "user[password]=$pw" "$B/auth.php"
    curl -s -o "$T/body" -b "$T/jar-other" "$B/"
    grep -qi 'logout' "$T/body" && bad "$u signs in"
  done
done < "$T/others"
[ "$FAILS" = "$f0" ] && ok "the login form turns away $(wc -l < "$T/others") other logins"

# every top-level page and every administration page opens for the administrator
f0=$FAILS
DB -N -e "SELECT CONCAT('/', s.smap_segment, '/') FROM share_sitemap s JOIN share_sitemap r ON s.smap_pid = r.smap_id
  WHERE r.smap_pid IS NULL AND s.smap_segment NOT IN ('admin', 'google-sitemap', 'robots.txt')
  UNION ALL
  SELECT CONCAT('/admin/', s.smap_segment, '/') FROM share_sitemap s JOIN share_sitemap a ON s.smap_pid = a.smap_id
  JOIN share_sitemap r ON a.smap_pid = r.smap_id WHERE r.smap_pid IS NULL AND a.smap_segment = 'admin'" > "$T/pages"
while read -r u; do
  c=$(get "$u")
  [ "$c" = 200 ] && html && clean || bad "$u answers $c to the administrator$(clean || echo ' with a PHP error')"
  grep -q 'demo@energine.org' "$T/body" && bad "$u shows the starter login"
done < "$T/pages"
[ "$FAILS" = "$f0" ] && ok "$(wc -l < "$T/pages") pages open for the administrator"

# every top-level page a guest may read opens for a guest
f0=$FAILS; : > "$T/jar-guest"
DB -N -e "SELECT DISTINCT s.smap_segment FROM share_sitemap s JOIN share_sitemap r ON s.smap_pid = r.smap_id
  JOIN share_access_level a ON a.smap_id = s.smap_id AND a.right_id > 0
  JOIN user_groups g ON g.group_id = a.group_id AND g.group_default = 1
  WHERE r.smap_pid IS NULL AND s.smap_segment NOT IN ('admin', 'google-sitemap', 'robots.txt')" > "$T/segments"
while read -r seg; do
  c=$(curl -s -o "$T/body" -w '%{http_code}' -b "$T/jar-guest" -c "$T/jar-guest" "$B/$seg/")
  [ "$c" = 200 ] && html && clean || bad "/$seg/ answers $c to a guest$(clean || echo ' with a PHP error')"
done < "$T/segments"
[ "$FAILS" = "$f0" ] && ok "$(wc -l < "$T/segments") pages open for a guest"

# setup linker again (after updating or moving the core): it rebuilds htdocs/images, scripts, stylesheets and
# templates — the site's own files come from site/modules/*/, anything put straight into those folders is removed
printf 'site file' | runuser -u "$RUN_AS" -- tee "$P/site/modules/main/images/install-check.txt" > /dev/null
printf 'stray file' | runuser -u "$RUN_AS" -- tee "$P/htdocs/images/install-check.txt" > /dev/null
( cd "$P/htdocs" && runuser -u "$RUN_AS" -- "$PHP" index.php setup linker ) > "$T/linker.log" 2>&1 \
  && [ "$(get /)" = 200 ] && html && ok "setup linker again" || bad "setup linker again"
[ "$(get /images/main/install-check.txt)" = 200 ] && grep -q 'site file' "$T/body" \
  && [ ! -e "$P/htdocs/images/install-check.txt" ] \
  && ok "setup links site/modules/main/images/ into htdocs/images/main/ and clears htdocs/images/" \
  || bad "site files after setup linker"

# PHP error log
[ ! -s "$T/php-error.log" ] && ok "PHP error log is empty" || bad "PHP error log: $(tail -3 "$T/php-error.log" | tr '\n' ' ')"

# INSTALL.md describes what this check did
for needle in 'composer install --no-dev' 'index.php setup install' 'index.php setup linker' 'share_domains' \
              'password_hash' 'php_admin_flag[display_errors] = off' 'AllowOverride All' 'site/modules/main/images' \
              $FILES; do
  grep -qF -- "$needle" "$E/INSTALL.md" 2>/dev/null || bad "INSTALL.md does not mention: $needle"
done

# published files are clean (git runs as root in a clone owned by RUN_AS: allow it explicitly, and a git
# error must fail the check instead of reading as "nothing found")
cd "$E"
G() { git -c safe.directory="$E" -C "$E" "$@"; }
leak=$(G grep -lI -e 'new\.energine\.org' -e 'pavka\.eggmen' -e '/var/www/clients' -- . ':!tools/install-check.sh'); rc=$?
if [ $rc -gt 1 ]; then bad "git grep failed ($rc)"
elif [ -z "$leak" ]; then ok "no demo-server names or paths"
else bad "demo-server names or paths in: $(echo $leak)"; fi
files=$(G ls-files) || bad "git ls-files failed"
conf=$(echo "$files" | grep -E 'system\.config\.[^/]*\.php$' | grep -v 'system\.config\.default\.php')
[ -z "$conf" ] && ok "only the default config is published" || bad "configs published: $conf"
# hashes in user_users rows (INSERT … VALUES) and in u_password assignments (UPDATE … SET u_password = …)
hashes=$( { awk '/INSERT INTO `user_users`|INSERT IGNORE INTO `user_users`/{f=1} f{print FILENAME": "$0} /;[[:space:]]*$/{f=0}' starter/sql/*.sql starter/sql/demo/*.sql
            grep -H 'u_password' starter/sql/*.sql starter/sql/demo/*.sql; } 2>/dev/null \
  | grep -E "'[0-9a-f]{40}'|\\\$2[aby]\\\$" | cut -d: -f1 | sort -u)
[ -z "$hashes" ] && ok "no password hashes in user_users data" || bad "password hashes in: $(echo $hashes)"
G grep -qiI -e 'recaptcha' -- starter/configs; rc=$?
[ $rc -eq 1 ] && ok "no reCAPTCHA keys" || bad "reCAPTCHA settings in the starter config (git grep rc=$rc)"
[ ! -e starter/tests ] && ok "no demo-server tests" || bad "starter/tests is published"
stale=$(G grep -lI -i -e 'svn checkout' -e 'googlecode' -e 'ISPConfig' -e 'private/project' -- . ':!tools/install-check.sh'); rc=$?
if [ $rc -gt 1 ]; then bad "git grep failed ($rc)"
elif [ -z "$stale" ]; then ok "no stale install instructions or demo-stand notes"
else bad "stale install instructions or demo-stand notes in: $(echo $stale)"; fi
# mariadb-dump's sandbox line stops MariaDB clients older than 10.11.8 / 10.6.18 ("Unknown command '\-'")
sandbox=$(G grep -lI -F '/*M!999999' -- starter/sql); rc=$?
if [ $rc -gt 1 ]; then bad "git grep failed ($rc)"
elif [ -z "$sandbox" ]; then ok "no mariadb-dump sandbox line in the SQL"
else bad "mariadb-dump sandbox line in: $(echo $sandbox)"; fi
cd /

echo "== install-check $VARIANT failures: $FAILS"
[ "$FAILS" -eq 0 ]
