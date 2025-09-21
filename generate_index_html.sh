#!/usr/bin/env bash
# generate_index_html.sh — Convert a Markdown file (readme.md by default) to HTML (index.html by default).
# side-effects: writes/overwrites the specified OUTPUT_HTML file on disk

set -euo pipefail

# Usage/help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $(basename "$0") [INPUT_MD] [OUTPUT_HTML]"
  echo "Defaults: INPUT_MD=readme.md and OUTPUT_HTML=index.html located in the script directory."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INPUT_MD="${SCRIPT_DIR}/readme.md"
DEFAULT_OUTPUT_HTML="${SCRIPT_DIR}/index.html"

INPUT_MD="${1:-$DEFAULT_INPUT_MD}"
OUTPUT_HTML="${2:-$DEFAULT_OUTPUT_HTML}"

# Fail fast if input is missing/unreadable
if [[ ! -r "$INPUT_MD" ]]; then
  echo "Error: expected readable Markdown file at: $INPUT_MD" >&2
  exit 1
fi

# Extract first H1 as document title if present, default to "Document"
DOC_TITLE="$(awk 'match($0,/^# +(.+)$/,a){print a[1]; exit}' "$INPUT_MD" || true)"
if [[ -z "${DOC_TITLE}" ]]; then
  DOC_TITLE="Document"
fi

# Prefer pandoc if available
if command -v pandoc >/dev/null 2>&1; then
  pandoc \
    --from=gfm \
    --to=html5 \
    --standalone \
    --metadata=title:"$DOC_TITLE" \
    --output "$OUTPUT_HTML" \
    "$INPUT_MD"
  echo "Generated: $OUTPUT_HTML"
  exit 0
fi

# Fallback: Python 3 with markdown package
if command -v python3 >/dev/null 2>&1; then
  python3 - "$INPUT_MD" "$OUTPUT_HTML" <<'PYCODE'
import sys, io, os, re
from typing import Optional

def read_file(path: str) -> str:
    assert os.path.isfile(path), f"Expected existing file, got: {path}"
    with io.open(path, "r", encoding="utf-8") as f:
        return f.read()

def extract_title(md_text: str) -> str:
    match = re.search(r"^# +(.+)$", md_text, flags=re.MULTILINE)
    return match.group(1).strip() if match else "Document"

def convert_with_markdown(md_text: str) -> Optional[str]:
    try:
        import markdown  # type: ignore
    except Exception:
        return None
    return markdown.markdown(md_text, extensions=["extra", "sane_lists"])  # returns HTML fragment

def wrap_html_document(title: str, body_html: str) -> str:
    return f"""<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>{title}</title>
</head>
<body>
{body_html}
</body>
</html>
"""

def main(argv: list[str]) -> None:
    # Expect exactly two args: input and output
    assert len(argv) == 3, f"Expected 2 args (input, output), got: {len(argv)-1}"
    input_md_path, output_html_path = argv[1], argv[2]
    md_text = read_file(input_md_path)
    title = extract_title(md_text)
    html_body = convert_with_markdown(md_text)
    if html_body is None:
        raise SystemExit(
            "Error: 'pandoc' not found and Python 'markdown' package not installed.\n"
            "Install pandoc, or run: python3 -m pip install markdown"
        )
    html_document = wrap_html_document(title, html_body)
    with io.open(output_html_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(html_document)

if __name__ == "__main__":
    main(sys.argv)
PYCODE
  echo "Generated: $OUTPUT_HTML"
  exit 0
fi

echo "Error: Neither 'pandoc' nor 'python3' with the 'markdown' package is available." >&2
echo "Install pandoc or 'pip install markdown' and re-run." >&2
exit 1


