#!/bin/bash
# md-to-pdf.sh — Convert markdown files (with Mermaid diagrams) to PDF
#
# Usage:
#   ./md-to-pdf.sh file.md [file2.md ...]   Convert specific files
#   ./md-to-pdf.sh                          Convert all *.md files in this directory
#
# Dependencies: mmdc (@mermaid-js/mermaid-cli), pandoc, weasyprint
# Output: <filename>.pdf alongside each input file
#
# Options (set via env vars):
#   MD_TO_PDF_CSS         Path to CSS stylesheet (default: pdf-style.css next to this script)
#   MD_TO_PDF_WIDTH       Mermaid render width in px (default: 2400)
#   MD_TO_PDF_ORIENTATION Page orientation: portrait or landscape (default: landscape)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_CSS="$SCRIPT_DIR/pdf-style.css"
[[ ! -f "$DEFAULT_CSS" ]] && DEFAULT_CSS="/usr/local/share/md-to-pdf/pdf-style.css"
CSS="${MD_TO_PDF_CSS:-$DEFAULT_CSS}"
MERMAID_WIDTH="${MD_TO_PDF_WIDTH:-2400}"
PUPPETEER_CFG="$SCRIPT_DIR/puppeteer-config.json"
[[ ! -f "$PUPPETEER_CFG" ]] && PUPPETEER_CFG="/usr/local/share/md-to-pdf/puppeteer-config.json"
ORIENTATION="${MD_TO_PDF_ORIENTATION:-landscape}"
DIAGRAMS_DIR="$SCRIPT_DIR/diagrams"
TEMP_DIR="$(mktemp -d)"

# Generate orientation CSS override
ORIENTATION_CSS="$TEMP_DIR/orientation.css"
echo "@page { size: A4 $ORIENTATION; }" > "$ORIENTATION_CSS"

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# ── Dependency check ──────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v mmdc   &>/dev/null || missing+=("mmdc (npm install -g @mermaid-js/mermaid-cli)")
    command -v pandoc &>/dev/null || missing+=("pandoc")
    command -v python3 &>/dev/null && python3 -c "import weasyprint" &>/dev/null || \
        missing+=("weasyprint (pip3 install weasyprint)")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies:" >&2
        for m in "${missing[@]}"; do echo "  - $m" >&2; done
        exit 1
    fi
}

# ── Mermaid rendering ─────────────────────────────────────────────────────────
# Extracts ```mermaid blocks from a markdown file, renders each to PNG,
# and writes a new markdown file with image references substituted.
render_mermaid() {
    local input_file="$1"
    local file_stem
    file_stem="$(basename "$input_file" .md)"
    local output_file="$TEMP_DIR/${file_stem}.md"
    local diagram_index=0
    local in_mermaid=false
    local mermaid_content=""

    mkdir -p "$DIAGRAMS_DIR"
    > "$output_file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == '```mermaid' ]]; then
            in_mermaid=true
            mermaid_content=""
            diagram_index=$((diagram_index + 1))
            continue
        fi

        if $in_mermaid; then
            if [[ "$line" == '```' ]]; then
                in_mermaid=false
                local name="${file_stem}-diagram-${diagram_index}"
                local mmd_file="$TEMP_DIR/${name}.mmd"
                local png_file="$DIAGRAMS_DIR/${name}.png"
                printf '%s' "$mermaid_content" > "$mmd_file"
                echo "    rendering diagram ${diagram_index}..." >&2
                mmdc -i "$mmd_file" -o "$png_file" \
                    -w "$MERMAID_WIDTH" -s 3 -b white \
                    -p "$PUPPETEER_CFG" \
                    2>&1 | grep -v "^Generating single" >&2 || true
                # Use absolute path so pandoc can find the image from any cwd
                echo "![]($png_file)" >> "$output_file"
                echo "" >> "$output_file"
            else
                mermaid_content+="${line}"$'\n'
            fi
        else
            echo "$line" >> "$output_file"
        fi
    done < "$input_file"

    echo "$output_file"
}

# ── Convert one markdown file to PDF ─────────────────────────────────────────
convert_file() {
    local input_file
    input_file="$(realpath "$1")"
    local file_stem
    file_stem="$(basename "$input_file" .md)"
    local output_dir
    output_dir="$(dirname "$input_file")"
    local pdf_file="$output_dir/${file_stem}.pdf"

    echo "── $file_stem ──"
    echo "  Processing Mermaid diagrams..."
    local processed
    processed="$(render_mermaid "$input_file")"

    echo "  Generating PDF..."
    local pandoc_args=(
        "$processed"
        -o "$pdf_file"
        --pdf-engine=weasyprint
        --metadata "title=$(echo "$file_stem" | tr '-' ' ' | sed 's/\b\w/\u&/g')"
    )
    [[ -f "$CSS" ]] && pandoc_args+=(--css="$CSS")
    pandoc_args+=(--css="$ORIENTATION_CSS")

    pandoc "${pandoc_args[@]}" 2>&1 | grep -v "^ERROR: No anchor" >&2 || true

    if [[ -f "$pdf_file" ]]; then
        local size
        size="$(du -sh "$pdf_file" | cut -f1)"
        echo "  ✓ $pdf_file ($size)"
    else
        echo "  ✗ PDF generation failed for $input_file" >&2
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
check_deps

if [[ $# -eq 0 ]]; then
    # No arguments — convert all .md files in the script's directory
    mapfile -t FILES < <(find "$SCRIPT_DIR" -maxdepth 1 -name "*.md" | sort)
    if [[ ${#FILES[@]} -eq 0 ]]; then
        echo "No .md files found in $SCRIPT_DIR" >&2
        exit 1
    fi
else
    FILES=("$@")
fi

echo "=== md-to-pdf: converting ${#FILES[@]} file(s) ==="
echo ""

failed=0
for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: File not found: $f" >&2
        failed=$((failed + 1))
        continue
    fi
    convert_file "$f" || failed=$((failed + 1))
    echo ""
done

echo "=== Done: $((${#FILES[@]} - failed)) succeeded, $failed failed ==="
