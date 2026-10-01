#!/bin/bash
# Каждый bash-скрипт тестов останавливается сразу, если env.php не собрал настройки
# (нет конфига площадки или tests/local.php), и не работает с пустыми переменными
# или с переменными, оставшимися в окружении от прошлого запуска.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
for s in regression.sh smoke-final.sh smoke-write.sh smoke-log.sh; do
  out=$(cd "$S" && env -u DB_NAME -u DB_USER -u DB_HOST -u MYSQL_PWD -u ENERGINE_WEB -u ENERGINE_LOCAL -u ENERGINE_BASE \
        BASE=https://stale.invalid B=https://stale.invalid ENERGINE_CONFIG=/nonexistent \
        timeout 60 bash "$S/$s" 2>&1)
  rc=$?
  extra=$(echo "$out" | grep -v '^env.php: нет файла')
  if [ $rc -eq 0 ] || [ -n "$extra" ]; then
    echo "FAIL $s: exit=$rc, лишний вывод: $(echo "$extra" | head -2 | tr '\n' ' ')"
    fail=1
  fi
done
[ $fail = 0 ] && echo "== env-guard: ok"
exit $fail
