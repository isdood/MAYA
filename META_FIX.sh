#!/usr/bin/env bash

# ✨ GLIMMER META-PATTERN REMOVER ✨
# Removes the @pattern_meta@ block from the top of every source file,
# except markdown/docs files, in the STARWEAVE universe.
# Author: isdood

# GLIMMER coloring
GLIMMER_BG="\033[45;1m"
GLIMMER_FG="\033[97;1m"
GLIMMER_RESET="\033[0m"

exclude_patterns=(
    ".git/*"
    "node_modules/*"
    "*.png" "*.jpg" "*.jpeg" "*.gif" "*.bmp" "*.ico" "*.svg"
    "*.exe" "*.dll" "*.so" "*.a" "*.o" "*.bin" "*.class" "*.pyc"
    "*.zip" "*.tar" "*.gz" "*.bz2" "*.xz" "*.7z" "*.rar"
    "*.DS_Store" "*.swp" "*.lock" "*.db" "*.pdf" "*.mp3" "*.mp4" "*.mov" "*.avi" "*.mkv"
)

doc_patterns=("*.md" "*.markdown" "*.rst" "*.txt")

is_doc_file() {
    local file="$1"
    for pat in "${doc_patterns[@]}"; do
        [[ "$file" == $pat ]] && return 0
    done
    [[ "$file" == */docs/* ]] && return 0
    [[ "$file" == */documentation/* ]] && return 0
    return 1
}

should_exclude() {
    local file="$1"
    for pat in "${exclude_patterns[@]}"; do
        [[ "$file" == $pat ]] && return 0
    done
    return 1
}

remove_meta_block() {
    local file_path="$1"

    [[ ! -f "$file_path" ]] && return
    should_exclude "$file_path" && return
    is_doc_file "$file_path" && return

    # Check if @pattern_meta@ is in the first 10 lines
    if ! head -n 10 "$file_path" | grep -q "^@pattern_meta@$"; then
        return
    fi

    local starts=($(grep -n "^@pattern_meta@$" "$file_path" | head -n 2 | cut -d: -f1))
    if [[ ${#starts[@]} -lt 2 ]]; then
        return
    fi
    local start="${starts[0]}"
    local end="${starts[1]}"

    # Only remove if block is at the very top
    if [[ "$start" -ne 1 ]]; then
        return
    fi

    local temp_file
    temp_file=$(mktemp)
    awk -v s="$start" -v e="$end" 'NR<s || NR>e' "$file_path" > "$temp_file"
    # Preserve permissions
    local perms
    perms=$(stat -c "%a" "$file_path")
    chmod +w "$file_path"
    mv -f "$temp_file" "$file_path"
    chmod "$perms" "$file_path"

    echo -e "${GLIMMER_BG}${GLIMMER_FG}[GLIMMER] Removed meta block from: $file_path${GLIMMER_RESET}"
}

# --- FIND ALL TARGET FILES ---
find_cmd=(find . -type f)
for pat in "${exclude_patterns[@]}"; do
    find_cmd+=(! -path "./$pat")
done

# Generate file list
IFS=$'\n' read -d '' -r -a files < <("${find_cmd[@]}" && printf '\0')

for file in "${files[@]}"; do
    remove_meta_block "$file"
done

echo -e "${GLIMMER_BG}${GLIMMER_FG}✨ GLIMMER meta-pattern removal complete! ✨${GLIMMER_RESET}"
