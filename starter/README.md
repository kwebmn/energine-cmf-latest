# Energine 2.13 project

This folder is a new Energine project. Copy it out of the core repository and install it as INSTALL.md in the
core repository describes (https://github.com/kwebmn/energine-cmf-latest/blob/master/INSTALL.md).

- `htdocs/` — the web server's document root: `index.php`, your `system.config.php` and `uploads/`. Setup
  rebuilds `images/`, `scripts/`, `stylesheets/` and `templates/` here on every run; do not put files there.
- `site/modules/main/` — your site: components, configuration, templates and transformers, and your own
  images, scripts and stylesheets (setup links them into `htdocs/images/main/` and so on).
- `configs/system.config.default.php` — the configuration template.
- `sql/` — the database for an empty site or for a site with demo content (`sql/demo/`).
- `setup/` — run from `htdocs/`: `php index.php setup install`, `linker`, `scriptMap`.
- `core/modules/` — setup links the core's modules here.
- `cli/` — console commands (newsletters).
- `jambalaya/` — nginx and Apache examples.
