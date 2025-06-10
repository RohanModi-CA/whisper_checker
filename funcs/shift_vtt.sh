#!/bin/bash
#
# File: shift_vtt.sh
# Description: Shifts all timestamps in a VTT file by a given offset.
#              The file is modified in-place.
#
# Sample Call:
# ./shift_vtt.sh "/path/to/my_subtitles.vtt" "00:09:28.360"
#

# --- Configuration ---
SUBFUNCS_DIR="subfuncs"
PYTHON_SCRIPT="$SUBFUNCS_DIR/shift_timestamps.py"

# --- Argument Validation ---
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 \"/path/to/vtt_file\" \"<offset_time>\""
    echo "Example: $0 \"./subs/part2.vtt\" \"00:10:00.000\""
    exit 1
fi

INPUT_FILE="$1"
OFFSET_TIME="$2"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found at '$INPUT_FILE'"
    exit 1
fi

# A simple regex to check if the offset looks like a time string
if ! [[ "$OFFSET_TIME" =~ ^([0-9]{1,2}:)?[0-9]{1,2}:[0-9]{2}\.[0-9]{3}$ ]]; then
    echo "Error: Offset time format appears invalid. Use HH:MM:SS.ms or MM:SS.ms"
    echo "You provided: '$OFFSET_TIME'"
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
echo "Starting VTT timestamp shift..."
echo "File to modify: $INPUT_FILE"
echo "Time offset to add: $OFFSET_TIME"
echo ""

# Call the Python script to perform the in-place modification
python3 "$PYTHON_SCRIPT" "$INPUT_FILE" "$OFFSET_TIME"

# Check the exit code of the python script
if [[ "$?" -ne 0 ]]; then
    echo "--------------------------------------------------------"
    echo "An error occurred during the Python script execution."
    echo "The original file should be unchanged."
    exit 1
fi

echo ""
echo "===================="
echo "Done."
echo "File '$INPUT_FILE' has been successfully modified in-place."
