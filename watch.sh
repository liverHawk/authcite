#!/bin/sh
set -e

# LaTeX / BibTeX execution script for authcite in Docker

TARGET="${1:-test}"

export TEXINPUTS=".:/workspace/src//:${TEXINPUTS:-}"
export BSTINPUTS=".:/workspace/src//:${BSTINPUTS:-}"

normalize_pdf() {
  PDF_FILE="$1"
  if [ -f "$PDF_FILE" ] && command -v pdftocairo >/dev/null 2>&1; then
    pdftocairo -pdf "$PDF_FILE" "${PDF_FILE}.tmp" && mv "${PDF_FILE}.tmp" "$PDF_FILE"
  fi
}

run_doc() {
  echo "=== Building Root Docs (authcite-doc & authcite-test) ==="
  cd /workspace
  uplatex -interaction=nonstopmode authcite-doc.tex || true
  upbibtex authcite-doc
  uplatex -interaction=nonstopmode authcite-doc.tex
  uplatex -interaction=nonstopmode authcite-doc.tex
  dvipdfmx authcite-doc.dvi
  normalize_pdf authcite-doc.pdf

  uplatex -interaction=nonstopmode authcite-test.tex || true
  upbibtex authcite-test
  uplatex -interaction=nonstopmode authcite-test.tex
  uplatex -interaction=nonstopmode authcite-test.tex
  dvipdfmx authcite-test.dvi
  normalize_pdf authcite-test.pdf
  echo "=== Root Docs completed ==="
}

run_test() {
  echo "=== Running Tests (tests/) ==="
  cd /workspace/tests

  echo "--- 1st LaTeX pass (test_ja) ---"
  uplatex -interaction=nonstopmode test_ja.tex || true

  echo "--- BibTeX pass (test_ja) ---"
  upbibtex test_ja

  echo "--- 2nd LaTeX pass (test_ja) ---"
  uplatex -interaction=nonstopmode test_ja.tex

  echo "--- 3rd LaTeX pass (test_ja) ---"
  uplatex -interaction=nonstopmode test_ja.tex

  echo "--- DVI to PDF (test_ja) ---"
  dvipdfmx test_ja.dvi
  normalize_pdf test_ja.pdf

  echo "--- 1st LaTeX pass (test_en) ---"
  uplatex -interaction=nonstopmode test_en.tex || true

  echo "--- BibTeX pass (test_en) ---"
  upbibtex test_en

  echo "--- 2nd LaTeX pass (test_en) ---"
  uplatex -interaction=nonstopmode test_en.tex

  echo "--- 3rd LaTeX pass (test_en) ---"
  uplatex -interaction=nonstopmode test_en.tex

  echo "--- DVI to PDF (test_en) ---"
  dvipdfmx test_en.dvi
  normalize_pdf test_en.pdf

  echo "=== Tests completed successfully ==="
}

run_ja() {
  echo "=== Building IPSJ Japanese Sample ==="
  cd /workspace/samples/ipsj/ja
  platex -interaction=nonstopmode authcite_demo.tex || true
  pbibtex authcite_demo
  platex -interaction=nonstopmode authcite_demo.tex
  platex -interaction=nonstopmode authcite_demo.tex
  dvipdfmx authcite_demo.dvi
  normalize_pdf authcite_demo.pdf
  echo "=== IPSJ Japanese Sample completed ==="
}

run_en() {
  echo "=== Building IPSJ English Sample ==="
  cd /workspace/samples/ipsj/en
  platex -interaction=nonstopmode authcite_demo_en.tex || true
  pbibtex authcite_demo_en
  platex -interaction=nonstopmode authcite_demo_en.tex
  platex -interaction=nonstopmode authcite_demo_en.tex
  dvipdfmx authcite_demo_en.dvi
  normalize_pdf authcite_demo_en.pdf
  echo "=== IPSJ English Sample completed ==="
}

case "$TARGET" in
  doc)
    run_doc
    ;;
  test)
    run_test
    ;;
  ja)
    run_ja
    ;;
  en)
    run_en
    ;;
  all)
    run_doc
    run_test
    run_ja
    run_en
    ;;
  watch)
    echo "Starting in watch mode..."
    run_test
    if command -v inotifywait >/dev/null 2>&1; then
      while true; do
        inotifywait -r -e modify,create,delete /workspace/src /workspace/tests /workspace/samples
        run_test || true
      done
    else
      echo "inotifywait not found; sleeping..."
      while true; do sleep 3600; done
    fi
    ;;
  *)
    exec "$@"
    ;;
esac
