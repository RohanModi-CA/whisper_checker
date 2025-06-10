#!/bin/bash
#
# File: remove_vtt_range.sh
# Description: Removes subtitle entries from a VTT file that fall within
#              a specified time range. The file is modified in-place.
#
# Sample Call:
# ./remove_vtt_range.sh "/path/to/my.vtt" "00:05:15.000" "00:10:20.500"
#

# --- Configuration ---
SUBFUNCS_DIR="subfuncs"
PYTHON_SCRIPT="$SUBFUNCS_DIR/remove_range.py"

# --- Argument Validation ---
if [[ "$#" -ne 3 ]]; then
    echo "Usage: $0 \"/path/to/vtt_file\" \"<start_time>\" \"<end_time>\""
    echo "Example: $0 \"./subs/movie.vtt\" \"01:10:05.000\" \"01:12:30.000\""
    echo "Note: The file will be modified in-place."
    exit 1
fi

INPUT_FILE="$1"
START_TIME="$2"
END_TIME="$3"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found at '$INPUT_FILE'"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed or not in your PATH. Please install it."
    exit 1
fi

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "Error: The required Python helper script was not found at '$PYTHON_SCRIPT'"
    exit 1
fi

# --- Script Execution ---
echo "Processing file: $INPUT_FILE"
echo "Removing entries between $START_TIME and $END_TIME..."

# Call the Python script to perform the in-place modification
python3 "$PYTHON_SCRIPT" "$INPUT_FILE" "$START_TIME" "$END_TIME"

# Check the exit code of the python script
if [[ "$?" -ne 0 ]]; then
    echo "--------------------------------------------------------"
    echo "An error occurred. The original file has NOT been modified."
    exit 1
fi

echo ""
echo "===================="
echo "Done."
echo "File has been successfully modified in-place."
