#!/bin/sh
set -e

# LaTeX / BibTeX execution script for authcite in Docker

TARGET="${1:-test}"

export TEXINPUTS=".:/workspace/src//:${TEXINPUTS:-}"
export BSTINPUTS=".:/workspace/src//:${BSTINPUTS:-}"

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
  echo "=== IPSJ English Sample completed ==="
}

case "$TARGET" in
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
