---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ui-engineer
---

# PDF, preview and print: Typst as a library; print through the webview dialog

## Context and Problem Statement

Invoices and the other sales documents need PDFs for email and download, an in-app preview, and printing on all three OSes, without shelling out (I-13) and without HTML-to-PDF browser engines. Report screens only need printing.

## Decision Drivers

* Pure Rust, deterministic output (golden tests).
* Professional typography and templates that are data, not code.
* One renderer for PDF and on-screen preview.

## Considered Options

* Typst 0.15 as a library (templates in `crates/render/templates/`, embedded fonts) → PDF and SVG pages
* krilla or printpdf with hand-built layout
* HTML to PDF through a headless browser

## Decision Outcome

Chosen option: **Typst**.

* `render` builds a `typst::World` with embedded fonts (no system font scan in tests) and the template, plus a JSON data file generated from the document.
* It compiles to PDF (`typst-pdf`) for download and email, and to SVG pages (`typst-svg`) for the in-app preview.
* Printing renders the SVG pages in a print stylesheet and calls the webview's print dialog. "Save as PDF" downloads the Typst PDF.

### Consequences

* Good, because layout lives in templates contributors can edit, and output is identical on every OS.
* Bad, because Typst adds compile time to the `render` crate. That is isolated: only `render`, `app`, `cli` and `desktop` build it.
* Bad, because macOS printing from WKWebView needs checking at the Windows and macOS release milestone (ROADMAP).

### Confirmation

Spike W0-06 criterion 7 (print through the GTK dialog). W4-04: golden tests compare PDF text extraction and page count, and SVG snapshots.

## Pros and Cons of the Options

### Typst

* Good, because it gives typesetting quality, templates as data, and both PDF and SVG output.

### krilla or printpdf

* Bad, because layout code would be hand-built and hard to change.

### HTML to PDF

* Bad, because it needs a browser engine process (shelling out or a heavy dependency).

## More Information

typst 0.15.1 (Apache-2.0), ADR-0019.
