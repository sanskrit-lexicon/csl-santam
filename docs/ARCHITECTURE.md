_Created: 14-06-2026 · Last updated: 05-09-2026_

# csl-santam — Architecture

Deep technical reference for the dictionary-search backend of [sanskrit-lexicon/csl-santam](https://github.com/sanskrit-lexicon/csl-santam). Every function name, branch, schema, and string literal below is quoted verbatim from live `master`. Source files are linked inline with full `blob` URLs.

---

## Overview

csl-santam is a web-frontend port of the Cologne **"MWScan tamil"** multi-dictionary search ([uni-koeln MWScan/tamil](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html)). A single search form ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)) POSTs to a single endpoint ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)), which queries **one combined SQLite table** (`tamil`) spanning four lexica.

Two implementations live side by side:

- the original **Perl CGI** backend (`perl/recherche.pl` + `perl/cgi-include2.pl`, form `perl/index.html`), and
- a **close PHP port** ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)) — the hardened, primary implementation documented here.

Maintainer: **Thomas Malten** (`th.malten@uni-koeln.de`), Cologne. Default branch: `master`. Form title: *"Sanskrit and Tamil Dictionaries"*.

The corpus is **Harvard-Kyoto (HK) romanized transliteration in single-byte ASCII** (e.g. `akAra`, with `%{...}` markup), **not** Unicode Devanagari/Tamil script. This single fact drives most of the design decisions below (see [Encoding rationale](#encoding-rationale)). The backend only ever sees HK. Since `0.1.0`+Wave 2, the **form itself** additionally accepts Devanagari or IAST for Sanskrit dictionaries, auto-converting client-side to HK before submit (see [Client-side transliteration input](#client-side-transliteration-input-wave-2)) — direct HK typing keeps working exactly as before.

---

## Data model

### Source file: `sqlite/ganz.txt`

The data lives in `sqlite/ganz.txt` (~25 MB), a tab-delimited flat file with **three fields per line**:

```
dict-id <TAB> headword(st) <TAB> entry(en)
```

### Normalized UTF-8 export: `sqlite/ganz_utf8.txt`

[sqlite/normalize_utf8.py](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/normalize_utf8.py) re-exports `ganz.txt` to `sqlite/ganz_utf8.txt` (Wave 3 migration artifact, [ROADMAP_2026_2027.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ROADMAP_2026_2027.md)):

```
dict-id <TAB> dict-code <TAB> headword(st) <TAB> entry(en)
```

It decodes `st`/`en` from Windows-1252 to UTF-8 (mirroring `recherche.php`'s render-time `iconv("Windows-1252","UTF-8",$en)`, see below) and adds an explicit `mwd`/`cap`/`otl`/`cpd` dict-code column read from [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books). All 325,838 rows decode as valid UTF-8 with zero replacement characters. This export is **additive** — `ganz.txt` and `tamil.sqlite` are untouched, and `recherche.php` still runs its own per-row `iconv()`. It exists for Wave 3's client-side engine (and Wave 4's kosha fold-in) to consume, not as a live-serving change.

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

From `$_REQUEST`: `$dictionary, $st, $prst, $en, $pren, $case_sensitive, $maxhits`. Because the code reads `$_REQUEST`, the form's POST works and a GET query-string also works for API clients (e.g. `recherche.php?dictionary=mwd&st=agni&prst=prefix&maxhits=50`).

| param | values | default |
|-------|--------|---------|
| `dictionary` | `mwd` \| `cap` \| `otl` \| `all` (`cpd` commented out) | `mwd` |
| `st` | primary-language word(s) (Sanskrit/Tamil) in HK | — |
| `prst` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `en` | English word(s), searched in the description | — |
| `pren` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `case_sensitive` | `1` (checkbox; absent when unchecked) | absent → case-insensitive |
| `maxhits` | `20` \| `50` \| `100` \| `200` \| `500` \| `1000` | `50` |

`$case_sensitive` is computed as `isset($_REQUEST['case_sensitive']) && $_REQUEST['case_sensitive'] == '1'` — browsers omit an unchecked checkbox from the request entirely, so a missing key correctly means "off," matching the checkbox's unchecked default.

### c. `readbooks()`

Loads [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) into `$dictbooks` (array of `[num, short, long]`).

### d. `dictionary_info($dictionary, $dictbooks)`

Maps the dictionary code to `($dictnum, $dictname)`:

- `'all'` → `dictnum='0'`, `dictname='All dictionaries'`.
- otherwise linear-scans `$dictbooks` matching `$dictionary` against the shortcode, returning that row's numeric id + full name.
- no match → `fehler("No dictonary has been selected.$dictionary")` (this **exits**).

### e. Empty-query guard

After `trim($st)` / `trim($en)`, if **neither** field has length > 1, `fehler("No search has been formulated.")`. The check is a single OR across both fields: a ≤ 1-char value in one field is **not** rejected on its own — if the other field has length > 1 the search proceeds and the short value is still passed to `where1()` and used in the WHERE clause.

### f. `compute_where($dictnum, $st, $prst, $en, $pren, $case_sensitive=false)`

Builds the WHERE clause:

- dictionary scope: `id<4` when `dictnum=='0'` (the `all` case), else `id=$dictnum`.
- if `$st != ""`: appends `... and ` + `where1($st, 'st', $prst, $case_sensitive)`.
- if `$en != ""`: appends `... and ` + `where1($en, 'en', $pren, $case_sensitive)`.

### g. `where1($var, $varname, $pr, $case_sensitive=false)` — per-field clause builder

This is where match mode and escaping happen:

- `trim`s the value, splits into words on `preg_split('/ +/', $var)` → multiple words in one field are **AND-joined**.
- **Default (case-insensitive):** lowercases the column for matching: `$lowdata = "lower($varname)"`; lowercases each term: `$part_term = strtolower($part)`.
- **Since `0.1.0`+Wave 2, `$case_sensitive=true` (the form's "Case-sensitive search" checkbox):** skips both — `$lowdata = $varname` (raw column), `$part_term = $part` (raw term). Two things beyond that are needed for it to actually take effect (see below): a case-sensitive regexp UDF variant, and `PRAGMA case_sensitive_like`.
- builds two escaped forms of each term (from `$part_term`, whichever case-mode produced it):
  - `$x` — backslash-escapes `%`/`_`/`\` then doubles `'` — for the **LIKE** (substring) branch.
  - `$xr` — `preg_quote($part_term, '/')` then doubles `'` — for the **regexp** branches.
- word-boundary anchors: `$wb = "\\b"`, `$we = "\\b"`.

Match-mode → SQL fragment:

| `$pr` mode | case-insensitive fragment | case-sensitive fragment | engine |
|-----------|--------------------|--------------------|--------|
| `exact` | `(lower(col) regexp '\b{term}\b')` | `(regexp_cs('\b{term}\b', col))` | regexp UDF |
| `prefix` | `(lower(col) regexp '\b{term}')` | `(regexp_cs('\b{term}', col))` | regexp UDF |
| `suffix` | `(lower(col) regexp '{term}\b')` | `(regexp_cs('{term}\b', col))` | regexp UDF |
| `substring` (else) | `(lower(col) like '%{term}%' ESCAPE '\')` | `(col like '%{term}%' ESCAPE '\')` + `PRAGMA case_sensitive_like` | native SQL `LIKE` |

`exact`/`prefix`/`suffix` route through a custom SQLite **`regexp`** function; `substring` uses native **`LIKE '%…%'`**. Multiple terms within a field are chained with ` and `. There is **no OR** anywhere in the query builder — every added word or field tightens the result set.

**Why the case-sensitive fragment uses function-call syntax, not the `REGEXP` operator.** SQLite's `REGEXP` infix operator (`col regexp 'pattern'`) is hardwired to call whatever function is registered under the literal name `regexp` — it cannot be pointed at a second, differently-named function. `col regexp_cs 'pattern'` is a **SQL syntax error** (confirmed empirically). So the case-sensitive path calls the second UDF with ordinary function-call syntax instead: `regexp_cs('pattern', col)`.

### h. Assemble and run the query (top level)

```php
$befehl = "select id,st,en from tamil where $where order by st collate nocase";
$befehl .= " LIMIT " . (int)$maxhits;
$results = selectfromdb($befehl, $case_sensitive);
```

Final SQL shape:

```sql
SELECT id, st, en FROM tamil
WHERE <dict-cond> [AND <st-conds…>] [AND <en-conds…>]
ORDER BY st COLLATE NOCASE LIMIT <(int)maxhits>;
```

`ORDER BY st COLLATE NOCASE` returns the alphabetically-first N rows. There is no pagination and no offset — beyond the cap, raise `maxhits` (≤ 1000) or tighten the query.

### i. `selectfromdb($sql, $case_sensitive=false)`

Opens `../sqlite/tamil.sqlite` via **PDO** (`new PDO('sqlite:'…)`, `ERRMODE_EXCEPTION`), then registers **both** regexp UDF variants:

```php
$file_db->sqliteCreateFunction('regexp', '_sqliteRegexp', 2);
$file_db->sqliteCreateFunction('regexp_cs', '_sqliteRegexpCS', 2);
```

Since `0.1.0`+Wave 2, if `$case_sensitive` is true, it also runs `PRAGMA case_sensitive_like = ON;` before the main query — SQLite's `LIKE` is case-**insensitive** for ASCII by default (verified empirically), independent of any `lower()`/`strtolower()` folding done in the query string itself; this pragma is the only thing that actually makes the `substring` match mode case-sensitive. The pragma is connection-local (this PDO handle is opened fresh per request and never reused), so it can never leak into another request.

Runs `$file_db->query($sql)` and collects each row as `[id, st, en]`. PDO failures route to `fehler(...)`.

### j. `_sqliteRegexp($pattern, $string)` / `_sqliteRegexpCS($pattern, $string)` — the regexp UDFs

The active line in `_sqliteRegexp`:

```php
if (preg_match('/'.$pattern.'/i', $string)) { return true; }
```

Case-insensitive (`/i`), **no `/u` flag** (correct for this corpus — see [Encoding rationale](#encoding-rationale)). A commented alternative `'/^'.$pattern.'$/i'` exists but is not used. This is the engine the `\b` anchors from `where1()` flow into — the word boundary lets a term match a *whole word inside* the `en` entry text, not just the field as a whole.

`_sqliteRegexpCS` (added `0.1.0`+Wave 2) is identical except for the missing `/i` flag — `preg_match('/'.$pattern.'/', $string)` — giving byte-wise case-sensitive matching, called via `where1()`'s `regexp_cs(...)` function-call syntax rather than the `REGEXP` infix operator.

---

## Search semantics (user-facing)

The query builder exposes a small, strict set of behaviors. They follow directly from the pipeline above and are restated here so the architecture is self-complete.

- **Two search axes.** `st` searches the romanized HK headword (Sanskrit for `mwd`/`cap`, Tamil for `otl`); `en` searches the full English entry text (translation, grammar, etymology, and any other listed material). Filling only `en` is a pure **reverse / onomasiological** lookup — find words whose definition mentions an English term.
- **Four match modes, per field** (`prst` for `st`, `pren` for `en`):
  - **exact** → `\bTERM\b` — TERM as a whole bounded word; `akAra` does **not** match `akAraNa` or `prAkAra`.
  - **prefix** → `\bTERM` — a word starting with TERM (e.g. `agni` matches `agni`, `agnihotra`, `agniSToma`).
  - **suffix** → `TERM\b` — a word ending in TERM (e.g. `pati` matches `gaNapati`, `prajApati`).
  - **substring** → `LIKE '%TERM%' ESCAPE '\'` — TERM anywhere, **no** word boundary (e.g. `indra` also matches `indriya`); the loosest, noisiest mode. Since `0.1.0`, a literal `%`/`_`/`\` in TERM is backslash-escaped before it reaches the `LIKE` pattern (`ESCAPE '\'` clause), so a literal `%` in an HK query matches itself instead of silently acting as a wildcard.
- **AND only — no OR, no phrase search.** Multiple words in one field are split on spaces and AND-joined; filling both `st` and `en` AND-joins the two condition blocks; the dictionary `id` scope is ANDed in front. So `en=white elephant` requires *both* whole words "white" and "elephant", in any order (not a phrase). Every added word or field tightens results.
- **Minimum length 2.** The guard is a single OR across both fields — a ≤ 1-char value is **not** ignored per-field; if the other field qualifies, the short value still goes into the query. If neither field has > 1 character the search is rejected with *"No search has been formulated."*
- **Hard result cap, no paging.** `maxhits` ∈ {20, 50, 100, 200, 500, 1000}, default 50, applied as `LIMIT (int)$maxhits`. Since `0.1.0`, a missing/`0`/negative `maxhits` (e.g. from a direct/API caller) defaults to `50` and a value above `1000` clamps to `1000`, mirroring the form's own default/max — this can no longer produce `LIMIT 0` or a SQLite error. Broad searches silently truncate at the cap; rows are ordered `st COLLATE NOCASE`, so you receive the alphabetically-first N. There is no offset.
- **Case-insensitive by default; opt-in case-sensitive since `0.1.0`+Wave 2.** The form's "Case-sensitive search" checkbox (`case_sensitive=1`) skips the `lower()`/`strtolower()` folding, routes `exact`/`prefix`/`suffix` through the `regexp_cs` UDF (no `/i` flag) instead of `regexp`, and sets `PRAGMA case_sensitive_like` for the `substring` `LIKE` branch — see [Request pipeline §g/§i](#request-pipeline) and the HK caveat in [Known quirks](#known-quirks-gotchas).

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

Per the now-retired `readme_dev.txt` (self-flagged "somewhat obsolete as of 12/27/2022"; its still-accurate content is folded in here — see [Repository conventions](#repository-conventions)):

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

## Client-side transliteration input (Wave 2)

[php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) loads two scripts before the form: [php/js/vendor/sanskrit-util.global.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/vendor/sanskrit-util.global.js) (vendored copy of [sanskrit-util](https://github.com/sanskrit-lexicon/sanskrit-util) `v0.3.0`, MIT — the org's canonical IAST⇄SLP1⇄Devanāgarī transcoder, per [SHARED_CODE.md](https://github.com/sanskrit-lexicon/SHARED_CODE.md) family #1) and [php/js/hk-input.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/hk-input.js), a small new glue module. **No backend change** — this is purely client-side; the PHP endpoint still only ever receives HK, exactly as before.

**Reuse, not reinvention.** The SLP1→HK correspondence table in `hk-input.js` is ported verbatim from [kosha/app/transliterate.py](https://github.com/gasyoun/kosha/blob/main/app/transliterate.py)'s `_SLP1_TO_HK` — kosha already solved SLP1→HK for its own (Python, server-side) use. `hk-input.js` reuses that table plus `sanskrit-util`'s `deva_to_slp1`/`to_slp1` for the Deva/IAST→SLP1 leg, so the only genuinely new code is the small amount of JS glue and the scheme-detection policy below.

**Scheme detection deliberately differs from kosha's.** kosha's `detect_scheme()` treats plain ASCII with no diacritics/Devanagari as SLP1 by default, because kosha is SLP1-native — any bare-ASCII text reaching it is assumed to already be an SLP1 key. csl-santam is **HK-native**: its entire existing corpus and UI assume plain-ASCII input already *is* Harvard-Kyoto. Blindly reusing kosha's "bare ASCII → SLP1" assumption here would silently mangle every existing user's HK input (e.g. `guRa`, valid HK, is also a string that parses as SLP1 for a different word). So `hk-input.js`'s `detectScheme()` returns `'hk'` (no-op, pass through unchanged) for any text without genuine Devanagari codepoints (`ऀ`–`ॿ`) or IAST diacritics (`ā ī ū ṛ ṝ ḷ ḹ ṃ ṁ ḥ ṅ ñ ṭ ḍ ṇ ś ṣ ḻ` + capitals) — conversion only fires on those two unambiguous signals.

**Not applied to `otl` (Tamil).** The Cologne Online Tamil Lexicon uses a different HK-like scheme (see [Encoding rationale](#encoding-rationale) above — `jn`/`n2` digraphs, different consonant ordering), which `sanskrit-util` and the ported SLP1→HK table do not model. The wiring script in `index.html` checks the `dictionary` select and skips conversion entirely when `otl` is selected, leaving the Tamil-scheme input the user typed untouched. `hk-input.js` itself is dictionary-agnostic — the skip is the caller's responsibility.

**Wiring.** A small inline script in `index.html` listens for the form's `submit` event, and (unless `otl` is selected) replaces the `st` field's value with `CslSantamHkInput.toHK(value)` just before the request goes out. If either vendored script fails to load, `toHK()` no-ops and returns the original text unchanged — a load failure degrades to "exactly the pre-Wave-2 behavior," never to corrupted input.

**Tested:** a standalone Node harness (12 cases: plain-HK passthrough incl. SLP1-look-alikes, IAST→HK incl. all three sibilants, Devanagari→HK incl. a conjunct, Tamil-script passthrough) — all pass. Live-browser verification was attempted but blocked by a Playwright browser-profile lock in the authoring session; re-verify manually before relying on it in production if that matters.

---

## Security model

Hardened on `master` on 2026-06-14. Four defense layers, each escaping at the point of use; the relevant function/branch is named for each. (`sanitize_REQUEST_all()` does **not** contribute — its `FILTER_UNSAFE_RAW` is a no-op.)

| Layer | Class | Function / branch | Fix |
|---|---|---|---|
| Output encoding | Reflected XSS | `fehler($msg)` | `htmlspecialchars($msg, ENT_QUOTES)`. `$msg` can embed user input — e.g. the unknown dictionary code in `dictionary_info`'s `"No dictonary…$dictionary"` — which was reflected unescaped. ([PR #4](https://github.com/sanskrit-lexicon/csl-santam/pull/4)) |
| SQLite-literal escaping | SQL injection | `where1()` (both branches) | Search term escaped for the SQLite string literal via `str_replace("'", "''", …)`: `$x` for the LIKE branch, inside `$xr` for the regexp branches (single-quote → doubled single-quote). ([PR #5](https://github.com/sanskrit-lexicon/csl-santam/pull/5)) |
| `LIMIT` cast | SQL injection | top-level `LIMIT` assembly | `$maxhits` (raw `$_REQUEST`) cast: `" LIMIT " . (int)$maxhits;` before concatenation into `$befehl`. ([PR #6](https://github.com/sanskrit-lexicon/csl-santam/pull/6)) |
| Regex-metachar quoting | Regex injection / ReDoS | `where1()` regexp branches → `_sqliteRegexp()` | The regexp-branch term is `preg_quote($part_l, '/')`d (inside `$xr`) before reaching `_sqliteRegexp`'s `preg_match`, neutralizing PCRE metacharacters and catastrophic-backtracking patterns (e.g. `(a+)+`) that would run per row. The `$wb`/`$we` `\b` anchors are intentionally left active. ([PR #7](https://github.com/sanskrit-lexicon/csl-santam/pull/7)) |

These guards do **not** change end-user search semantics — user-typed regex/SQL metacharacters are now treated as literal text. A fifth, dependency-hygiene PR bumped `dependabot/fetch-metadata` 2→3 ([PR #3](https://github.com/sanskrit-lexicon/csl-santam/pull/3)).

**`0.1.0` LIKE-branch predictability fix (not a security issue).** The `substring` branch's `LIKE '%TERM%'` previously left `%`/`_` as live SQL wildcards inside a user's TERM — not an injection (the `'` was already doubled), but a correctness/predictability gap: a literal `%` in an HK query silently became a wildcard. `where1()`'s LIKE branch now backslash-escapes `\`, `%`, and `_` in the term before quote-doubling, and the fragment carries an explicit `ESCAPE '\'` clause, so literal `%`/`_` match themselves.

---

## Known quirks / gotchas

1. **"Pali" comment mislabel — fixed.** In `compute_where()` the comment on the `all` branch previously read `// 'all', exclude the 4th (Pali dictionary)` with `where = "id<4"`. Id 4 is the **Concise Pahlavi Dictionary** (`cpd`), per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books); the comment now reads "Pahlavi" (release `0.1.0`). The **code behavior** (exclude id 4 from `all`) was correct throughout — only the comment wording was wrong.

2. **Case-folding over case-semantic HK — now opt-out.** By default the search lowercases both data (`lower(col)`) and query (`strtolower`), but in Harvard-Kyoto **letter case is semantic**: `A` = long ā, `T` = retroflex ṭ, `R` = vocalic ṛ, `S`/`z` vs `s` = the sibilants, `N`/`G`/`J` vs `n`. Folding case therefore **conflates HK distinctions** by default — `ata` and `aTa` (exact) match the same lowered string, as do `a`/`A`, `t`/`T`. This is the "not case sensitive" behavior advertised in the form and remains the default, but since `0.1.0`+Wave 2 the form's **"Case-sensitive search" checkbox** (`case_sensitive=1`) opts out of it entirely — see [Request pipeline §g](#request-pipeline) — so power users who need the HK phonemic distinctions no longer have to rely on surrounding spelling/context alone.

3. **No `/u` flag in `_sqliteRegexp` is correct here** (see [Encoding rationale](#encoding-rationale)) — the corpus is single-byte ASCII HK, so ASCII `\b` boundaries work and `/u` is unwanted. This would become a bug only if the data were ever migrated to Unicode script.

4. **`substring` mode lacks word boundaries.** It matches inside words (e.g. `indra` matches `indriya`), unlike the `\b`-anchored `exact`/`prefix`/`suffix` regexp modes — noisier by design.

5. **Variable reuse.** The result loop rebinds `$id`/`$st`/`$en` from `list($id,$st,$en) = $result;`, shadowing the request-scoped `$st`/`$en` — harmless but a readability trap.

---

## Repository layout (relevant paths)

| Path | Role |
|---|---|
| [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) | PHP search backend (the hardened one) |
| [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) | PHP search form / entry point (POSTs to `recherche.php`) |
| [php/js/hk-input.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/hk-input.js) | Client-side Deva/IAST→HK transcode (Wave 2, no backend change) |
| [php/js/vendor/sanskrit-util.global.js](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/js/vendor/sanskrit-util.global.js) | Vendored [sanskrit-util](https://github.com/sanskrit-lexicon/sanskrit-util) `v0.3.0` browser build (MIT) |
| `perl/recherche.pl` + `perl/cgi-include2.pl` | Original Perl CGI backend |
| `perl/index.html` | Perl search form |
| [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) | dict-id → name map |
| `sqlite/ganz.txt` | Source data, tab-delimited (~25 MB) |
| [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) | `tamil` table schema + import |
| [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat) | Rebuild script (XAMPP `sqlite3`) |
| `sqlite/tamil.sqlite` | Built database |
| `CDSL.pdf` | Cologne Digital Sanskrit Lexicon project report |
| `README.md`, `CLAUDE.md`, `LICENSE.md` | Docs (`readme_dev.txt` retired in `0.1.0` — its content lives on in [Perl vs PHP](#perl-vs-php) and [Repository conventions](#repository-conventions) below) |

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

_Dr. Mārcis Gasūns_
