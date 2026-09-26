#!/bin/bash
# Самотест хука pre-commit и .githooks/secret-scan.php во временном репозитории
# с поддельным паролем. Настоящие конфиги и пароли не используются.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1"; fail=1; }

git init -q "$T/repo"
cd "$T/repo" || exit 2
git config user.name selftest && git config user.email selftest@localhost
cp -a "$R/.githooks" .githooks
git config core.hooksPath .githooks
echo '<?php return ["database" => ["password" => "FakeSecret-12345"]];' > "$T/fake.config.php"
echo '<?php return ["database" => ["password" => ' > "$T/broken.config.php"
export ENERGINE_CONFIG="$T/fake.config.php"

# PATH без php8.5 (есть только php) и PATH совсем без PHP
mkdir -p "$T/bin-php" "$T/bin-nophp"
ln -s "$(command -v git)" "$T/bin-php/git"; ln -s "$(command -v php8.5)" "$T/bin-php/php"
ln -s "$(command -v git)" "$T/bin-nophp/git"

commit() { # label expected_exit expected_message [env...]
  local label=$1 want=$2 msg=$3; shift 3
  local out rc
  out=$(env "$@" git commit -qm "$label" 2>&1); rc=$?
  if [ $rc -eq "$want" ] && { [ -z "$msg" ] || grep -qF -- "$msg" <<<"$out"; }; then ok "$label"
  else bad "$label: exit=$rc, вывод: $(tr '\n' ' ' <<<"$out" | cut -c1-160)"; fi
  git reset -q 2>/dev/null
}

# 1. кириллическое имя файла с паролем — коммит отклонён как найденный пароль
printf 'x FakeSecret-12345 y\n' > "тест.txt"; git add "тест.txt"
commit "кириллическое имя с паролем" 1 "пароль из локального конфига"
rm -f "тест.txt"

# 2. пустой файл — не ошибка скана, коммит проходит
: > empty.txt; git add empty.txt
commit "пустой файл" 0 ""

# 3. сломанный конфиг — честное сообщение об ошибке проверки, а не «найден пароль»
echo two > two.txt; git add two.txt
commit "ошибка скана" 1 "проверка паролей не выполнилась" ENERGINE_CONFIG="$T/broken.config.php"
grep -qF "пароль из локального конфига" <<<"$(ENERGINE_CONFIG="$T/broken.config.php" git commit -qm x 2>&1)" \
  && bad "ошибка скана выдана за найденный пароль" || ok "ошибка скана не выдаётся за найденный пароль"
git reset -q

# 4. нет php8.5, но есть php — хук работает
echo three > three.txt; git add three.txt
commit "без php8.5" 0 "" PATH="$T/bin-php"

# 5. PHP нет совсем — предупреждение, коммит не блокируется
echo four > four.txt; git add four.txt
commit "без PHP" 0 "PHP не найден" PATH="$T/bin-nophp"

[ $fail = 0 ] && echo "== hook-selftest: ok"
exit $fail
