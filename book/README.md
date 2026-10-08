# Options Tools Book: Publishing & Build Guide

This directory contains the manuscript, graphics generators, and configuration for the **Options Tools Book**.

## Directory Structure

```text
book/
├── README.md               # Build & organization guide (this file)
├── book.toml               # mdBook configuration (math support, themes)
├── SUMMARY.md              # Master outline & linear chapter order
├── chapters/               # Topic content files (decoupled from chapter numbering)
│   ├── options-mechanics.md
│   ├── delta-and-hedging.md
│   └── earnings-iv-crush.md
├── assets/
│   └── figures/            # Generated SVGs and graphics
└── scripts/                # Utility scripts for asset generation
```

---

## 1. Prerequisites: Installing `mdBook`

The book is authored in Markdown and rendered using [`mdBook`](https://rust-lang.github.io/mdBook/).

Install `mdbook` via either method:

### Direct binary download (recommended, no dependencies needed)

```bash
mkdir -p ~/.local/bin
curl -sSL https://github.com/rust-lang/mdBook/releases/download/v0.5.4/mdbook-v0.5.4-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C ~/.local/bin
```

*(Ensure `~/.local/bin` is in your `$PATH`)*

### Via Cargo (if Rust is installed)

```bash
cargo install mdbook
```

---

## 2. One-Command Build Script (`bin/make_book.sh`)

To generate all book graphics and build the complete HTML book into `docs/book/` in one step:

```bash
./bin/make_book.sh
```

---

## 3. Generating Book Graphics Separately (Dart SVG Engine)

Book graphics (such as 2D PnL payoff diagrams) are rendered programmatically using the `PositionAnalyzer` library from `lib/position_analyzer.dart`.

To re-generate only the SVG chart figures in `book/assets/figures/`, run:

```bash
dart run book/scripts/generate_book_assets.dart
```

This guarantees that all diagrams reflect exact position math and breakeven calculations.

---

## 4. Local Preview (Live Reload + Math Support)

To preview the book locally with live reloads on change and instant LaTeX math rendering:

```bash
mdbook serve book --open
```

This opens `http://localhost:3000` in your browser. Any change saved to `SUMMARY.md` or any chapter file immediately refreshes the page.

---

## 5. Building & Publishing Output (`./docs/book/`)

The compiled book output is built to `docs/book/` so that it can be served via GitHub Pages alongside the web application:

```bash
mdbook build book
```

---

## 6. Adding & Reordering Chapters

1. **Create a topic note**: Add a Markdown file in `book/chapters/` named after the topic slug (e.g. `book/chapters/covered-calls.md`), avoiding arbitrary numbering prefixes.
2. **Organize in `SUMMARY.md`**: Add or reorder the link in `book/SUMMARY.md` where you want it to appear in the book's sequence.
3. If new position diagrams are needed, add generation calls in `book/scripts/generate_book_assets.dart`.
