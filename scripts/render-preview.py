#!/usr/bin/env python3
"""
Render Japanese/English PDF files into a self-contained interactive HTML viewer.
Uses pdftoppm + cwebp (or PNG fallback) + pdftotext to preserve Japanese fonts
(such as HaranoAji) without requiring external CMap files in PDF.js.
"""

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_DOCS = [
    {
        "path": "authcite-doc.pdf",
        "title": "authcite 取扱説明書兼サンプル文書",
        "category": "1. メイン文書",
        "dpi": 160,
    },
    {
        "path": "authcite-test.pdf",
        "title": "authcite 動作確認テスト",
        "category": "1. メイン文書",
        "dpi": 160,
    },
    {
        "path": "tests/test_ja.pdf",
        "title": "日本語環境テスト (test_ja)",
        "category": "2. テストスイート",
        "dpi": 160,
    },
    {
        "path": "tests/test_en.pdf",
        "title": "英語環境テスト (test_en)",
        "category": "2. テストスイート",
        "dpi": 160,
    },
    {
        "path": "samples/ipsj/ja/authcite_demo.pdf",
        "title": "情報処理学会スタイル 日本語デモ (authcite_demo)",
        "category": "3. 情報処理学会 (IPSJ) サンプル",
        "dpi": 160,
    },
    {
        "path": "samples/ipsj/en/authcite_demo_en.pdf",
        "title": "情報処理学会スタイル 英語デモ (authcite_demo_en)",
        "category": "3. 情報処理学会 (IPSJ) サンプル",
        "dpi": 160,
    },
    {
        "path": "samples/ipsj/ja/jsample.pdf",
        "title": "IPSJ 論文誌執筆案内（日本語サンプル）",
        "category": "3. 情報処理学会 (IPSJ) サンプル",
        "dpi": 110,
        "quality": 78,
    },
    {
        "path": "samples/ipsj/ja/tech-jsample.pdf",
        "title": "IPSJ 研究報告執筆案内（日本語サンプル）",
        "category": "3. 情報処理学会 (IPSJ) サンプル",
        "dpi": 110,
        "quality": 78,
    },
    {
        "path": "samples/ipsj/en/esample.pdf",
        "title": "IPSJ 論文誌執筆案内（英語サンプル）",
        "category": "3. 情報処理学会 (IPSJ) サンプル",
        "dpi": 110,
        "quality": 78,
    },
]


def format_size(num_bytes: int) -> str:
    if num_bytes < 1024:
        return f"{num_bytes} B"
    kb = num_bytes / 1024.0
    if kb < 1024:
        return f"{kb:.1f} KB"
    return f"{kb / 1024.0:.2f} MB"


def page_number_key(filename: str) -> int:
    m = re.search(r"-(\d+)\.[a-zA-Z0-9]+$", filename)
    return int(m.group(1)) if m else 0


def extract_page_text(pdf_path: Path, page_num: int, has_pdftotext: bool) -> str:
    if not has_pdftotext:
        return ""
    try:
        out = subprocess.check_output(
            [
                "pdftotext",
                "-f",
                str(page_num),
                "-l",
                str(page_num),
                str(pdf_path),
                "-",
            ],
            stderr=subprocess.DEVNULL,
        )
        return out.decode("utf-8", errors="replace").strip()
    except Exception:
        return ""


