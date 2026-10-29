# authcite

`\cite` の直前に筆頭著者名等を自動付与し、「Hosseini[4]」「Duら[1]」「Du et al. [1]」「DuとGu[1]」のように出力する LaTeX パッケージおよび BibTeX スタイルファイルです。

---

## 目的

学術論文や技術文書において、「Hosseini[1]によれば」「Duら[2]の研究では」のように著者名を添えて引用する際、以下のような課題があります：
- 著者数（1人、2人、3人以上）に応じた「ら」や「et al.」の付け分けを手動で行うとミスや表記揺れが発生する。
- 論文誌の規定（2名共著は「DuとGu」のように連記する等）に合わせた表記修正に手間がかかる。

`authcite` は BibTeX（`.bbl`）から著者数と姓（筆頭著者・第2著者）を自動抽出し、統一されたルールで出力します。

---

## パッケージ構成

```text
authcite/
├── authcite.sty        # パッケージ本体（必須）
├── authcite.bst        # BibTeX スタイルファイル（必須）
├── README.md           # 本書（使い方・目的・インストール方法）
├── LICENSE             # ライセンス（MIT License）
├── authcite-doc.tex    # ドキュメント兼サンプル文書
└── authcite-test.tex   # 動作確認用テスト
```

※ 情報処理学会論文誌用の追加スタイルファイル（`authcite-ipsjunsrt.bst`, `authcite-ipsjunsrt-e.bst`）は `src/` ディレクトリ内に同梱されています。

---

## インストール方法

### 方法 A: プロジェクトごとに直接配置する（最も手軽）
1. `authcite.sty` および `authcite.bst` を、作成する `.tex` 文書と同じディレクトリにコピーします。

### 方法 B: TeX システム（TeX Live 等）のユーザーディレクトリに配置する
全プロジェクトで共通して利用したい場合は、`TEXMFHOME`（通常 `~/texmf`）に配置します：
```bash
# スタイルファイル (.sty) の配置
mkdir -p $(kpsewhich -var-value TEXMFHOME)/tex/latex/authcite
cp authcite.sty $(kpsewhich -var-value TEXMFHOME)/tex/latex/authcite/

# BibTeX スタイル (.bst) の配置
mkdir -p $(kpsewhich -var-value TEXMFHOME)/bibtex/bst/authcite
cp authcite.bst $(kpsewhich -var-value TEXMFHOME)/bibtex/bst/authcite/

# 必要に応じて mktexlsr を実行
mktexlsr $(kpsewhich -var-value TEXMFHOME)
```

---

## 使い方

### 1. プリアンブルでの宣言
```latex
\usepackage{authcite}

% 英語論文全体に適用したい場合はプリアンブルで設定可能
% \authcitesetup{lang=en}
```

### 2. 本文での引用
```latex
% 基本引用（既定: 日本語なら「Duら[1]」、英語なら「Du et al. [1]」）
\authcite{du2021}

% 複数の語の言語を指定（ja -> 「ら」、en -> 「et al.」）
\authcite[lang=ja]{du2021}   % Duら[1]
\authcite[lang=en]{du2021}   % Du et al. [1]

% 省略記法（キー名を省略して直接指定可能）
\authcite[ja]{du2021}        % Duら[1]
\authcite[en]{du2021}        % Du et al. [1]

% 2人共著を連記（日本語「DuとGu[1]」、英語「Du and Gu [1]」）
\authcite[two=both]{du2021}
\authcite[both]{du2021}      % 省略記法

% 組み合わせ
\authcite[en, both]{du2021}  % Du and Gu [1]
\authcite[etal={ほか}]{du2021} % 任意の語にカスタマイズ
```

### 3. 文献リストの指定
```latex
\bibliographystyle{authcite}
\bibliography{your_references}
```

---

## 設定オプション一覧

`\authcite[<options>]{<key>}` または `\authcitesetup{<options>}` で指定可能です。

| キー | 指定可能な値 | 既定値 | 説明 |
|---|---|---|---|
| `lang` | `ja` / `en` | `ja` | 助詞・言語設定。`ja` は「ら」「と」、`en` は「et al.」「and」 |
| `two`  | `etal` / `both` | `etal` | 2人共著の表記。`etal` は「1人目＋ら/et al.」、`both` は2名連記 |
| `etal` | `ja` / `en` / 任意文字列 | - | 複数のときの語を個別指定（`etal=ja`, `etal={ほか}` など） |
| `ja`   | （値なし） | - | `lang=ja` の省略記法（複数の語を「ら」にする） |
| `en`   | （値なし） | - | `lang=en` の省略記法（複数の語を「et al.」にする） |
| `both` | （値なし） | - | `two=both` の省略記法（2人共著を連記する） |

---

## 出力ルール

| 人数 | 日本語（lang=ja） | 英語（lang=en） |
|---|---|---|
| 1人 | `Hosseini[1]` | `Hosseini [1]` |
| 2人（既定: two=etal） | `Duら[2]` | `Du et al. [2]` |
| 2人（連記: two=both） | `DuとGu[2]` | `Du and Gu [2]` |
| 3人以上 | `Smithら[3]` | `Smith et al. [3]` |
| `and others` 含む | `Leeら[4]` | `Lee et al. [4]` |
| 著者なし（manual等） | `[5]` | `[5]` |

---

## コンパイル方法

`authcite` は BibTeX（`.bbl`）経由で著者情報を `.aux` に書き出すため、複数回のコンパイルが必要です（`latexmk` 等を使えば自動化されます）。

```bash
# 例: uplatex の場合
uplatex authcite-test.tex
upbibtex authcite-test
uplatex authcite-test.tex
uplatex authcite-test.tex
dvipdfmx authcite-test.dvi
```

---

## ライセンス

本パッケージは [MIT License](LICENSE) のもとで公開されています。
