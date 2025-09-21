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
  CSS_PATH="${SCRIPT_DIR}/assets/style.css"
  [[ -r "$CSS_PATH" ]] || CSS_PATH=""
  pandoc \
    --from=gfm \
    --to=html5 \
    --standalone \
    --metadata=title:"$DOC_TITLE" \
    ${CSS_PATH:+--css "$CSS_PATH"} \
    --output "$OUTPUT_HTML" \
    --shift-heading-level-by=-1 \
    "$INPUT_MD"
  echo "Pandoc generated: $OUTPUT_HTML"
  exit 0
fi

echo "Error: 'pandoc' package is not available." >&2
exit 1


