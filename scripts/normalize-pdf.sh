#!/bin/sh
set -e

# Re-embed fonts with Identity ordering and ToUnicode CMaps via pdftocairo
# so that PDF.js / editor built-in PDF tabs can render Japanese without external CMap files.

if ! command -v pdftocairo >/dev/null 2>&1; then
  echo "Error: pdftocairo (poppler) is not installed." >&2
  exit 1
fi

normalize_one() {
  f="$1"
  if [ -f "$f" ]; then
    tmp="${f}.cairo.tmp.pdf"
    pdftocairo -pdf "$f" "$tmp"
    mv "$tmp" "$f"
    echo "Normalized PDF for native tab display: $f"
  fi
}

if [ "$#" -gt 0 ]; then
  for arg in "$@"; do
    normalize_one "$arg"
  done
else
  for f in \
    authcite-doc.pdf \
    authcite-test.pdf \
    tests/test_ja.pdf \
    tests/test_en.pdf \
    samples/ipsj/ja/authcite_demo.pdf \
    samples/ipsj/en/authcite_demo_en.pdf \
    samples/ipsj/ja/jsample.pdf \
    samples/ipsj/ja/tech-jsample.pdf \
    samples/ipsj/en/esample.pdf
  do
    normalize_one "$f"
  done
fi
