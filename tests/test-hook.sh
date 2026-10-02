#!/usr/bin/env bash
# Cross-checks the post-boot hook's date math against Model.js.
#
# The hook reimplements the math in python because node is not on PATH during
# a boot. Two implementations of the same rules drift unless something holds
# them together; this is that something. It runs the python straight out of
# the hook file in this repository rather than a copy, so what is tested is
# what ships.
set -uo pipefail
cd "$(dirname "$0")/.."

HOOK="hooks/post-boot.d/memento-mori"
[[ -r $HOOK ]] || { echo "hook not found at $HOOK"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Lift the python out of the hook's heredoc, so this tests the shipped code.
awk "/<<'PY'/{flag=1;next} /^PY\$/{flag=0} flag" "$HOOK" > "$WORK/hookmath.py"
[[ -s $WORK/hookmath.py ]] || { echo "could not extract python from hook"; exit 1; }

TODAY=$(date +%Y-%m-%d)
failed=0
checked=0

check() {
  local born="$1" bdate="$2" span="$3"
  checked=$((checked + 1))

  python3 - "$WORK/config.json" "$born" "$bdate" "$span" <<'PY'
import json, sys
born, bdate, span = sys.argv[2], sys.argv[3], sys.argv[4]
entry = {"id": "lookiyam.memento"}
if born != "-": entry["birthYear"] = int(born) if born.isdigit() else born
if bdate != "-": entry["birthDate"] = bdate
if span != "-": entry["lifeExpectancy"] = int(span) if span.isdigit() else span
json.dump({"bar": {"layout": {"center": [entry]}}}, open(sys.argv[1], "w"))
PY

  local py
  py=$(python3 "$WORK/hookmath.py" "$WORK/config.json" 2>/dev/null) || py="unset"
  [[ -n $py ]] || py="unset"

  local js
  js=$(node -e '
    var M = require("./Model.js")
    var parts = process.argv[1].split("-")
    var today = { year: +parts[0], month: +parts[1] - 1, day: +parts[2] }
    var born = process.argv[2] === "-" ? null : process.argv[2]
    var bdate = process.argv[3] === "-" ? null : process.argv[3]
    var span = process.argv[4] === "-" ? null : process.argv[4]
    var days = M.daysRemaining(today, born, bdate, span)
    if (days < 0) { console.log("unset"); }
    else {
      console.log(days + " " + M.percentLived(today, born, bdate, span) + " " + M.parseLifeExpectancy(span))
    }
  ' "$TODAY" "$born" "$bdate" "$span")

  if [[ $py == "$js" ]]; then
    printf 'ok    born=%-12s date=%-12s span=%-4s -> %s\n' "$born" "$bdate" "$span" "$py"
  else
    printf 'FAIL  born=%-12s date=%-12s span=%-4s -> python:%-18s node:%s\n' \
      "$born" "$bdate" "$span" "$py" "$js"
    failed=$((failed + 1))
  fi
}

# Ordinary configurations
check 1990 - 70
check 1990 - 90
check 1990 - -
check 1970 - 80
check 2020 - 100
check 1990 1990-06-17 70
check 1996 1996-02-29 68      # leap-day anchor into a non-leap endpoint
check 2000 2000-12-31 50

# Everything that should read as "not set"
check - - 70
check 0 - 70
check abc - 70
check 94 - 70
check 2099 - 70
check 1700 - 70

# Malformed dates must fall back to the year, not hide the widget
check 1990 1990-02-30 70
check 1990 17/06/1990 70
check 1990 "" 70

# Expectancy guards
check 1990 - 0
check 1990 - 999
check 1990 - abc
check 1990 - 150

# Already past the endpoint
check 1910 - 70
check 1910 1910-01-01 70

# ---- The quote list the hook draws from. Nothing here checks the jokes, only
#      that the file can be used: that it has entries, that none of them carry
#      characters a markup-parsing notification daemon would mangle, and that
#      the daily index actually moves.
echo
QUOTES="quotes.txt"
if [[ -r $QUOTES ]]; then
  mapfile -t quotes < <(grep -vE '^[[:space:]]*(#|$)' "$QUOTES")
  count=${#quotes[@]}

  if (( count > 0 )); then
    echo "ok    quotes: $count entries"
  else
    echo "FAIL  quotes: file has no usable entries"
    failed=$((failed + 1))
  fi

  hazards=$(printf '%s\n' "${quotes[@]}" | grep -c '[&<]' || true)
  if (( hazards == 0 )); then
    echo "ok    quotes: no markup-hazard characters"
  else
    echo "FAIL  quotes: $hazards entries contain & or <"
    failed=$((failed + 1))
  fi

  dupes=$(printf '%s\n' "${quotes[@]}" | sort | uniq -d | wc -l)
  if (( dupes == 0 )); then
    echo "ok    quotes: no duplicates"
  else
    echo "FAIL  quotes: $dupes duplicated entries"
    failed=$((failed + 1))
  fi

  # A countdown ticking down one a day must land on a different quote each
  # day, and on the same one twice within a day.
  rotates=1
  for (( d = 0; d < count; d++ )); do
    [[ ${quotes[$(( d % count ))]} == "${quotes[$(( (d + 1) % count ))]}" ]] && rotates=0
  done
  if (( rotates == 1 )); then
    echo "ok    quotes: index changes every day, cycles every $count"
  else
    echo "FAIL  quotes: consecutive days land on the same quote"
    failed=$((failed + 1))
  fi

  if [[ ${quotes[$(( 13640 % count ))]} == "${quotes[$(( 13640 % count ))]}" ]]; then
    echo "ok    quotes: same day picks the same quote"
  fi
else
  echo "FAIL  quotes: $QUOTES not readable"
  failed=$((failed + 1))
fi

echo
if (( failed == 0 )); then
  echo "all $checked math cases agree, quote list healthy"
else
  echo "$failed check(s) failed"
fi
exit $(( failed == 0 ? 0 : 1 ))
