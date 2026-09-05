_Created: 03-07-2026 · Last updated: 05-09-2026_

# Security policy

csl-santam is a PHP/Perl web frontend ([php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php)) that accepts untrusted search input and queries a local SQLite database. The principal security concerns are:

1. **Injection at the search endpoint** — SQL injection, reflected XSS, and regex injection/ReDoS via the `dictionary`/`st`/`en`/`maxhits` request parameters. These were the subject of a hardening pass landed `2026-06-14` (PRs [#4](https://github.com/sanskrit-lexicon/csl-santam/pull/4)–[#7](https://github.com/sanskrit-lexicon/csl-santam/pull/7); see [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md#security-model) for the full model).
2. **Supply-chain risk** in CI dependencies (currently just the `dependabot/fetch-metadata` GitHub Action).
3. **Credential leakage** in committed files.

**Current automated scanning:** Dependabot is configured (`.github/dependabot.yml`, auto-merge workflow). GitHub code scanning (CodeQL) has **no PHP or Perl analyzer** and would scan nothing in this repo, so it is deliberately not deployed here (the same gap that motivated `csl-websanlexicon`'s Semgrep adoption). Instead, [`.github/workflows/semgrep.yml`](https://github.com/sanskrit-lexicon/csl-santam/blob/master/.github/workflows/semgrep.yml) runs Semgrep's `p/php` + `p/security-audit` rulesets (advisory, uploads SARIF to the Security tab) against [php/recherche.php](https://github.com/sanskrit-lexicon/csl-santam/blob/master/php/recherche.php), the hardened primary implementation.

## Reporting a vulnerability

Please do **not** open a public GitHub issue for security-sensitive reports. Instead:

- Email the maintainer, Thomas Malten (`th.malten@uni-koeln.de`), or
- Contact `@gasyoun` directly via GitHub.

We will acknowledge within five working days and triage privately.

## Out of scope

- Bug reports about display rendering, broken links, or character-encoding glitches in dictionary entries — please use the regular issue tracker with the appropriate type label.
- Concerns about dictionary content (typos, mistranslations, scholarly disagreement) — these are *editorial* matters, not security; please open a normal `text-correction` or `question` issue.
- The intentional case-folding of Harvard-Kyoto input (documented in [docs/ARCHITECTURE.md](https://github.com/sanskrit-lexicon/csl-santam/blob/master/docs/ARCHITECTURE.md#known-quirks-gotchas)) — this is a search-semantics design choice, not a vulnerability.

## Licence

This security policy itself is licensed CC BY 4.0.

_Dr. Mārcis Gasūns_
