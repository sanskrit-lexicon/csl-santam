# Changelog

All notable changes to [csl-santam](https://github.com/sanskrit-lexicon/csl-santam) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project intends to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

csl-santam is a web-frontend port of the Cologne ["MWScan tamil"](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html) multi-dictionary search. The form at [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) POSTs to the backend [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php), which queries one combined SQLite table `tamil(id, st, en)` ([sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql)) spanning four lexica: Monier-Williams (`mwd`, 166,434 entries), Capeller (`cap`, 37,413), the Cologne Online Tamil Lexicon (`otl`, 117,773), and the Concise Pahlavi Dictionary (`cpd`, 4,218 — disabled in the UI and excluded from `all` via `id<4`). `all` searches mwd + cap + otl = 325,838 entries. Headword input is Harvard-Kyoto (HK) ASCII romanization, not Unicode script. Two implementations exist: the original Perl CGI (`perl/`) and a close PHP port (`php/`). Default branch: `master`. Maintainer: Thomas Malten (th.malten@uni-koeln.de).

## [Unreleased] — 2026-06-14

### Security

The search backend [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) was hardened against injection at the point of use. None of these changes alter end-user search semantics — user-typed SQL/regex/HTML metacharacters are now treated as literal text. (Note: the pre-existing `sanitize_REQUEST_all()` runs `filter_var(…, FILTER_UNSAFE_RAW)`, which performs no filtering and is effectively a no-op; the escaping guards below are the real input safety.)

- **Reflected XSS in `fehler()` error output** — the error message is now wrapped in `htmlspecialchars($msg, ENT_QUOTES)`. `$msg` can embed user input (e.g. the unknown dictionary code reflected by `dictionary_info()`'s `"No dictonary…$dictionary"` message), which was previously emitted unescaped. ([PR #4](https://github.com/sanskrit-lexicon/csl-santam/pull/4))
- **SQL injection via the `where1()` search term** — each search term is now escaped for the SQLite string literal by doubling single quotes (`str_replace("'", "''", …)`): `$x` for the native `LIKE` (substring) branch, and inside `$xr` for the `regexp` branches. ([PR #5](https://github.com/sanskrit-lexicon/csl-santam/pull/5))
- **SQL injection via `maxhits` in the `LIMIT` clause** — `$maxhits` (raw `$_REQUEST`) is now cast with `(int)` before being concatenated into the query (`" LIMIT " . (int)$maxhits;`). ([PR #6](https://github.com/sanskrit-lexicon/csl-santam/pull/6))
- **Regex injection / ReDoS in the `exact`/`prefix`/`suffix` branches** — the regexp-branch term is now `preg_quote($part_l, '/')`d (inside `$xr`) before it reaches `_sqliteRegexp()`'s `preg_match('/'.$pattern.'/i', …)`, neutralizing PCRE metacharacters and catastrophic-backtracking patterns (e.g. `(a+)+`) that would otherwise run per row. The `\b` word-boundary anchors (`$wb`/`$we`) remain active; the native `LIKE` (`substring`) branch is unchanged. ([PR #7](https://github.com/sanskrit-lexicon/csl-santam/pull/7))

### Dependencies

- Bump `dependabot/fetch-metadata` from 2 to 3 in the CI workflow. ([PR #3](https://github.com/sanskrit-lexicon/csl-santam/pull/3))

### Documentation

- Deepened the auto-generated `README.md` stub (previously only "Runtime: Perl" plus generic 0-open-issue tables) into a substantive description of the search frontend, the four lexica and their entry counts, the HK input requirement, the request parameters, and the Perl/PHP parity. The stale auto-generated issue tables were removed.
- Added/maintained `.ai_state.md` as the session journal per org convention, with the fixed section structure (`# Project Objective`, `## ➡️ Next Steps (Queue)`, `## 🚧 Current Work-In-Progress (WIP)`, `## 🧠 Dev Notes & Hypotheses (Bugs, ideas, context)`, `## ✅ Completed (Recent only)`).

### Notes

- **Perl → PHP parity.** The PHP backend is a close port of `perl/recherche.pl` + `perl/cgi-include2.pl`. The one documented divergence: the PHP `maxhits` dropdown offers `20 / 50 / 100 / 200 / 500 / 1000` (default `50`) and drops the Perl original's `all` option ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)). The `en` field is re-encoded `iconv("Windows-1252","UTF-8", …)` per row at render time in the PHP port (the Perl code does this conversion itself).
- **Known code-comment quirk (not changed).** `compute_where()`'s comment calls the excluded `id=4` dictionary "Pali"; per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) and [readme_dev.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/readme_dev.txt) it is the Concise **Pahlavi** Dictionary (`cpd`). The behavior (`id<4` excludes it from `all`) is correct regardless of the mislabel.

[Unreleased]: https://github.com/sanskrit-lexicon/csl-santam/commits/master