def render_pdf_entry(
    repo_root: Path,
    rel_path: str,
    title: str,
    category: str,
    dpi: int,
    quality: int,
    has_cwebp: bool,
    has_pdftotext: bool,
) -> dict | None:
    pdf_path = (repo_root / rel_path).resolve()
    if not pdf_path.is_file():
        return None

    file_size = pdf_path.stat().st_size
    pages_data = []

    with tempfile.TemporaryDirectory() as tmpdir:
        prefix = os.path.join(tmpdir, "page")
        subprocess.check_call(
            ["pdftoppm", "-png", "-r", str(dpi), str(pdf_path), prefix],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        png_files = sorted(
            [
                f
                for f in os.listdir(tmpdir)
                if f.startswith("page-") and f.endswith(".png")
            ],
            key=page_number_key,
        )

        for idx, png_name in enumerate(png_files):
            page_num = idx + 1
            png_full = os.path.join(tmpdir, png_name)
            mime = "image/png"
            target_file = png_full

            if has_cwebp:
                webp_full = png_full + ".webp"
                try:
                    subprocess.check_call(
                        ["cwebp", "-q", str(quality), png_full, "-o", webp_full],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    if os.path.isfile(webp_full):
                        target_file = webp_full
                        mime = "image/webp"
                except Exception:
                    pass

            with open(target_file, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("ascii")

            text = extract_page_text(pdf_path, page_num, has_pdftotext)
            pages_data.append(
                {
                    "image": f"data:{mime};base64,{b64}",
                    "text": text,
                }
            )

    return {
        "title": title,
        "path": rel_path,
        "category": category,
        "sizeLabel": format_size(file_size),
        "pages": pages_data,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build self-contained Japanese PDF Viewer HTML."
    )
    parser.add_argument(
        "extra_pdfs",
        nargs="*",
        help="Additional PDF file paths to include in the viewer.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="pdf-viewer.html",
        help="Output HTML file path (default: pdf-viewer.html).",
    )
    parser.add_argument(
        "--sync",
        action="append",
        default=[],
        help="Additional output path(s) to copy the generated HTML to.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=0,
        help="Override rendering DPI for all documents.",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    template_path = script_dir / "pdf-viewer-template.html"

    if not template_path.is_file():
        print(f"Error: Template not found at {template_path}", file=sys.stderr)
        return 1

    if not shutil.which("pdftoppm"):
        print(
            "Error: 'pdftoppm' (poppler) is required to render PDF pages.",
            file=sys.stderr,
        )
        return 1

    has_cwebp = shutil.which("cwebp") is not None
    has_pdftotext = shutil.which("pdftotext") is not None

    docs_to_process = list(DEFAULT_DOCS)
    seen_paths = {d["path"] for d in docs_to_process}

    # Add any user-supplied extra PDFs
    for extra in args.extra_pdfs:
        p = Path(extra)
        try:
            rel = str(p.resolve().relative_to(repo_root))
        except ValueError:
            rel = str(p)
        if rel not in seen_paths:
            seen_paths.add(rel)
            docs_to_process.insert(
                0,
                {
                    "path": rel,
                    "title": p.stem,
                    "category": "0. 指定ファイル",
                    "dpi": 160,
                },
            )

    catalog = []
    for entry in docs_to_process:
        dpi = args.dpi if args.dpi > 0 else entry["dpi"]
        rel_path = entry["path"]
        full_candidate = (
            Path(rel_path)
            if os.path.isabs(rel_path)
            else (repo_root / rel_path)
        )
        if not full_candidate.is_file():
            continue

        print(f"Rendering {rel_path} ({dpi} DPI)...")
        doc_obj = render_pdf_entry(
            repo_root=repo_root,
            rel_path=rel_path,
            title=entry["title"],
            category=entry["category"],
            dpi=dpi,
            quality=entry.get("quality", 88),
            has_cwebp=has_cwebp,
            has_pdftotext=has_pdftotext,
        )
        if doc_obj and doc_obj["pages"]:
            catalog.append(doc_obj)

    if not catalog:
        print("Error: No PDF files found to render.", file=sys.stderr)
        return 1

    template_html = template_path.read_text(encoding="utf-8")
    catalog_json = json.dumps(catalog, ensure_ascii=False)
    output_html = template_html.replace("__PDF_CATALOG_JSON__", catalog_json)

    out_path = Path(args.output)
    if not out_path.is_absolute():
        out_path = repo_root / out_path
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(output_html, encoding="utf-8")
    print(f"Generated viewer: {out_path} ({format_size(out_path.stat().st_size)})")

    for sync_target in args.sync:
        sync_path = Path(sync_target)
        sync_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(out_path, sync_path)
        print(f"Synced viewer to: {sync_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
