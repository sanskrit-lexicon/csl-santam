# csl-santam — Architecture

Deep technical reference for the dictionary-search backend of [sanskrit-lexicon/csl-santam](https://github.com/sanskrit-lexicon/csl-santam). Every function name, branch, schema, and string literal below is quoted verbatim from live `master`. Source files are linked inline with full `blob` URLs.

---

## Overview

csl-santam is a web-frontend port of the Cologne **"MWScan tamil"** multi-dictionary search ([uni-koeln MWScan/tamil](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html)). A single search form ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)) POSTs to a single endpoint ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)), which queries **one combined SQLite table** (`tamil`) spanning four lexica.

Two implementations live side by side:

- the original **Perl CGI** backend (`perl/recherche.pl` + `perl/cgi-include2.pl`, form `perl/index.html`), and
- a **close PHP port** ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)) — the hardened, primary implementation documented here.

Maintainer: **Thomas Malten** (`th.malten@uni-koeln.de`), Cologne. Default branch: `master`. Form title: *"Sanskrit and Tamil Dictionaries"*.

The corpus is **Harvard-Kyoto (HK) romanized transliteration in single-byte ASCII** (e.g. `akAra`, with `%{...}` markup), **not** Unicode Devanagari/Tamil script. This single fact drives most of the design decisions below (see [Encoding rationale](#encoding-rationale)). Users type romanized HK; the form does not accept native script.

---

## Data model

### Source file: `sqlite/ganz.txt`

The data lives in `sqlite/ganz.txt` (~25 MB), a tab-delimited flat file with **three fields per line**:

```
dict-id <TAB> headword(st) <TAB> entry(en)
```

### The `tamil` table

`ganz.txt` is imported into one table named `tamil` by [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) (verbatim):

```sql
DROP TABLE tamil;
CREATE TABLE tamil (
 id INT  NOT NULL,
 st VARCHAR(255)  NOT NULL,
 en TEXT NOT NULL
);
.separator "\t"
.import ganz.txt tamil
```

| Column | Type | Meaning |
|---|---|---|
| `id` | `INT` | Dictionary id (1–4); doubles as the per-row dictionary tag. |
| `st` | `VARCHAR(255)` | The headword / primary-language term ("st") in HK. |
| `en` | `TEXT` | The description / entry body ("en"). |

### The four dictionaries

The id→name map is [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books), read at runtime by `readbooks()` via the regex `/^([1-4]) (.*?) (.*)$/` (id, shortcode, fullname):

| id | code | name | entries | UI status |
|----|------|------|--------:|-----------|
| 1 | `mwd` | Cologne Digital Sanskrit Lexicon (Monier-Williams) | 166,434 | active (default) |
| 2 | `cap` | Capeller's Sanskrit-English Dictionary | 37,413 | active |
| 3 | `otl` | Cologne Online Tamil Lexicon | 117,773 | active |
| 4 | `cpd` | Concise Pahlavi Dictionary | 4,218 | **DISABLED** — `<option value=cpd>` HTML-commented in the form |

`all` = **321,620** entries = mwd + cap + otl (the form's hard-coded "325,838" label counts all four dictionaries; `all` excludes Pahlavi). The Pahlavi dictionary (id 4) is present in the data and in [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books), but is **excluded from `all`** (the SQL filters `id<4`) and its `<option>` is HTML-commented in [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html). The entry counts above are hard-coded as display labels in the form.

### Build / rebuild

The database is rebuilt by [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat), which deletes `tamil.sqlite` and pipes [def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) into the XAMPP-bundled `sqlite3.exe` (verbatim):

```bat
rm tamil.sqlite
C:\xampp\MercuryMail\sqlite3.exe  tamil.sqlite < def.sql
```

The built database `sqlite/tamil.sqlite` is what [recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) opens at runtime.

---

## Request pipeline

All functions below are in [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php). Top-level flow, in order.

### a. `sanitize_REQUEST_all()`

Called first. Iterates every `$_REQUEST` key and runs `filter_var($old, FILTER_UNSAFE_RAW)`, writing the result back into `$_REQUEST[$key]`. `FILTER_UNSAFE_RAW` performs **no** filtering — this is effectively a no-op pass-through. (Earlier `FILTER_SANITIZE_STRING`/`FILTER_SANITIZE_URL` attempts are commented out; `FILTER_SANITIZE_STRING` is deprecated in PHP 8.2.) The real input safety comes from the point-of-use guards in [Security model](#security-model), not from this function.

### b. Read inputs

From `$_REQUEST`: `$dictionary, $st, $prst, $en, $pren, $maxhits`. Because the code reads `$_REQUEST`, the form's POST works and a GET query-string also works for API clients (e.g. `recherche.php?dictionary=mwd&st=agni&prst=prefix&maxhits=50`).

| param | values | default |
|-------|--------|---------|
| `dictionary` | `mwd` \| `cap` \| `otl` \| `all` (`cpd` commented out) | `mwd` |
| `st` | primary-language word(s) (Sanskrit/Tamil) in HK | — |
| `prst` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `en` | English word(s), searched in the description | — |
| `pren` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `maxhits` | `20` \| `50` \| `100` \| `200` \| `500` \| `1000` | `50` |

### c. `readbooks()`

Loads [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) into `$dictbooks` (array of `[num, short, long]`).

### d. `dictionary_info($dictionary, $dictbooks)`

Maps the dictionary code to `($dictnum, $dictname)`:

- `'all'` → `dictnum='0'`, `dictname='All dictionaries'`.
- otherwise linear-scans `$dictbooks` matching `$dictionary` against the shortcode, returning that row's numeric id + full name.
- no match → `fehler("No dictonary has been selected.$dictionary")` (this **exits**).

### e. Empty-query guard

After `trim($st)` / `trim($en)`, if **neither** field has length > 1, `fehler("No search has been formulated.")`. The check is a single OR across both fields: a ≤ 1-char value in one field is **not** rejected on its own — if the other field has length > 1 the search proceeds and the short value is still passed to `where1()` and used in the WHERE clause.

### f. `compute_where($dictnum, $st, $prst, $en, $pren)`

Builds the WHERE clause:

- dictionary scope: `id<4` when `dictnum=='0'` (the `all` case), else `id=$dictnum`.
- if `$st != ""`: appends `... and ` + `where1($st, 'st', $prst)`.
- if `$en != ""`: appends `... and ` + `where1($en, 'en', $pren)`.

### g. `where1($var, $varname, $pr)` — per-field clause builder

This is where match mode and escaping happen:

- `trim`s the value, splits into words on `preg_split('/ +/', $var)` → multiple words in one field are **AND-joined**.
- lowercases the column for matching: `$lowdata = "lower($varname)"`; lowercases each term: `$part_l = strtolower($part)`.
- builds two escaped forms of each term:
  - `$x = str_replace("'", "''", $part_l)` — for the **LIKE** (substring) branch.
  - `$xr = str_replace("'", "''", preg_quote($part_l, '/'))` — for the **regexp** branches.
- word-boundary anchors: `$wb = "\\b"`, `$we = "\\b"`.

Match-mode → SQL fragment (`$regexp` is the literal string `'regexp'`, the name of the SQLite UDF):

| `$pr` mode | generated fragment | engine |
|-----------|--------------------|--------|
| `exact` | `(lower(col) regexp '\b{term}\b')` | regexp UDF |
| `prefix` | `(lower(col) regexp '\b{term}')` | regexp UDF |
| `suffix` | `(lower(col) regexp '{term}\b')` | regexp UDF |
| `substring` (else) | `(lower(col) like '%{term}%')` | native SQL `LIKE` |

`exact`/`prefix`/`suffix` route through the custom SQLite **`regexp`** function; `substring` uses native **`LIKE '%…%'`**. Multiple terms within a field are chained with ` and `. There is **no OR** anywhere in the query builder — every added word or field tightens the result set.

### h. Assemble and run the query (top level)

```php
$befehl = "select id,st,en from tamil where $where order by st collate nocase";
$befehl .= " LIMIT " . (int)$maxhits;
$results = selectfromdb($befehl);
```

Final SQL shape:

```sql
SELECT id, st, en FROM tamil
WHERE <dict-cond> [AND <st-conds…>] [AND <en-conds…>]
ORDER BY st COLLATE NOCASE LIMIT <(int)maxhits>;
```

`ORDER BY st COLLATE NOCASE` returns the alphabetically-first N rows. There is no pagination and no offset — beyond the cap, raise `maxhits` (≤ 1000) or tighten the query.

### i. `selectfromdb($sql)`

Opens `../sqlite/tamil.sqlite` via **PDO** (`new PDO('sqlite:'…)`, `ERRMODE_EXCEPTION`), then registers the regexp UDF:

```php
$file_db->sqliteCreateFunction('regexp', '_sqliteRegexp', 2);
```

Runs `$file_db->query($sql)` and collects each row as `[id, st, en]`. PDO failures route to `fehler(...)`.

### j. `_sqliteRegexp($pattern, $string)` — the regexp UDF

The active line is:

```php
if (preg_match('/'.$pattern.'/i', $string)) { return true; }
```

Case-insensitive (`/i`), **no `/u` flag** (correct for this corpus — see [Encoding rationale](#encoding-rationale)). A commented alternative `'/^'.$pattern.'$/i'` exists but is not used. This is the engine the `\b` anchors from `where1()` flow into — the word boundary lets a term match a *whole word inside* the `en` entry text, not just the field as a whole.

---

## Search semantics (user-facing)

The query builder exposes a small, strict set of behaviors. They follow directly from the pipeline above and are restated here so the architecture is self-complete.

- **Two search axes.** `st` searches the romanized HK headword (Sanskrit for `mwd`/`cap`, Tamil for `otl`); `en` searches the full English entry text (translation, grammar, etymology, and any other listed material). Filling only `en` is a pure **reverse / onomasiological** lookup — find words whose definition mentions an English term.
- **Four match modes, per field** (`prst` for `st`, `pren` for `en`):
  - **exact** → `\bTERM\b` — TERM as a whole bounded word; `akAra` does **not** match `akAraNa` or `prAkAra`.
  - **prefix** → `\bTERM` — a word starting with TERM (e.g. `agni` matches `agni`, `agnihotra`, `agniSToma`).
  - **suffix** → `TERM\b` — a word ending in TERM (e.g. `pati` matches `gaNapati`, `prajApati`).
  - **substring** → `LIKE '%TERM%'` — TERM anywhere, **no** word boundary (e.g. `indra` also matches `indriya`); the loosest, noisiest mode.
- **AND only — no OR, no phrase search.** Multiple words in one field are split on spaces and AND-joined; filling both `st` and `en` AND-joins the two condition blocks; the dictionary `id` scope is ANDed in front. So `en=white elephant` requires *both* whole words "white" and "elephant", in any order (not a phrase). Every added word or field tightens results.
- **Minimum length 2.** The guard is a single OR across both fields — a ≤ 1-char value is **not** ignored per-field; if the other field qualifies, the short value still goes into the query. If neither field has > 1 character the search is rejected with *"No search has been formulated."*
- **Hard result cap, no paging.** `maxhits` ∈ {20, 50, 100, 200, 500, 1000}, default 50, applied as `LIMIT (int)$maxhits`. Broad searches silently truncate at the cap; rows are ordered `st COLLATE NOCASE`, so you receive the alphabetically-first N. There is no offset.
- **Always case-insensitive** — see the HK caveat in [Known quirks](#known-quirks--gotchas).

---

## Result rendering

Still in [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php), after the query:

- Page chrome: `<html>…<h1>$dictname: Search Results</h1>`.
- **`all`-mode legend**: when `dictnum=='0'`, an abbreviation table `($bshort) = $blong` is printed for each book **except id 4** (`if ($bnum != '4')`) — the Pahlavi line is suppressed because the form does not expose it.
- **Per-result row** (loop over `$results`): prints a 1-based hit number, then:
  - **dict-book lookup** — in `all`-mode it derives `$idx = intval($id) - 1` and looks up `$dictbooks[$idx]` to print the per-row short code `($bshort)` in a column; a single-dictionary search shows no book column.
  - **headword** — `<b>$st</b>`.
  - **`en` field encoding conversion** — `$en1 = iconv("Windows-1252","UTF-8",$en)`: the raw `en` bytes are read as Windows-1252 and converted to UTF-8 before output (otherwise "unprintable characters" appear). A code comment notes a cleaner fix would be to `iconv` `ganz.txt` once and rebuild the SQLite DB; per that comment the original Perl backend "seems to do this conversion on its own."
- `$id`/`$st`/`$en` are deliberately rebound as loop locals via `list($id,$st,$en) = $result;`, **shadowing** the request-level `$st`/`$en`.
- An empty result set prints `No entries found.`

---

## Perl vs PHP

Per [readme_dev.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/readme_dev.txt) (self-flagged "somewhat obsolete as of 12/27/2022"):

- The PHP version is "a **very close port** of the perl version."
- The Perl backend is `perl/recherche.pl` + `perl/cgi-include2.pl`; the entry form is `perl/index.html`. Shebang `#!"C:\xampp\perl\bin\perl.exe"` (XAMPP CGI). Modules sit next to `index.html`, not in `cgi-bin`.
- **The one documented divergence**: the PHP port **drops the `all` option for "Maximum Output."** In [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) the choices are `20 / 50 / 100 / 200 / 500 / 1000` (default 50) and `<option value=1000000>all` is HTML-commented out. The Perl original offered "all".
- Both share the same data path: the SQLite `tamil.sqlite` built from `ganz.txt` via [def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) / [redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat).
- **`en` handling difference**: the original Perl backend appears to perform the Windows-1252→UTF-8 conversion itself (its source comment hedges, "seems to do this conversion on its own"); the PHP port does it inline per row via `iconv` at render time.
- **Cologne origin**: in the upstream Cologne deployment the data is in MySQL and the SQL differs slightly for SQLite; the readme notes the displays are "almost, though not exactly, identical."

---

## Encoding rationale

The `st`/`en` data is **single-byte ASCII Harvard-Kyoto transliteration**, not multibyte Unicode. The HK letter table (from the form):

```
a A i I u U R RR lR lRR e ai o au M H
k kh g gh G c ch j jh J
T Th D Dh N t th d dh n
p ph b bh m y r l v z S s h
```

In this scheme capitals carry meaning: `A` = long ā, `T` = retroflex ṭ, `R` = vocalic ṛ, and `z` (palatal ś) / `S` (retroflex ṣ) / `s` (dental s) are three distinct sibilants. The MW markup `%{…}` may appear in stored text.

Consequences — byte-wise operations are **correct** here:

- `lower()` (SQLite) and `strtolower()` (PHP) operate byte-wise, which is exactly right for ASCII HK — there are no multibyte code points to mishandle.
- `_sqliteRegexp()` calls `preg_match('/'.$pattern.'/i', …)` **without the `/u` (UTF-8) flag**, and this is **correct** for this corpus: with single-byte ASCII data the ASCII `\b` word-boundary anchors behave as intended, and `/u` would be inappropriate. (For Unicode data this would be a latent bug; here it is not.)
- The only non-ASCII bytes are in `en`, handled separately by the Windows-1252→UTF-8 `iconv` at render time — **not** part of the search/matching path.

Note: the `otl` (Tamil) dictionary uses a **different HK scheme** from Sanskrit — palatal n `n^` is written **`jn`**, alveolar n `n_` is written **`n2`**, and the consonant ordering differs (`H k g c ... T N t n p m y r l v z L R`, plus Grantha `j S s h kS`). Both schemes are still single-byte ASCII, so the byte-wise rationale holds regardless. Using the wrong scheme for `otl` yields no hits.

---

## Security model

Hardened on `master` on 2026-06-14. Four defense layers, each escaping at the point of use; the relevant function/branch is named for each. (`sanitize_REQUEST_all()` does **not** contribute — its `FILTER_UNSAFE_RAW` is a no-op.)

| Layer | Class | Function / branch | Fix |
|---|---|---|---|
| Output encoding | Reflected XSS | `fehler($msg)` | `htmlspecialchars($msg, ENT_QUOTES)`. `$msg` can embed user input — e.g. the unknown dictionary code in `dictionary_info`'s `"No dictonary…$dictionary"` — which was reflected unescaped. ([PR #4](https://github.com/sanskrit-lexicon/csl-santam/pull/4)) |
| SQLite-literal escaping | SQL injection | `where1()` (both branches) | Search term escaped for the SQLite string literal via `str_replace("'", "''", …)`: `$x` for the LIKE branch, inside `$xr` for the regexp branches (single-quote → doubled single-quote). ([PR #5](https://github.com/sanskrit-lexicon/csl-santam/pull/5)) |
| `LIMIT` cast | SQL injection | top-level `LIMIT` assembly | `$maxhits` (raw `$_REQUEST`) cast: `" LIMIT " . (int)$maxhits;` before concatenation into `$befehl`. ([PR #6](https://github.com/sanskrit-lexicon/csl-santam/pull/6)) |
| Regex-metachar quoting | Regex injection / ReDoS | `where1()` regexp branches → `_sqliteRegexp()` | The regexp-branch term is `preg_quote($part_l, '/')`d (inside `$xr`) before reaching `_sqliteRegexp`'s `preg_match`, neutralizing PCRE metacharacters and catastrophic-backtracking patterns (e.g. `(a+)+`) that would run per row. The `$wb`/`$we` `\b` anchors are intentionally left active. The **LIKE branch is unchanged**. ([PR #7](https://github.com/sanskrit-lexicon/csl-santam/pull/7)) |

These guards do **not** change end-user search semantics — user-typed regex/SQL metacharacters are now treated as literal text. A fifth, dependency-hygiene PR bumped `dependabot/fetch-metadata` 2→3 ([PR #3](https://github.com/sanskrit-lexicon/csl-santam/pull/3)).

---

## Known quirks / gotchas

1. **"Pali" comment means PAHLAVI.** In `compute_where()` the comment on the `all` branch reads `// 'all', exclude the 4th (Pali dictionary)` with `where = "id<4"`. The "Pali" wording is **wrong**: id 4 is the **Concise Pahlavi Dictionary** (`cpd`), per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) and [readme_dev.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/readme_dev.txt) (which correctly calls id 4 "Pahlavi"/"unused"). The **code behavior** (exclude id 4 from `all`) is correct regardless of the mislabel.

2. **Case-folding over case-semantic HK.** The search lowercases both data (`lower(col)`) and query (`strtolower`), but in Harvard-Kyoto **letter case is semantic**: `A` = long ā, `T` = retroflex ṭ, `R` = vocalic ṛ, `S`/`z` vs `s` = the sibilants, `N`/`G`/`J` vs `n`. Folding case therefore **conflates HK distinctions** — `ata` and `aTa` (exact) match the same lowered string, as do `a`/`A`, `t`/`T`. This is the intentional "not case sensitive" behavior advertised in the form, but it collapses genuine phonemic contrasts; disambiguation must come from surrounding spelling/context, not letter case.

3. **No `/u` flag in `_sqliteRegexp` is correct here** (see [Encoding rationale](#encoding-rationale)) — the corpus is single-byte ASCII HK, so ASCII `\b` boundaries work and `/u` is unwanted. This would become a bug only if the data were ever migrated to Unicode script.

4. **`substring` mode lacks word boundaries.** It matches inside words (e.g. `indra` matches `indriya`), unlike the `\b`-anchored `exact`/`prefix`/`suffix` regexp modes — noisier by design.

5. **Variable reuse.** The result loop rebinds `$id`/`$st`/`$en` from `list($id,$st,$en) = $result;`, shadowing the request-scoped `$st`/`$en` — harmless but a readability trap.

6. **Auto-generated README stub.** The repo's `README.md` is a Cologne tooling-runbook stub (says only "Runtime: Perl", generic 0-open-issue tables); [readme_dev.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/readme_dev.txt) is the better existing source but is self-described as "somewhat obsolete as of 12/27/2022." See [Repository conventions](#repository-conventions) for the de-stubbing rule.

---

## Repository layout (relevant paths)

| Path | Role |
|---|---|
| [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) | PHP search backend (the hardened one) |
| [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) | PHP search form / entry point (POSTs to `recherche.php`) |
| `perl/recherche.pl` + `perl/cgi-include2.pl` | Original Perl CGI backend |
| `perl/index.html` | Perl search form |
| [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) | dict-id → name map |
| `sqlite/ganz.txt` | Source data, tab-delimited (~25 MB) |
| [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) | `tamil` table schema + import |
| [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat) | Rebuild script (XAMPP `sqlite3`) |
| `sqlite/tamil.sqlite` | Built database |
| `CDSL.pdf` | Cologne Digital Sanskrit Lexicon project report |
| `README.md`, `CLAUDE.md`, [readme_dev.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/readme_dev.txt), `LICENSE.md` | Docs |

---

## Repository conventions

Default branch: `master`. Cologne maintainers dislike chatty bot noise — every doc, commit message, and issue comment must be **substantive and factual**, never a motivational recap.

### `.ai_state.md` (session journal)

Per the org `CLAUDE.md`, every repo carries a single tracked `.ai_state.md` as the cross-session journal. It must contain **exactly these section headers, in this order, with the emoji prefixes**:

```
# Project Objective: [Global Goal]
## ➡️ Next Steps (Queue)
## 🚧 Current Work-In-Progress (WIP)
## 🧠 Dev Notes & Hypotheses (Bugs, ideas, context)
## ✅ Completed (Recent only)
```

Check items off as sub-tasks land; on handoff, move finished work to **✅ Completed**, state blockers explicitly, and write concrete **➡️ Next Steps**.

### `CHANGELOG.md`

[CHANGELOG.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/CHANGELOG.md) is a valid [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) file: **newest-first**, with a dated `## [Unreleased]` heading, canonical sections (`### Security`, `### Changed`, …), and each change-bearing entry linking the **full PR URL** as `([PR #N](…))`. The 2026-06-14 hardening pass added the four `### Security` entries (PRs [#4](https://github.com/sanskrit-lexicon/csl-santam/pull/4)–[#7](https://github.com/sanskrit-lexicon/csl-santam/pull/7)) and the `### Changed` Dependabot bump ([#3](https://github.com/sanskrit-lexicon/csl-santam/pull/3)) now at the top of that file — see it for the canonical format. Newer entries are prepended above older ones; never append at the bottom.

### `README.md`

The shipped `README.md` is an auto-generated Cologne tooling-runbook stub (only "Runtime: Perl", plus generic **0-open-issue tables**). Those stale auto-generated issue tables **must be removed** when the README is deepened — replace the stub with real substance (what the tool is, the HK-input rule, how to run the PHP/Perl forms, the four dictionaries, the build via [redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat)). Do not retain the placeholder issue tables.
