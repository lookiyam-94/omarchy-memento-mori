// Pure date math for the memento widget. Locale- and Qt-free on purpose, the
// same way the stock clock plugin keeps its Model.js testable under plain
// node -- nothing in here touches QML, so it can be exercised directly.

var DEFAULT_LIFE_EXPECTANCY = 90

// ---- Settings parsing. Every guard resolves to "not set" rather than to a
//      wrong number: a widget that hides itself is honest, one that shows a
//      countdown built from garbage is not.

// 0 means "not set", which is also what a blank, malformed, future, or
// implausibly distant year means.
function parseBirthYear(value, currentYear) {
  var now = Math.round(Number(currentYear))
  if (!isFinite(now)) return 0
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d{4}$/.test(text)) return 0
  var year = parseInt(text, 10)
  if (!isFinite(year) || year > now || year < now - 120) return 0
  return year
}

// Unset or nonsense falls back to the default rather than to zero, so the
// countdown always has something to measure against.
function parseLifeExpectancy(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return DEFAULT_LIFE_EXPECTANCY
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 150) return DEFAULT_LIFE_EXPECTANCY
  return years
}

// Optional "YYYY-MM-DD" refinement. With only a birth year the endpoint can
// be no better than January 1, which leaves the count off by however far the
// real birthday sits from the turn of the year. Returns null when unset or
// unparseable, and the caller falls back to the year alone.
function parseBirthDate(value, currentYear) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!match) return null

  var year = parseBirthYear(match[1], currentYear)
  if (year <= 0) return null

  var month = parseInt(match[2], 10)
  var day = parseInt(match[3], 10)
  if (!isFinite(month) || month < 1 || month > 12) return null
  if (!isFinite(day) || day < 1 || day > 31) return null

  // Reject a day the month does not actually have (Feb 30, Apr 31) rather
  // than letting Date roll it forward into the next month.
  var probe = new Date(Date.UTC(year, month - 1, day))
  if (probe.getUTCMonth() !== month - 1 || probe.getUTCDate() !== day) return null

  return { year: year, month: month - 1, day: day }
}

// ---- Day math. Counted in UTC midnights so a DST changeover cannot make a
//      day arrive twice or go missing.
function daysBetween(from, to) {
  var start = Date.UTC(from.year, from.month, from.day)
  var end = Date.UTC(to.year, to.month, to.day)
  return Math.round((end - start) / 86400000)
}

// The birth anchor: the full date when one is configured, otherwise January 1
// of the birth year.
function birthAnchor(birthYear, birthDate, currentYear) {
  var exact = parseBirthDate(birthDate, currentYear)
  if (exact) return exact
  var year = parseBirthYear(birthYear, currentYear)
  if (year <= 0) return null
  return { year: year, month: 0, day: 1 }
}

// The endpoint is the anchor plus the expectancy in whole years. A Feb 29
// anchor lands on Mar 1 in a non-leap year, which is the conventional way to
// carry that date forward.
function endAnchor(anchor, expectancy) {
  if (!anchor) return null
  var end = new Date(Date.UTC(anchor.year + expectancy, anchor.month, anchor.day))
  return { year: end.getUTCFullYear(), month: end.getUTCMonth(), day: end.getUTCDate() }
}

// Days from today to the endpoint, floored at zero -- past the endpoint the
// widget reads "0" rather than going negative.
function daysRemaining(today, birthYear, birthDate, expectancy) {
  var anchor = birthAnchor(birthYear, birthDate, today.year)
  if (!anchor) return -1
  var end = endAnchor(anchor, parseLifeExpectancy(expectancy))
  if (!end) return -1
  return Math.max(0, daysBetween(today, end))
}

// Share of the span already spent, as a whole percentage. Measured in days
// against the same two anchors the countdown uses, so the two numbers can
// never disagree about where you are.
function percentLived(today, birthYear, birthDate, expectancy) {
  var anchor = birthAnchor(birthYear, birthDate, today.year)
  if (!anchor) return -1
  var end = endAnchor(anchor, parseLifeExpectancy(expectancy))
  if (!end) return -1

  var span = daysBetween(anchor, end)
  if (span <= 0) return -1
  var spent = daysBetween(anchor, today)
  return Math.round(Math.max(0, Math.min(1, spent / span)) * 100)
}

// Thousands separators, so a five-digit count stays readable at bar size.
function groupDigits(value) {
  var digits = String(Math.max(0, Math.round(Number(value) || 0)))
  var out = ""
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += ","
    out += digits.charAt(i)
  }
  return out
}

// The bar label. `template` is the configured format with {days} substituted;
// an empty count yields an empty label and the widget paints nothing.
function barLabel(days, template) {
  if (days < 0) return ""
  var text = String(template === undefined || template === null ? "" : template)
  if (text === "") text = "{days}"
  return text.replace(/\{days\}/g, groupDigits(days))
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    DEFAULT_LIFE_EXPECTANCY: DEFAULT_LIFE_EXPECTANCY,
    parseBirthYear: parseBirthYear,
    parseLifeExpectancy: parseLifeExpectancy,
    parseBirthDate: parseBirthDate,
    daysBetween: daysBetween,
    birthAnchor: birthAnchor,
    endAnchor: endAnchor,
    daysRemaining: daysRemaining,
    percentLived: percentLived,
    groupDigits: groupDigits,
    barLabel: barLabel
  }
}
