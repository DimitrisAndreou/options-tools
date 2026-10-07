# Options Tools Book: Publishing & Build Guide

This directory contains the manuscript, graphics generators, and configuration for the **Options Tools Book**.

## Directory Structure

```text
book/
├── README.md               # Build instructions (this file)
├── chapters/
│   ├── 01_introduction.md  # Chapter 1
│   └── 02_second_chapter.md# Chapter 2
├── assets/
│   └── figures/            # Generated SVGs and graphics
└── scripts/                # Utility scripts for asset generation
```

---

## 1. Generating Book Graphics (Dart SVG Engine)

Book graphics (such as 2D PnL payoff diagrams) are rendered programmatically using the `PositionAnalyzer` library from `lib/position_analyzer.dart`.

To re-generate all SVG chart figures in `book/assets/figures/`, run:

```bash
dart run bin/generate_book_assets.dart
```

This guarantees that all diagrams reflect exact position math and breakeven calculations.

---

## 2. Building & Publishing Output (`./docs/book/`)

The compiled book output is designed to be published to `docs/book/` so that it can be served via GitHub Pages alongside the web application.

### Option A: Using Quarto (Recommended for PDF + HTML + EPUB)

If [Quarto](https://quarto.org/) is installed:

```bash
# Render to HTML web book inside docs/book/
quarto render book/ --output-dir ../docs/book

# Render to standalone PDF
quarto render book/ --to pdf
```

### Option B: Using mdBook

If [`mdbook`](https://rust-lang.github.io/mdBook/) is installed:

```bash
mdbook build book -d ../docs/book
```

---

## 3. Adding New Chapters

To add a new chapter:
1. Create a new Markdown file in `book/chapters/` (e.g. `03_covered_calls.md`).
2. Add any position graphic generation calls in `bin/generate_book_assets.dart` if new diagrams are needed.
3. Link the chapter in your book TOC / renderer config.
