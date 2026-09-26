#!/bin/bash
# Distinct PHP messages from nginx error log after line $1 (default: last 3000 lines)
envsh=$(php8.5 "$(dirname "${BASH_SOURCE[0]}")/env.php" --shell) || exit 1; eval "$envsh"
HOST_DIR=$(dirname "$(dirname "$ROOT")")
from=${1:-$(( $(wc -l < $LOG) - 3000 ))}; [ "$from" -lt 0 ] && from=0
tail -n +$((from+1)) $LOG | sed 's/; PHP message: /\n/g; s/PHP message: /\n/g' \
  | grep -oE '^PHP (Deprecated|Warning|Notice|Fatal error|error [0-9]+ thrown as SystemException)[^"]*' \
  | sed -E "s/ while reading.*//; s#$ROOT/core/modules/##; s#$HOST_DIR/##" \
  | sort | uniq -c | sort -rn | cut -c1-260
