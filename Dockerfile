FROM creambrulee/tiny-latex:latest-platex

RUN apk add --no-cache \
    texmf-dist-latexextra \
    poppler-utils