# csl-santam — Sanskrit and Tamil multi-dictionary search

A web-frontend port of the Cologne [MWScan "tamil" multi-dictionary search](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html). A single search form ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)) POSTs to one backend ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)), which queries one combined SQLite table (`tamil(id, st, en)`) spanning four lexica. Two implementations ship side by side: the original Perl CGI and a close PHP port. Maintainer: Thomas Malten, Cologne (th.malten@uni-koeln.de). Default branch: `master`.

The four dictionaries and their entry counts:

| `dictionary` | id | code | Lexicon | Entries | Status |
|---|---|---|---|--:|---|
| Monier-Williams | 1 | `mwd` | Cologne Digital Sanskrit Lexicon (Monier-Williams) | 166,434 | active (default) |
| Capeller | 2 | `cap` | Capeller's Sanskrit-English Dictionary | 37,413 | active |
| Tamil Lexicon | 3 | `otl` | Cologne Online Tamil Lexicon | 117,773 | active |
| Pahlavi | 4 | `cpd` | Concise Pahlavi Dictionary | 4,218 | **disabled** |

`all` searches mwd + cap + otl combined = **321,620** entries (the form advertises "325,838", which counts all four dictionaries including the disabled Pahlavi). The Concise Pahlavi Dictionary (id 4) is present in the data and in [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books), but its `<option value=cpd>` is HTML-commented out of the form and it is excluded from `all` (the SQL filters `id<4`), so it is not reachable through the UI.

---

## Quick start / How to run

This is a classic XAMPP web app (Apache + the bundled `sqlite3`); there is no build step beyond rebuilding the database.

**PHP version (the maintained one):**

1. Serve the repo under XAMPP's Apache (or any PHP-enabled webserver). PHP 8.x with the PDO SQLite driver is required — the backend opens the database via `new PDO('sqlite:…')` and registers a `regexp` UDF at query time.
2. Open the entry point [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) in a browser. The form POSTs to [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php), which reads the request, builds the SQL, queries [sqlite/tamil.sqlite](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/tamil.sqlite), and renders the results.
3. The backend reads `$_REQUEST`, so API clients may also use a GET query string, e.g. `php/recherche.php?dictionary=mwd&st=agni&prst=prefix&maxhits=50`.

**Perl version (original CGI):** `perl/recherche.pl` + `perl/cgi-include2.pl`, with form `perl/index.html`. It runs as an XAMPP CGI (shebang `#!"C:\xampp\perl\bin\perl.exe"`); the modules sit next to `index.html`, not under `cgi-bin`. The PHP port is a very close port of this Perl backend, with one documented divergence: it drops the `all` choice for "Maximum Output." (In the Perl form, "Maximum Output" also offered an unbounded `<option value=1000000>all`, HTML-commented out in the PHP form.)

---

## How it works

Request flow (all in [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)):

