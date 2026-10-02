#!/usr/bin/env bash
# Exercises Model.js under node. The model is deliberately Qt-free so the date
# math can be checked without starting a shell.
set -euo pipefail
cd "$(dirname "$0")/.."

node -e '
var M = require("./Model.js")
var today = { year: 2026, month: 7, day: 28 }   // 2026-08-28
var failed = 0
function eq(label, got, want) {
  var ok = String(got) === String(want)
  if (!ok) failed++
  console.log((ok ? "ok  " : "FAIL") + "  " + label + ": " + got + (ok ? "" : " (want " + want + ")"))
}

eq("days, year only (1990/70)", M.daysRemaining(today, 1990, null, 70), 12179)
eq("percent lived, year only", M.percentLived(today, 1990, null, 70), 52)
eq("days, exact date (1990-06-17/70)", M.daysRemaining(today, 1990, "1990-06-17", 70), 12347)
eq("missing expectancy uses default 90", M.daysRemaining(today, 1990, null, null), M.daysRemaining(today, 1990, null, 90))

eq("unset year hides", M.daysRemaining(today, 0, null, 70), -1)
eq("future year hides", M.daysRemaining(today, 2099, null, 70), -1)
eq("garbage year hides", M.daysRemaining(today, "abc", null, 70), -1)
eq("two-digit year hides", M.daysRemaining(today, 94, null, 70), -1)
eq("impossible date falls back to year", M.daysRemaining(today, 1990, "1990-02-30", 70), 12179)
eq("malformed date falls back to year", M.daysRemaining(today, 1990, "17/06/1990", 70), 12179)
eq("leap day accepted", M.parseBirthDate("1996-02-29", 2026).day, 29)
eq("past endpoint floors at zero", M.daysRemaining(today, 1920, null, 70), 0)
eq("absurd expectancy uses default", M.parseLifeExpectancy("999"), 90)
eq("zero expectancy uses default", M.parseLifeExpectancy(0), 90)

eq("digit grouping", M.groupDigits(13640), "13,640")
eq("short number ungrouped", M.groupDigits(940), "940")
eq("default label", M.barLabel(13640, null), "13,640")
eq("template label", M.barLabel(13640, "{days}d left"), "13,640d left")
eq("unconfigured label is empty", M.barLabel(-1, "{days}d"), "")

console.log(failed === 0 ? "\nall passed" : "\n" + failed + " failed")
process.exit(failed === 0 ? 0 : 1)
'
