_Created: 14-06-2026 · Last updated: 05-09-2026_

# Changelog

All notable changes to [csl-santam](https://github.com/sanskrit-lexicon/csl-santam) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project intends to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

csl-santam is a web-frontend port of the Cologne ["MWScan tamil"](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html) multi-dictionary search. The form at [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) POSTs to the backend [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php), which queries one combined SQLite table `tamil(id, st, en)` ([sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql)) spanning four lexica: Monier-Williams (`mwd`, 166,434 entries), Capeller (`cap`, 37,413), the Cologne Online Tamil Lexicon (`otl`, 117,773), and the Concise Pahlavi Dictionary (`cpd`, 4,218 — disabled in the UI and excluded from `all` via `id<4`). `all` searches mwd + cap + otl = 321,620 entries (the form's "325,838" label counts all four, including the disabled Pahlavi). Headword input is Harvard-Kyoto (HK) ASCII romanization, not Unicode script. Two implementations exist: the original Perl CGI (`perl/`) and a close PHP port (`php/`). Default branch: `master`. Maintainer: Thomas Malten (th.malten@uni-koeln.de).

## [Unreleased]

Nothing yet.

## [0.2.0] — 2026-08-28

### Added

- **Clean-UTF-8 corpus export** (Wave 3 migration artifact, [docs/ROADMAP_2026_2027.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ROADMAP_2026_2027.md)). [sqlite/normalize_utf8.py](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/normalize_utf8.py) re-exports `sqlite/ganz.txt` to `sqlite/ganz_utf8.txt`, decoding the Windows-1252 `en` (and `st`) fields to UTF-8 — mirroring the per-row `iconv("Windows-1252","UTF-8")` workaround at [php/recherche.php:97](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php#L97) — and adding an explicit `mwd`/`cap`/`otl`/`cpd` dict-code column alongside the numeric id (from [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books)). All 325,838 rows (321,620 active + 4,218 disabled-Pahlavi) round-trip as valid UTF-8 with zero replacement characters. Along the way, fixed 6 rows (e.g. "Bühler", "über") whose `en` field the live iconv() workaround silently drops today — byte `0x81` is undefined in Windows-1252 but always represents `ü` in this corpus, so it's remapped before decoding. This export is additive only; `php/recherche.php` and `sqlite/tamil.sqlite` are unchanged — it is the artifact Wave 3's client-side rebuild and Wave 4's kosha fold-in will consume.
- **Semgrep SAST** ([.github/workflows/semgrep.yml](https://github.com/sanskrit-lexicon/csl-santam/blob/master/.github/workflows/semgrep.yml)), advisory, `p/php` + `p/security-audit` rulesets against [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php). CodeQL has no PHP/Perl analyzer and would scan nothing in this repo, so it is deliberately not deployed here — same gap `csl-websanlexicon` closed with Semgrep.
- **Client-side Devanagari/IAST → Harvard-Kyoto transliteration input** (Wave 2, [docs/ROADMAP_2026_2027.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ROADMAP_2026_2027.md)). [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) now converts the primary-language field to HK before submit when it contains Devanagari or IAST diacritics; plain-ASCII (including existing HK usage) is left untouched. No backend change. Reuses [sanskrit-util](https://github.com/sanskrit-lexicon/sanskrit-util) `v0.3.0` (vendored, [php/js/vendor/sanskrit-util.global.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/vendor/sanskrit-util.global.js)) for IAST/Deva→SLP1 and kosha's `_SLP1_TO_HK` table (ported, not reinvented) for the SLP1→HK leg, glued in a new [php/js/hk-input.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/hk-input.js). Not applied when the Cologne Online Tamil Lexicon (`otl`) is selected — its HK-like scheme differs (see [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md#client-side-transliteration-input-wave-2)).
- **Case-sensitive search toggle** (Wave 2, [docs/ROADMAP_2026_2027.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ROADMAP_2026_2027.md)). A new "Case-sensitive search" checkbox (`case_sensitive=1`) opts out of the default case-folded matching, so HK's phonemic letter case (`A`=ā, `T`=ṭ, `S`=ṣ vs `s`, …) no longer has to be conflated. Applies to both `st` and `en`, all four match modes. Implementation required two non-obvious fixes beyond just skipping `lower()`/`strtolower()`: a second SQLite UDF `regexp_cs` (no `/i` flag) called via function-call syntax — SQLite's `REGEXP` infix operator is hardwired to a function literally named `regexp`, so a second variant can't be invoked as an infix operator — and `PRAGMA case_sensitive_like`, since SQLite's `LIKE` is otherwise case-insensitive for ASCII regardless of any lowercasing done in the query string. Verified against a real in-memory SQLite database (9 scenarios: exact/prefix/substring, case-sensitive and -insensitive, incl. the retroflex/dental `aTa`/`ata` distinction) — no PHP interpreter was available to run the PHP itself.

## [0.1.0] — 2026-06-14

### Security

The search backend [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) was hardened against injection at the point of use. None of these changes alter end-user search semantics — user-typed SQL/regex/HTML metacharacters are now treated as literal text. (Note: the pre-existing `sanitize_REQUEST_all()` runs `filter_var(…, FILTER_UNSAFE_RAW)`, which performs no filtering and is effectively a no-op; the escaping guards below are the real input safety.)

- **Reflected XSS in `fehler()` error output** — the error message is now wrapped in `htmlspecialchars($msg, ENT_QUOTES)`. `$msg` can embed user input (e.g. the unknown dictionary code reflected by `dictionary_info()`'s `"No dictonary…$dictionary"` message), which was previously emitted unescaped. ([PR #4](https://github.com/sanskrit-lexicon/csl-santam/pull/4))
- **SQL injection via the `where1()` search term** — each search term is now escaped for the SQLite string literal by doubling single quotes (`str_replace("'", "''", …)`): `$x` for the native `LIKE` (substring) branch, and inside `$xr` for the `regexp` branches. ([PR #5](https://github.com/sanskrit-lexicon/csl-santam/pull/5))
- **SQL injection via `maxhits` in the `LIMIT` clause** — `$maxhits` (raw `$_REQUEST`) is now cast with `(int)` before being concatenated into the query (`" LIMIT " . (int)$maxhits;`). ([PR #6](https://github.com/sanskrit-lexicon/csl-santam/pull/6))
- **Regex injection / ReDoS in the `exact`/`prefix`/`suffix` branches** — the regexp-branch term is now `preg_quote($part_l, '/')`d (inside `$xr`) before it reaches `_sqliteRegexp()`'s `preg_match('/'.$pattern.'/i', …)`, neutralizing PCRE metacharacters and catastrophic-backtracking patterns (e.g. `(a+)+`) that would otherwise run per row. The `\b` word-boundary anchors (`$wb`/`$we`) remain active; the native `LIKE` (`substring`) branch is unchanged. ([PR #7](https://github.com/sanskrit-lexicon/csl-santam/pull/7))

### Changed

- Bump `dependabot/fetch-metadata` from 2 to 3 in the CI workflow. ([PR #3](https://github.com/sanskrit-lexicon/csl-santam/pull/3))

### Fixed

- **Misleading source comment in `compute_where()`.** The `all`-branch comment called the excluded `id=4` dictionary "Pali"; it is the Concise **Pahlavi** Dictionary (`cpd`), per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books). Comment-only — the behavior (`id<4` excludes it from `all`) was already correct. ([PR #11](https://github.com/sanskrit-lexicon/csl-santam/pull/11))
- **Unclamped `maxhits`.** A missing/empty/`0`/negative `maxhits` (e.g. from a direct/API caller) previously produced `LIMIT 0` or a SQLite error. `maxhits` now defaults to `50` and clamps to `1000` when out of range, mirroring the search form's own default/max ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)). ([PR #11](https://github.com/sanskrit-lexicon/csl-santam/pull/11))
- **Unescaped `%`/`_` in the `substring` LIKE branch of `where1()`.** A literal `%` or `_` in a query was silently interpreted as a SQL `LIKE` wildcard/single-char-match, giving unpredictable (though not unsafe — the `'` was already doubled) results. The term is now backslash-escaped (`\`, `%`, `_`) and the fragment carries an explicit `ESCAPE '\'` clause, so literal `%`/`_` match themselves. ([PR #11](https://github.com/sanskrit-lexicon/csl-santam/pull/11))

### Documentation

- Deepened the auto-generated `README.md` stub (previously only "Runtime: Perl" plus generic 0-open-issue tables) into a substantive description of the search frontend, the four lexica and their entry counts, the HK input requirement, the request parameters, and the Perl/PHP parity. The stale auto-generated issue tables were removed.
- Added/maintained `.ai_state.md` as the session journal per org convention, with the fixed section structure (`# Project Objective`, `## ➡️ Next Steps (Queue)`, `## 🚧 Current Work-In-Progress (WIP)`, `## 🧠 Dev Notes & Hypotheses (Bugs, ideas, context)`, `## ✅ Completed (Recent only)`).
- Added `docs/ROADMAP_2026_2027.md` (4-wave roadmap, 4 maintainer rulings).
- **Retired `readme_dev.txt`** (self-described as "somewhat obsolete as of 12/27/2022"). Its still-accurate content (Perl/PHP parity, the `en` Windows-1252→UTF-8 conversion, the data path) was already folded into `docs/ARCHITECTURE.md`; all cross-references were repointed there. ([PR #11](https://github.com/sanskrit-lexicon/csl-santam/pull/11))
- Added `CODE_OF_CONDUCT.md`, `SECURITY.md`, and `.pre-commit-config.yaml`; turned on branch protection for `master`. ([PR #11](https://github.com/sanskrit-lexicon/csl-santam/pull/11))

### Notes

- **Perl → PHP parity.** The PHP backend is a close port of `perl/recherche.pl` + `perl/cgi-include2.pl`. The one documented divergence: the PHP `maxhits` dropdown offers `20 / 50 / 100 / 200 / 500 / 1000` (default `50`) and drops the Perl original's `all` option ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)). The `en` field is re-encoded `iconv("Windows-1252","UTF-8", …)` per row at render time in the PHP port (the Perl code does this conversion itself).

[Unreleased]: https://github.com/sanskrit-lexicon/csl-santam/compare/v0.2.0...master
[0.2.0]: https://github.com/sanskrit-lexicon/csl-santam/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sanskrit-lexicon/csl-santam/releases/tag/v0.1.0

_Dr. Mārcis Gasūns_
