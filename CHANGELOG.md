# Changelog

## 2.13.0 — 2026-10

Energine 2.12 brought to PHP 8.4+ and MariaDB 10.11, with the modules repaired and a starter that installs from
scratch.

### PHP and MariaDB
- PHP 8.4 is the minimum (`Pdo\Mysql`); tested on PHP 8.5.
- Explicit nullable parameters and native return types; removed functions replaced (`create_function()`,
  `each()`, `strftime()`, `PDO::MYSQL_ATTR_*`); runtime warnings and deprecations fixed.
- MariaDB 10.11: results of stored procedure calls, unquoted numeric column defaults, strict SQL mode.

### Security
- Uploads refuse executable files.
- Guests can no longer rewrite anonymous comments.
- The "My orders" page no longer exposes other users' data.
- SQL injection fixed in the shop's producer filter and search.
- HTML e-mails escape visitor values; the unused `eval()` templating is gone.
- Deleting a form no longer drops other forms' tables.
- The profile saves a new password only when it is confirmed.

### Modules
- Repaired: mail (with digests), ads (banners bound to sites and pages), blog, calendar, comments, form builder.
- Shop: admin editors, catalogue, cart and orders, prices in the visitor's currency, filters, search,
  comparison, recently viewed goods, related goods and accessories.
- News: category names and links, similar news, calendar, RSS, tag cloud and filtering by tag, categories
  editor.
- Site: a real 404 page, the Google sitemap that robots.txt points to, tops, section branding, per-page
  banners.

### Starter
- `setup/` restored (install, linker, scriptMap); it runs from the console only.
- SQL for an empty site and for a site with demo content, module tables and data included; no account in it
  has a usable password.
- composer for PHP 8.4+ (symfony/console 7.4); nginx and Apache examples.
- `tools/install-check.sh` installs the release from scratch and checks it.

### Removed
- Sign-in through Facebook, VK, Google and OK; reCAPTCHA; the MoveToFooter behavior of the login form.
- HTMLCap is deprecated.

### Known risks
See [README.md](README.md#known-risks).
