# Energine 2.13

Energine is an open-source content management framework for PHP. A page is assembled from components; each
component returns XML, and XSLT turns the page's XML into HTML. Content and interface texts are multilingual,
access rights are set per section and user group, and the engine comes with modules: news and blogs, shop,
forms and the form builder, mailings, banners, comments, calendar, SEO tools and more.

Energine has been developed since 2006 by Pavel Dubenko and contributors. Version 2.13 brings the 2.12 code
to PHP 8.4+ and MariaDB 10.11, repairs the modules and ships a starter project that installs from scratch
(see [CHANGELOG.md](CHANGELOG.md)).

- **Install:** [INSTALL.md](INSTALL.md) — an empty site, or a site with demo content.
- **Requirements:** PHP 8.4+ (tested on 8.5), MariaDB 10.11+, nginx with PHP-FPM (or Apache 2.4), composer.
- **License:** MIT, see [LICENSE](LICENSE).

## Energine Simple

[Energine Simple](https://github.com/kwebmn/energine-cmf-latest/tree/simple), in the `simple` branch, is a
smaller, reworked line of the engine: the core only (section tree and pages, users, groups and rights,
languages, file repository), one site per install, plain JavaScript instead of MooTools, CSRF protection and
password reset through an e-mail link.

## Known risks

Energine 2.13 is released as it is. Before putting a site online, know these:

- **Password restore** sets a new password at once and e-mails it, without a confirmation link: anyone who
  knows a user's e-mail address can replace that user's password.
- **Public forms have no bot protection:** registration, feedback, form-builder forms and anonymous comments.
- **Admin grids show field values as HTML.** Text sent through public forms can run scripts in an
  administrator's browser. Review submitted content and keep the number of administrators small.
- **Administrator rights are powerful:** the form builder changes the database schema, and the widget editor
  writes template files. Give administrator rights only to people you trust.
- **Deletes in admin grids cascade:** deleting a language or a site removes everything stored for it, for
  good.
- **With `debug` on, mailings are not sent:** each newsletter, with its recipients' addresses, is appended to
  `htdocs/uploads/tmp/mailout.txt`, which the web server serves. Run live sites with `debug` set to 0.
- **Some front-end libraries load from CDNs:** jQuery from ajax.googleapis.com, slick from jsDelivr.

Security work continues in Energine Simple.

## Third-party code

`starter/htdocs/resizer/timthumb.php` (GPL-2.0) and `starter/setup/JSqueeze.php` (Apache-2.0 or GPL-2.0) keep
their own licenses.
