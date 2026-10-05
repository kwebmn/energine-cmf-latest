# Installing Energine 2.13

These steps install an empty site. To see every module at work, install the site with demo content: step 4
has its own SQL list and step 9 adds its images. `tools/install-check.sh` runs exactly these steps on a
temporary server before each release.

## Requirements

- PHP 8.4 or newer (tested on 8.5) with the extensions ctype, dom, fileinfo, gd, json, libxml, mbstring, PDO,
  pdo_mysql, SimpleXML, session and xsl. Optional: tidy (cleans up the HTML of text blocks), zip (archives in
  the file repository), curl (remote images in the resizer), ftp (FTP file repositories), iconv (CSV export
  in encodings other than UTF-8).
- MariaDB 10.11 or newer. MySQL is not supported: the SQL files use MariaDB syntax.
- nginx with PHP-FPM (`starter/jambalaya/.nginx.conf.example`), or Apache 2.4 with mod_rewrite
  (`starter/jambalaya/.htaccess`, not tested).
- composer, git, bash and the mariadb command-line client.

Run every command as the user that owns the site, not as root: setup creates links, folders and files that
PHP must be able to read and change later.

## 1. Get the code

```bash
git clone https://github.com/kwebmn/energine-cmf-latest.git /var/www/energine
cp -a /var/www/energine/starter /var/www/my-site
```

`/var/www/energine` is the core, `/var/www/my-site` is your project. The web server's document root is
`/var/www/my-site/htdocs`; the rest of the project (configuration, SQL, setup, vendor) stays outside it.

## 2. Install PHP dependencies

```bash
cd /var/www/my-site
composer install --no-dev
```

## 3. Create the database and its user

In `mariadb`, as a database administrator:

```sql
CREATE DATABASE energine CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'energine'@'localhost' IDENTIFIED BY 'choose-a-password';
GRANT ALL PRIVILEGES ON energine.* TO 'energine'@'localhost';
```

The user needs every privilege on its database: the SQL creates stored functions and procedures, a view and
temporary tables, and the form builder creates and alters tables at run time. If binary logging is on, set
`log_bin_trust_function_creators = 1`, otherwise the stored functions cannot be imported.

## 4. Import the SQL files

Import the files from `/var/www/my-site/sql`, one at a time and in this order, with

```bash
mariadb --default-character-set=utf8 -u energine -p energine < FILE
```

Empty site:

1. `starter.structure.sql`
2. `starter.routines.sql`
3. `starter.data.empty.sql`
4. `starter.structure.fixes.sql`
5. `modules.structure.sql`
6. `starter.data.admin.sql`
7. `starter.data.sitemap.sql`
8. `modules.data.sql`

Site with demo content (instead of the list above):

1. `starter.structure.sql`
2. `starter.routines.sql`
3. `starter.data.demo.sql`
4. `starter.structure.fixes.sql`
5. `starter.data.demo.fixes.sql`
6. `modules.structure.sql`
7. `modules.data.sql`
8. `demo/demo.content.sql`

## 5. Write the configuration

```bash
cd /var/www/my-site
cp configs/system.config.default.php htdocs/system.config.php
chmod 640 htdocs/system.config.php
```

In `htdocs/system.config.php` replace:

- `'PATH TO CORE'` with the folder you cloned in step 1: `'/var/www/energine'`;
- `'DB HOST NAME'`, `'DB NAME'`, `'DB LOGIN'` and `'DB PASSWORD'` with your database: `'localhost'`,
  `'energine'`, `'energine'` and its password (and `'port' => '3306'` if your server listens on another port);
- `'PROJECT DOMAIN NAME'` with your domain, for example `'example.com'`;
- `'debug' => 1` with `'debug' => 0` on a live site (see Known risks in README.md);
- the addresses in `mail` with yours.

## 6. Run setup

```bash
cd /var/www/my-site/htdocs
php index.php setup install
```

`setup install` checks the database connection, writes your domain into the site's address, links the core's
modules into the project's `core/modules/`, fills `htdocs/` with the modules' images, scripts, stylesheets and
templates, and writes the script map `htdocs/system.jsmap.php`. Setup runs from the console only.

With `debug` off, setup copies the module files into `htdocs/`; with `debug` on, it links them. Run
`php index.php setup linker` again after updating the core, after moving the core or the project, and after
changing `debug`.

## 7. Create your administrator

The starter has one administrator account, `demo@energine.org`, and it has no usable password: nobody can
sign in until you do this step. Give the account your e-mail address and a password (in bash):

```bash
read -rs -p 'Administrator password: ' PW; echo
HASH=$(printf '%s' "$PW" | php -r 'echo password_hash(stream_get_contents(STDIN), PASSWORD_DEFAULT);'); unset PW
mariadb --default-character-set=utf8 -u energine -p energine \
  -e "UPDATE user_users SET u_name = 'you@example.com', u_fullname = 'Administrator', u_password = '$HASH' WHERE u_name = 'demo@energine.org'"
```

The password appears neither in your shell history nor in the process list. Sign in at `/login/`; the
administration is at `/admin/`.

## 8. The address the site answers on

`setup install` stores your domain as the site's address `http://YOUR-DOMAIN/` (port 80), and the site
builds its links from it. If the site answers on HTTPS or on another port, add that address to
`share_domains` and bind it to the site:

```sql
INSERT INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES ('https', 443, 'example.com', '/');
INSERT INTO share_domain2site (domain_id, site_id) VALUES (LAST_INSERT_ID(), 1);
```

An address without its own row still opens the site, but the links on its pages lead to the first address,
`http://YOUR-DOMAIN/`.

## 9. Demo images (demo content only)

```bash
cd /var/www/my-site
mkdir -p htdocs/uploads/public/demo
cp -a sql/demo/uploads/. htdocs/uploads/public/demo/
```

The demo users (`@example.com`) have no usable passwords either; to sign in as one of them, set a password in
the administration (Users).

## Writable folders

- Setup writes to `htdocs/` and to the project's `core/modules/`.
- PHP, as the web server runs it, writes to `htdocs/uploads/` and everything below it (uploaded files) and to
  `site/modules/*/templates/content/` (the widget editor saves page layouts there).

## Updating

```bash
git -C /var/www/energine pull
cd /var/www/my-site/htdocs
php index.php setup linker
php index.php setup scriptMap
```

The project folder is yours: updating the core does not change it. Compare `starter/` of a new release with
your project to take over its changes.

## Known risks

Read the Known risks section of [README.md](README.md#known-risks) before putting a site online.
