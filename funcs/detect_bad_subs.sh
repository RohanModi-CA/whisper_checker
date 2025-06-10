#!/bin/bash
#
# File: detect_bad_subs.sh
# Description: Identifies problematic segments in a subtitle file and
#              outputs their padded timestamps to a JSON file.
#
# Sample Call:
# ./detect_bad_subs.sh "/path/to/my_subtitles.vtt"
#

# --- Configuration ---
SUBFUNCS_DIR="subfuncs"
PROCESSED_DIR="processed"
PYTHON_SCRIPT="$SUBFUNCS_DIR/process_subs.py"

# --- Argument Validation ---
if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 \"/path/to/subtitle_file\""
    echo "Example: $0 \"./subtitles/movie.vtt\""
    exit 1
fi

INPUT_FILE="$1"

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
echo "Starting subtitle analysis..."
echo "Input file: $INPUT_FILE"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$PROCESSED_DIR"

# Define the output filename
INPUT_BASENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${INPUT_BASENAME%.*}"
OUTPUT_FILE="$PROCESSED_DIR/${FILENAME_NO_EXT}_bad_segments.json"

echo "Handing off to Python script for processing..."
echo "Output will be saved to: $OUTPUT_FILE"
echo "--------------------------------------------------------"

# Call the Python script to perform the core logic
python3 "$PYTHON_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE"

# Check the exit code of the python script
if [[ "$?" -ne 0 ]]; then
    echo "--------------------------------------------------------"
    echo "An error occurred during the Python script execution."
    exit 1
fi

echo "--------------------------------------------------------"
echo ""
echo "===================="
echo "Done."
echo "Analysis complete. JSON file created at '$OUTPUT_FILE'"
