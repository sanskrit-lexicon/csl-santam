# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**csl-santam** is the "Sanskrit and Tamil Dictionaries" web application, originally created c. 2003 by Thomas Malten (data) and Kira Stöwe (display). It provides a searchable interface to several Sanskrit-Tamil dictionary datasets.

Deployed at: `http://www.sanskrit-lexicon.uni-koeln.de/scans/MWScan/tamil/index.html`

The application runs as a PHP web application on Apache/XAMPP.

## Architecture

| Directory/File | Purpose |
|---|---|
| `dat/` | Raw dictionary data files |
| `sqlite/` | SQLite database files for the dictionary data |
| `php/` | PHP scripts for the web interface |
| `perl/` | Legacy Perl CGI scripts (earlier version) |
| `CDSL.pdf` | Documentation PDF |
| `readme_dev.txt` | Developer setup notes |

### Installation (XAMPP/Windows)

1. Clone this repo (~22 MB) into `C:\xampp\htdocs\cologne\csl-santam\`
2. Access via `http://localhost/cologne/csl-santam/`

## Dependencies

- **PHP** (CLI + PDO + SQLite3 drivers)
- **Apache/XAMPP** for local development
