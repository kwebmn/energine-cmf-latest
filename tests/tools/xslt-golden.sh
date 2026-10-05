#!/bin/bash
# Сверка вывода шаблонов XSLT «до/после»: bash tests/tools/xslt-golden.sh capture DIR | compare DIR REV (см. xslt-golden.php)
exec php8.5 "$(dirname "${BASH_SOURCE[0]}")/xslt-golden.php" "$@"