1. `sanitize_REQUEST_all()` passes over `$_REQUEST` first (a `FILTER_UNSAFE_RAW` pass-through — it performs no filtering; the real input safety is the escaping at the point of use; see [Security](#security)).
2. `readbooks()` loads [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) via the regex `/^([1-4]) (.*?) (.*)$/` (id, shortcode, fullname); `dictionary_info()` maps the dictionary code to a numeric id (`all` → `0`, `dictname='All dictionaries'`). An unknown code calls `fehler()` and exits.
3. After `trim`, the backend requires at least one of `st`/`en` to have length > 1, otherwise `fehler("No search has been formulated.")`.
4. `compute_where()` sets the dictionary scope (`id<4` for `all`, else `id=$dictnum`) and calls `where1()` per non-empty field. `where1()` splits each field's value on spaces (`preg_split('/ +/', …)`) and AND-joins the words. Match mode per field: `exact`/`prefix`/`suffix` route through a custom SQLite `regexp` UDF (`_sqliteRegexp` → `preg_match('/'.$pattern.'/i', …)`) with `\b` word-boundary anchors; `substring` uses native SQL `LIKE '%…%'`. Matching is case-insensitive via `lower(col)` / `strtolower`.
5. The final query is `SELECT id,st,en FROM tamil WHERE <where> ORDER BY st COLLATE NOCASE LIMIT <(int)maxhits>`, run through `selectfromdb()` (PDO, `ERRMODE_EXCEPTION`), which registers the regexp UDF with `sqliteCreateFunction('regexp', '_sqliteRegexp', 2)`.
6. Each `en` value is re-encoded with `iconv("Windows-1252","UTF-8", …)` before display (the raw `en` bytes are Windows-1252; without this conversion they render as unprintable characters). In `all` mode each row is tagged with its source abbreviation `(mwd)`/`(cap)`/`(otl)` and a legend table is printed above the results (the id-4 Pahlavi line is suppressed). An empty result set prints `No entries found.`

---

## Data & rebuild

The source data is [sqlite/ganz.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/ganz.txt) (~25 MB), a tab-delimited flat file with three fields per line:

```
dict-id <TAB> headword(st) <TAB> entry(en)
```

It is imported into one table `tamil` by [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql):

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

- `id` (INT) — the dictionary id 1–4, doubling as the per-row dictionary tag.
- `st` (VARCHAR 255) — the romanized headword / primary-language term.
- `en` (TEXT) — the English description / entry body.

Rebuild the database with [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat), which deletes the old DB and pipes the schema into the XAMPP-bundled `sqlite3`:

```bat
rm tamil.sqlite
C:\xampp\MercuryMail\sqlite3.exe  tamil.sqlite < def.sql
```

The id → name map lives in [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) and is read at runtime.

---

## Transliteration

Stored data and the backend are **Harvard-Kyoto (HK) single-byte ASCII romanization**, not Unicode Devanagari or Tamil script — e.g. `akAra` (Monier-Williams markup `%{…}` may appear in stored text). In HK, **letter case is semantic** (capitals mark long vowels and retroflex/sibilant distinctions). Since Wave 2, the **form** also accepts Devanagari or IAST for the Sanskrit dictionaries and auto-converts to HK before submit (not for `otl`/Tamil, which uses a different HK-like scheme) — see [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md#client-side-transliteration-input-wave-2).

**Sanskrit HK (mwd, cap):**

```
Vowels:      a A i I u U R RR lR lRR e ai o au   M(anusvāra) H(visarga)
Gutturals:   k kh g gh G
Palatals:    c ch j jh J
Retroflex:   T Th D Dh N
Dentals:     t th d dh n
Labials:     p ph b bh m
Semivowels:  y r l v
Sibilants:   z(ś) S(ṣ) s
Aspirate:    h
```

**Tamil HK (otl)** differs in ordering and a few letters — palatal n is `n^` (ASCII `jn`), alveolar n is `n_` (ASCII `n2`); otherwise type Tamil text as though standard diacritical marks had been dropped:

```
Vowels:      a A i I u U e E ai o O au
Consonants:  H k g c n^/jn T N t n p m y r l v z L R n_/n2
Grantha:     j [C (SRI)] S s h kS
```

> **Case-insensitivity caveat.** Both the data column and the query term are lowercased before matching, so HK case distinctions collapse: `aTa` folds to `ata`, conflating retroflex `T` with dental `t`; `A` (long ā) with `a`; and the three sibilants `z`/`S`/`s` with each other. This is the intentional "not case sensitive" behavior advertised in the form, but it erases genuine phonemic contrasts — disambiguate by spelling/context, not case.

---

## Searching

- `st` searches the romanized **headword** column (Sanskrit for mwd/cap, Tamil for otl).
- `en` searches the **English description** column — use it for reverse / onomasiological lookup (find words whose gloss mentions an English term).
- Four match modes per field (`prst` for `st`, `pren` for `en`): **exact** (`\bTERM\b`), **prefix** (`\bTERM`), **suffix** (`TERM\b`), **substring** (`LIKE '%TERM%'`, no word boundary).
- **AND only.** Multiple words in one field, or both fields filled, are AND-joined — there is no OR and no phrase search; every added term narrows the result set. Multi-word `en` is unordered AND, not a quoted phrase.
- A field needs at least 2 characters; if neither field has more than one character the search is rejected (*"No search has been formulated."*).
- `maxhits` caps the result set (`20 / 50 / 100 / 200 / 500 / 1000`, default 50); there is no pagination or offset, so broad searches truncate at the alphabetically-first N rows (`ORDER BY st COLLATE NOCASE`).

Form request parameters:

| Parameter | Values | Default |
|---|---|---|
| `dictionary` | `mwd` \| `cap` \| `otl` \| `all` | `mwd` |
| `st` | primary-language word(s) in HK | — |
| `prst` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `en` | English word(s), searched in the description | — |
| `pren` | `exact` \| `prefix` \| `suffix` \| `substring` | `exact` |
| `maxhits` | `20` \| `50` \| `100` \| `200` \| `500` \| `1000` | `50` |

**Worked examples:**

| dictionary | st | prst | en | pren | maxhits | Behavior |
|---|---|---|---|---|---|---|
| `mwd` | `akAra` | `exact` | — | — | `50` | Exact MW headword **akAra** (regex `\bakara\b`, case-folded); does not match `akAraNa` or `prAkAra`. |
| `mwd` | `agni` | `prefix` | — | — | `100` | All MW headwords starting `agni`: **agni, agnihotra, agnipurANa, agniSToma, …**. |
| `mwd` | `pati` | `suffix` | — | — | `200` | All MW headwords ending `pati`: **pati, gaNapati, prajApati, bhUpati, …**. |
| `mwd` | `indra` | `substring` | — | — | `100` | MW headwords containing `indra` anywhere (`LIKE '%indra%'`): **indra, devendra, upendra, mahendra, indriya, …** (mid-word, no boundary). |
| `mwd` | — | — | `elephant` | `exact` | `200` | Reverse lookup: MW entries whose gloss contains the whole word "elephant" (**gaja, hastin, nAga, dvipa, …**). |
| `mwd` | `gaja` | `exact` | `elephant` | `exact` | `50` | Both fields → AND: headword `gaja` and gloss contains "elephant". |
| `all` | `nara` | `prefix` | — | — | `500` | Cross-dictionary (`id<4`): headwords starting `nara` from mwd + cap + otl, each row tagged `(mwd)`/`(cap)`/`(otl)`; Pahlavi excluded. |

---

## Encoding rationale (why byte-wise ops are correct here)

Because the `st`/`en` corpus is single-byte ASCII HK transliteration (not multibyte Unicode), the byte-wise operations are intentional and correct:

- `lower()` (SQLite) and `strtolower()` (PHP) fold ASCII correctly — there are no multibyte code points to mishandle.
- `_sqliteRegexp()` calls `preg_match` **without** the `/u` (UTF-8) flag; with single-byte ASCII data the ASCII `\b` word-boundary anchors behave as intended. This would be a latent bug only if the data were ever migrated to Unicode script.
- The only non-ASCII bytes are in `en`, handled separately by the Windows-1252 → UTF-8 `iconv` at render time — not part of the search/matching path.

---

## Known quirks

- **The "Pali" code comment meant Pahlavi — fixed in `0.1.0`.** In `compute_where()` the `all`-branch comment previously read "exclude the 4th (Pali dictionary)"; id 4 is the **Concise Pahlavi Dictionary** (`cpd`), per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books), and the comment now says so. The behavior (excluding id 4 from `all`) was correct throughout.
- **`sanitize_REQUEST_all()` is effectively a no-op** — `FILTER_UNSAFE_RAW` performs no filtering. Input safety comes from the point-of-use escaping in the PR #4–#7 hardening, not from this function.
- **Variable reuse.** The result loop rebinds `$id`/`$st`/`$en` from `list($id,$st,$en) = $result;`, shadowing the request-scoped variables — harmless, but a readability trap.

---

## Security

The PHP backend was hardened on 2026-06-14, escaping user input at the point of use. User-typed SQL and regex metacharacters are now treated as literal text; search semantics are unchanged.

| PR | Class | Fix |
|---|---|---|
| [#4](https://github.com/sanskrit-lexicon/csl-santam/pull/4) | Reflected XSS | `fehler()` error output wrapped in `htmlspecialchars($msg, ENT_QUOTES)` |
| [#5](https://github.com/sanskrit-lexicon/csl-santam/pull/5) | SQL injection | `where1()` search term escaped for the SQLite string literal (`'` → `''`) |
| [#6](https://github.com/sanskrit-lexicon/csl-santam/pull/6) | SQL injection | `maxhits` cast to `(int)` before the `LIMIT` clause |
| [#7](https://github.com/sanskrit-lexicon/csl-santam/pull/7) | Regex injection / ReDoS | regexp-branch term `preg_quote()`d before reaching `_sqliteRegexp` |
| [#3](https://github.com/sanskrit-lexicon/csl-santam/pull/3) | Dependencies | bump `dependabot/fetch-metadata` 2 → 3 |

`0.1.0` also fixed a LIKE-branch predictability gap (not injection): the `substring` branch now backslash-escapes `%`/`_` in the search term and carries an `ESCAPE '\'` clause, so a literal `%`/`_` in an HK query matches itself instead of acting as a wildcard.

See [CHANGELOG.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/CHANGELOG.md) for the running record.

---

## Repository layout

- [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) — PHP search backend (the hardened one).
- [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) — PHP search form / entry point (POSTs to `recherche.php`).
- `perl/recherche.pl` + `perl/cgi-include2.pl` — original Perl CGI backend; `perl/index.html` is its form.
- [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) — dict-id → dictionary name map.
- [sqlite/ganz.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/ganz.txt) — source data, tab-delimited (~25 MB).
- [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) — `tamil` table schema + import.
- [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat) — rebuild script (XAMPP `sqlite3`).
- [sqlite/tamil.sqlite](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/tamil.sqlite) — the built database.
- [CDSL.pdf](https://github.com/sanskrit-lexicon/csl-santam/blob/master/CDSL.pdf) — Cologne Digital Sanskrit Lexicon project report.
- [CLAUDE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/CLAUDE.md) — repo-specific agent guidance.
- [LICENSE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/LICENSE.md) — license.

(`readme_dev.txt` was retired in `0.1.0`; its still-accurate content lives on in [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md).)

---

## Links & contact

- Upstream Cologne search: [MWScan "tamil" multi-dictionary search](http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html)
- Cologne Digital Sanskrit Dictionaries: [sanskrit-lexicon.uni-koeln.de](https://www.sanskrit-lexicon.uni-koeln.de/)
- Project report: [CDSL.pdf](https://github.com/sanskrit-lexicon/csl-santam/blob/master/CDSL.pdf)
- Maintainer: Thomas Malten — th.malten@uni-koeln.de
