#!/bin/bash
#
# File: clean_vtt.sh
# Description: Cleans a VTT file by removing any lines that are not part of
#              a valid VTT block (timestamp + text). Modifies the file in-place.
#
# Sample Call:
# ./clean_vtt.sh "/path/to/dirty_output.vtt"
#

# --- Argument Validation ---
if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 \"/path/to/vtt_file\"" >&2
    echo "Example: $0 \"./subs/whisper_output.vtt\"" >&2
    exit 1
fi

INPUT_FILE="$1"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found at '$INPUT_FILE'" >&2
    exit 1
fi

if ! command -v awk &> /dev/null; then
    echo "Error: awk is not installed or not in your PATH. Please install it." >&2
    exit 1
fi

# --- In-Place Modification Setup ---
# Create a temporary file to write the clean output to.
# Using mktemp ensures we get a unique, secure filename.
TEMP_FILE=$(mktemp)

# Ensure the temporary file is removed on script exit, even if an error occurs.
trap 'rm -f "$TEMP_FILE"' EXIT

# --- Script Execution ---
echo "Cleaning VTT file: $INPUT_FILE"

# The awk script implements the "whitelist" logic.
# It writes its output to the temporary file.
awk '
# This is the main logic block, executed for every line.
{
    # Assume the previous line was not a timestamp.
    is_text_line = was_timestamp;
    was_timestamp = 0;

    # Check if the current line is a timestamp line.
    # We look for the arrow and the square brackets.
    if ($0 ~ /\[[0-9:.]+ --> [0-9:.]+\]/) {
        print;
        was_timestamp = 1;
    } else if (is_text_line) {
        # If the previous line was a timestamp, this must be valid text.
        print;
    }
    # Any other line (junk) is simply ignored.
}
' "$INPUT_FILE" > "$TEMP_FILE"

# Check if awk succeeded and the temp file is not empty.
if [[ "$?" -ne 0 || ! -s "$TEMP_FILE" ]]; then
    echo "Error: Failed to process the file. It might be empty or an error occurred." >&2
    echo "Original file has not been changed." >&2
    exit 1
fi

# If we get here, the temp file is valid. Replace the original file.
mv "$TEMP_FILE" "$INPUT_FILE"

# The trap will now try to remove the temp file, but it has been moved,
# which is fine. We can unset the trap.
trap - EXIT

echo ""
echo "===================="
echo "Done."
echo "File has been successfully cleaned in-place."
