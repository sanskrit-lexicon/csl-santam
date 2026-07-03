# csl-santam — End-User & API Use Cases

A web-frontend port of the Cologne *"MWScan tamil"* multi-dictionary search. A single search form ([php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html)) POSTs to a single endpoint ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)), which queries **one combined SQLite table** (`tamil(id, st, en)`) spanning four lexica. The data is imported from [sqlite/ganz.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/ganz.txt) (~25 MB, tab-delimited: `dict-id <TAB> headword(st) <TAB> entry(en)`) into the `tamil` table via [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql), rebuilt by [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat).

Form title: *"Sanskrit and Tamil Dictionaries"*. Maintainer: Thomas Malten, th.malten@uni-koeln.de (Cologne). Default branch: `master`.

> **Critical input rule.** All headword input reaches the backend as **Harvard-Kyoto (HK) ASCII romanization**, *not* Unicode Devanagari or Tamil script — the stored data is single-byte ASCII HK (e.g. `akAra`, with `%{...}` markup). Since Wave 2 (`docs/ROADMAP_2026_2027.md`), the **form** additionally accepts Devanagari or IAST for the Sanskrit dictionaries (`mwd`/`cap`/`all`) and auto-converts to HK client-side before submit — see [docs/ARCHITECTURE.md § Client-side transliteration input](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md#client-side-transliteration-input-wave-2). This does **not** apply to `otl` (Tamil) — type its HK-with-exceptions scheme directly. See [Harvard-Kyoto transliteration reference](#harvard-kyoto-transliteration-reference).

There are two implementations sharing the same SQLite data path: the original Perl CGI ([perl/recherche.pl](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/recherche.pl) + [perl/cgi-include2.pl](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/cgi-include2.pl), form [perl/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/index.html)) and a close PHP port (the hardened one). This document describes the PHP port, which is the maintained search backend.

---

## Parameters

Endpoint: `POST` to [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php). The form submits by POST; the backend reads `$_REQUEST`, so a GET query string also works for API clients (e.g. `recherche.php?dictionary=mwd&st=agni&prst=prefix&maxhits=50`).

| Parameter | Form control | Allowed values | Default | Meaning |
|---|---|---|---|---|
| `dictionary` | dropdown | `mwd`, `cap`, `otl`, `all` | `mwd` | Which lexicon to search. `cpd` (Pahlavi) is commented out in the form and unreachable. `all` maps to dictnum `0` → `WHERE id<4`, so `all` = mwd + cap + otl only. |
| `st` | text box | HK word(s); space-separated for multi-word | empty | **Primary-language headword** search (Sanskrit for mwd/cap, Tamil for otl). |
| `prst` | dropdown | `exact`, `prefix`, `suffix`, `substring` | `exact` | Match mode applied to **`st`**. |
| `en` | text box | English word(s); space-separated | empty | **English-description** search (searches the entry/gloss text). |
| `pren` | dropdown | `exact`, `prefix`, `suffix`, `substring` | `exact` | Match mode applied to **`en`**. |
| `case_sensitive` | checkbox | `1` (absent when unchecked) | absent (case-insensitive) | Since `0.1.0`+Wave 2: opt into HK's phonemic letter case (`A`/`a`, `T`/`t`, `S`/`s`/`z` stop conflating) for **both** `st` and `en`. |
| `maxhits` | dropdown | `20`, `50`, `100`, `200`, `500`, `1000` | `50` | Row cap → `LIMIT (int)$maxhits`. (The Perl original also offered `all`; the PHP port dropped it.) |

**Input validation gate.** The backend requires at least one of `st`/`en` to have length > 1 after `trim`; otherwise it returns *"No search has been formulated."* A single-character query in a field is ignored — you must type at least two characters.

**Result row shape.** Each hit prints a 1-based hit number, the headword `st` (bold), and the English entry `en`. When `dictionary=all`, an extra column shows the per-row source abbreviation `(mwd)`/`(cap)`/`(otl)`, and a legend table of abbreviations is printed above the results (the Pahlavi line is suppressed because the form does not expose it). Results are ordered `ORDER BY st COLLATE NOCASE`. The `en` text is re-encoded via `iconv("Windows-1252","UTF-8", …)` before display. An empty result set prints *"No entries found."*

---

## Match modes

Match modes are applied **per field** — `prst` governs `st`, `pren` governs `en`. Internally there are two engines:

- **exact / prefix / suffix** route through a custom SQLite `regexp` UDF (`_sqliteRegexp` → `preg_match('/'.$pattern.'/i', $string)`), with `\b` word-boundary anchors. The user term is `preg_quote`d, so any typed metacharacters are treated as literal text. Both the data column (`lower(col)`) and the term (`strtolower`) are lowercased → **case-insensitive by default**.
- **substring** uses native SQL `LIKE '%term%'` — case-insensitive by default, no word boundaries.
- **Case-sensitive opt-in (`case_sensitive=1`, since `0.1.0`+Wave 2):** skips the lowercasing entirely. `exact`/`prefix`/`suffix` route through a second UDF, `regexp_cs` (same pattern, no `/i` flag) — called as `regexp_cs('pattern', col)` rather than the `col regexp 'pattern'` operator syntax, because SQLite's `REGEXP` operator only ever calls the function literally named `regexp`. `substring` relies on `PRAGMA case_sensitive_like`, since SQLite's `LIKE` is otherwise case-insensitive for ASCII regardless of any lowercasing done in the query.

The `\b` word boundary matters because `en` (and, to a lesser degree, `st`) contains multi-word text; the boundary lets you match a *whole word inside* an entry, not only the field as a whole.

| Mode | Pattern built | Matches when the searched text contains a word that… | HK worked example (field `st`) |
|---|---|---|---|
| **exact** | `\bTERM\b` | equals TERM as a whole word, bounded on both sides | `st=akAra`, `prst=exact` → matches the headword **akAra** as a standalone word; does **not** match `akAraNa` or `prAkAra`. |
| **prefix** | `\bTERM` | begins with TERM | `st=agni`, `prst=prefix` → matches **agni, agnihotra, agnipurANa, agniSToma, …** — every headword starting with `agni`. |
| **suffix** | `TERM\b` | ends with TERM | `st=pati`, `prst=suffix` → matches **pati, gaNapati, prajApati, bhUpati, …** — every headword ending in `pati`. |
| **substring** | `LIKE '%TERM%'` | contains TERM anywhere, no boundary | `st=putra`, `prst=substring` → matches `putra` anywhere inside the headword (no word boundary), e.g. the simplex `putra` and compounds where the literal sequence survives. **HK caveat:** vowel-sandhi spells many compounds away from the simplex (e.g. *deva+indra* is stored `devendra`), so a substring of the simplex form will not find its sandhi'd compounds. |

`substring` is the **loosest** mode (matches inside words, no boundaries); `prefix`/`suffix` anchor one side; `exact` anchors both. For an entry that is itself a single word, `exact` ≈ equality. The per-field words are split on `preg_split('/ +/', …)` and **AND-joined**; multiple regexp/LIKE fragments are chained with ` and `.

---

## Searching by headword vs English description

The two text fields search two different columns and serve two different lookup directions.

- **`st` — primary-language headword.** Searches the `st` column = the romanized HK headword (Sanskrit for mwd/cap, Tamil for otl). Use this when you know the word you are looking up. Type it in HK (e.g. `dharma`, `gaja`, `akAra`).
- **`en` — English description.** Searches the `en` column = the full English entry text. For Monier-Williams this includes the translation, grammatical information, etymology, and any other listed material — the form explicitly states *"You may search for all of it."* Use this as a **reverse / onomasiological** lookup: find Sanskrit or Tamil words whose definition mentions an English term. For example `en=elephant`, `pren=exact` finds entries whose gloss contains the whole word *elephant*.

Leaving `st` empty and filling only `en` is a pure reverse search; the reverse direction is the main reason the `en` field exists. Both fields can also be combined — see below.

---

## Combined / multi-word (AND) queries

The form states: *"If you type words into both fields or several English words then only entries fulfilling all conditions are shown."* Every added term **tightens** the result set — there is **no OR** and **no phrase search** anywhere in the query builder.

- **Multiple words in one field.** The field value is split on spaces (`preg_split('/ +/', …)`) and each word becomes its own condition, **AND-joined**. So `en=white elephant` (with `pren=exact`) requires the entry to contain *both* the whole word *white* *and* the whole word *elephant*, in any order, anywhere in the text. It is **not** a phrase search — *"elephant … white"* also matches.
- **Both fields filled.** The `st` condition block and the `en` condition block are **AND-joined**, on top of the implicit dictionary condition. So `st=gaja` + `en=elephant` returns only entries whose headword matches `gaja` **and** whose description contains *elephant*.
- **Dictionary scope is always ANDed first:** `id=N` for a single dictionary, or `id<4` for `all`.

Final SQL shape:

```sql
SELECT id, st, en FROM tamil
WHERE <dict-cond> [AND <st-conds…>] [AND <en-conds…>]
ORDER BY st COLLATE NOCASE LIMIT <maxhits>;
```

---

## Per-dictionary use cases

The id → name map is [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books).

| `dictionary` | id | Lexicon | Entries | Typical use |
|---|---|---|---|---|
| `mwd` | 1 | Cologne Digital Sanskrit Lexicon (Monier-Williams) | 166,434 | Primary Sanskrit→English lookup; the largest dictionary and the default. The `en` search covers translation, grammatical, and etymological information. |
| `cap` | 2 | Capeller's Sanskrit-English Dictionary | 37,413 | Concise Sanskrit→English; a second opinion against MW. Same HK transliteration as MW. |
| `otl` | 3 | Cologne Online Tamil Lexicon | 117,773 | Tamil headword lookup with English meanings. **Tamil uses a different HK scheme** — see the reference below. |
| `cpd` | 4 | Concise Pahlavi Dictionary | 4,218 | **Disabled** — the `<option value=cpd>` is commented out of the form, and `all` excludes it via `id<4`. Not reachable through the UI. |
| `all` | 0 | mwd + cap + otl | 321,620 | Cross-dictionary search; each result row is tagged `(mwd)`/`(cap)`/`(otl)` and an abbreviation legend is printed. Pahlavi excluded. |

> **Code-comment quirk — fixed in `0.1.0`.** In `compute_where()` the comment on the `all` branch used to call id 4 the *"Pali dictionary"*. Per [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books), id 4 is the **Concise Pahlavi Dictionary** (`cpd`), and the comment now says so. The behavior (excluding id 4 from `all` via `id<4`) was correct throughout.

---

## Harvard-Kyoto transliteration reference

Users must type **Harvard-Kyoto ASCII**, not Unicode script. Two HK schemes apply: one for Sanskrit (`mwd`, `cap`) and a different one for Tamil (`otl`).

### Sanskrit (mwd, cap)

Letter **case is significant** — capitals encode long vowels and retroflex/sibilant distinctions:

```
Vowels:      a A i I u U R RR lR lRR e ai o au   M (anusvāra)  H (visarga)
Gutturals:   k kh g gh G (ṅ)
Palatals:    c ch j jh J (ñ)
Retroflex:   T Th D Dh N
Dentals:     t th d dh n
Labials:     p ph b bh m
Semivowels:  y r l v
Sibilants:   z (ś palatal)   S (retroflex ṣ)   s (dental)
Aspirate:    h
```

So `A` = long ā, `T` = retroflex ṭ, `R` = vocalic ṛ, and `z`/`S`/`s` are the three sibilants. MW markup `%{…}` may appear in stored text.

### Tamil (otl)

The Tamil scheme has a different ordering and a few distinct letters:

```
Vowels:      a A i I u U e E ai o O au
Consonants:  H k g c n^/jn T N t n p m y r l v z L R n_/n2
Grantha:     j  [C (SRI)]  S s h  kS
```

Palatal n (`n^`) is replaced by **`jn`**; alveolar n (`n_`) by **`n2`**. Otherwise, type Tamil text *"as though standard diacritical marks had been dropped."* Using the Sanskrit scheme against `otl` (or vice versa) will yield no hits.

---

## Case-insensitivity

Search is **always case-insensitive**. Both the data column (`lower(col)`) and the query term (`strtolower`) are folded to lowercase before matching — the regex modes via the `/i` flag, the substring mode via `LIKE`.

**HK case caveat — lossy by default, opt-out since `0.1.0`+Wave 2.** In Harvard-Kyoto, *letter case is semantic*: `A` = long ā vs `a` = short a; `T` = retroflex ṭ vs `t` = dental t; `S`/`z` vs `s`; `N`/`G`/`J` vs `n`. By default, after case-folding, these distinctions **collapse**:

- `st=ata` and `st=aTa` (exact) match the **same** rows — both the term and the `lower(st)` column are lowercased, so the retroflex/dental contrast is erased on both sides.
- `st=akAra` is folded to `akara`, so it can also match a stored `akara`-style spelling once both are lowercased.

This is the *"not case sensitive"* design advertised on the form and remains the default, but the form's **"Case-sensitive search" checkbox** (`case_sensitive=1`) now opts out of it entirely — `st=aTa` with case-sensitive checked matches only `aTa`, not `ata`. Without the checkbox, disambiguation still relies on the surrounding spelling and context, not letter case.

*(Implementation note: `_sqliteRegexp` omits the PCRE `/u` flag. This is correct here — the data is single-byte ASCII HK, so the ASCII `\b` word boundaries behave as intended. It would only be a latent bug if the corpus were ever migrated to Unicode script.)*

---

## Limits & caveats

1. **HK input only — no Unicode script.** You cannot type or paste Devanagari or Tamil script; everything is romanized HK ASCII. Two HK schemes apply (Sanskrit vs Tamil); using the wrong one for a dictionary yields no hits.
2. **Case-folding conflates HK distinctions by default** — retroflex vs dental, long vs short vowel, and the three sibilants all collapse. Since `0.1.0`+Wave 2 you can force a case-sensitive HK match with the "Case-sensitive search" checkbox (`case_sensitive=1`).
3. **Pahlavi (`cpd`) unavailable** — disabled in the form and excluded from `all` (`id<4`). Only mwd, cap, and otl are searchable.
4. **AND-only — no OR, no phrase search.** Every extra word or field narrows results; multi-word `en` is unordered AND, not a quoted phrase.
5. **Hard result cap, no paging.** `maxhits` ≤ 1000, applied as `LIMIT (int)$maxhits`; there is no pagination or offset. Broad searches truncate silently, returning the alphabetically-first N rows (`ORDER BY st COLLATE NOCASE`). To see more, raise `maxhits` (max 1000) or tighten the query.
6. **Minimum length 2.** A field with ≤ 1 character is ignored; if neither field has > 1 character, the search is rejected with *"No search has been formulated."*
7. **`substring` lacks word boundaries** — it matches inside longer words, which can be noisy; use `exact`/`prefix`/`suffix` for word-anchored matches.
8. **`en` encoding edge cases** — the `en` text is force-decoded as Windows-1252 → UTF-8 at display time. The PHP port notes this as a workaround pending a one-time re-import of `ganz.txt`.

---

## Worked examples

Each row gives the exact form-field values and the expected behavior. For an API client, the same values work as a query string on [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php).

| # | `dictionary` | `st` | `prst` | `en` | `pren` | `maxhits` | Expected behavior |
|---|---|---|---|---|---|---|---|
| 1 | `mwd` | `akAra` | `exact` | — | — | `50` | Exact MW headword **akAra**. Regex `\bakara\b` (case-folded). Returns the headword entry; does **not** return `akAraNa`. |
| 2 | `mwd` | `agni` | `prefix` | — | — | `100` | All MW headwords starting with `agni`: **agni, agnihotra, agnipurANa, agniSToma, …**. Alphabetically ordered, truncated at 100. |
| 3 | `mwd` | `pati` | `suffix` | — | — | `200` | All MW headwords ending in `pati`: **pati, gaNapati, prajApati, bhUpati, …** (`pati\b`). |
| 4 | `mwd` | `indra` | `substring` | — | — | `100` | MW headwords whose stored string literally contains `indra` (`LIKE '%indra%'`). **HK caveat:** Sanskrit vowel-sandhi spells most *indra*-compounds with `-endra` (e.g. *devendra*, *mahendra*) and `indriya` as `indri-`, so a substring `indra` matches the simplex `indra` but **not** those — an illustration of how substring search over HK can surprise you. |
| 5 | `mwd` | — | — | `elephant` | `exact` | `200` | Reverse lookup: MW entries whose **description** contains the whole word *elephant* — e.g. **gaja, hastin, nAga, dvipa, …**. Demonstrates the `en` field. |
| 6 | `mwd` | `gaja` | `exact` | `elephant` | `exact` | `50` | **Both fields → AND.** Only the entry whose headword is **gaja** *and* whose gloss contains *elephant*. Intersects headword + meaning. |
| 7 | `mwd` | — | — | `white elephant` | `exact` | `50` | **Multi-word `en` → AND, unordered.** Entries whose description contains *both* *white* and *elephant*, in any order — not a phrase. |
| 8 | `otl` | `amma` | `prefix` | — | — | `50` | **Tamil dictionary.** Online Tamil Lexicon headwords beginning with `amma` (Tamil HK scheme; `amma` uses no special Tamil letters, so it is a plain prefix match). Returns Tamil entries with English meanings. |
| 9 | `cap` | `dharma` | `exact` | — | — | `20` | Capeller's concise dictionary: exact Sanskrit headword **dharma**. Smaller corpus — useful as a second opinion against MW. |
| 10 | `all` | `nara` | `prefix` | — | — | `500` | **Cross-dictionary** (`id<4`): headwords starting with `nara` from mwd + cap + otl, each row tagged `(mwd)`/`(cap)`/`(otl)` with an abbreviation legend. Pahlavi excluded. |
| 11 | `mwd` | `aTa` | `exact` | — | — | `50` | **Case-folding caveat (default, `case_sensitive` unchecked).** Both the query term and the `lower(st)` column fold to `ata`, so headwords stored as either `ata` or `aTa` collapse to the same key and are returned indistinguishably — the retroflex/dental contrast is lost. Check "Case-sensitive search" to get only `aTa`. |
| 12 | `all` | — | — | `king sovereign` | `prefix` | `1000` | Reverse multi-word AND across all three dictionaries: entries whose gloss has a word starting *king* **and** a word starting *sovereign* (royalty/ruler terms), capped at 1000. |

---

## Security note (context)

The backend was hardened on 2026-06-14. These fixes do **not** change end-user search semantics — user-typed regex or SQL metacharacters are now treated as literal text:

- Reflected XSS in `fehler()` → `htmlspecialchars($msg, ENT_QUOTES)` — [PR #4](https://github.com/sanskrit-lexicon/csl-santam/pull/4).
- SQL injection via the search term → single-quote doubling (`'` → `''`) in `where1()` — [PR #5](https://github.com/sanskrit-lexicon/csl-santam/pull/5).
- SQL injection via `maxhits` → `(int)` cast on the `LIMIT` clause — [PR #6](https://github.com/sanskrit-lexicon/csl-santam/pull/6).
- Regex injection / ReDoS → `preg_quote()` on the regexp-branch term before it reaches `_sqliteRegexp` (the `LIKE` branch is unchanged) — [PR #7](https://github.com/sanskrit-lexicon/csl-santam/pull/7).

---

## Source files

- [php/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/index.html) — the PHP search form / entry point (POSTs to `recherche.php`).
- [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php) — the PHP search backend (the hardened one).
- [perl/recherche.pl](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/recherche.pl) + [perl/cgi-include2.pl](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/cgi-include2.pl) — the original Perl CGI backend; form [perl/index.html](https://github.com/sanskrit-lexicon/csl-santam/blob/master/perl/index.html).
- [dat/books](https://github.com/sanskrit-lexicon/csl-santam/blob/master/dat/books) — dictionary-id → name map.
- [sqlite/ganz.txt](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/ganz.txt) — source data, tab-delimited (~25 MB).
- [sqlite/def.sql](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/def.sql) — `tamil` table schema and import.
- [sqlite/redo.bat](https://github.com/sanskrit-lexicon/csl-santam/blob/master/sqlite/redo.bat) — database rebuild script (XAMPP `sqlite3`).
- [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md) — deep technical reference (`readme_dev.txt` was retired in `0.1.0`; its content lives on here).
