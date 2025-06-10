#!/bin/bash
#
# File: split_audio.sh
# Description: Splits a long audio file into clips of a target duration,
#              ensuring splits occur during moments of silence. Also creates
#              a JSON manifest of the output files.
#
# Sample Call:
# ./split_audio.sh "/path/to/my long audio file.mp3" 10
#

# --- Configuration ---
SUBFUNCS_DIR="subfuncs"
PROCESSED_DIR="processed"
PYTHON_SCRIPT="$SUBFUNCS_DIR/find_and_split.py"

# --- Argument Validation ---
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 \"/path/to/audio_file\" <clip_duration_in_minutes>"
    echo "Example: $0 \"./audio/lecture.mp3\" 15"
    exit 1
fi

INPUT_FILE="$1"
CLIP_MINUTES="$2"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found at '$INPUT_FILE'"
    exit 1
fi

if ! [[ "$CLIP_MINUTES" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: Clip duration must be a positive number. You provided: '$CLIP_MINUTES'"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed or not in your PATH. Please install it."
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
echo "Starting audio processing..."
echo "Input file: $INPUT_FILE"
echo "Target clip duration: $CLIP_MINUTES minutes"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$PROCESSED_DIR"

echo "Handing off to Python script for analysis and splitting..."
echo "--------------------------------------------------------"

# Call the Python script to perform the core logic
# It will provide its own progress updates
python3 "$PYTHON_SCRIPT" "$INPUT_FILE" "$CLIP_MINUTES" "$PROCESSED_DIR"

# Check the exit code of the python script
if [[ "$?" -ne 0 ]]; then
    echo "--------------------------------------------------------"
    echo "An error occurred during the Python script execution."
    exit 1
fi



# Construct the expected manifest filename for the user message
INPUT_BASENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${INPUT_BASENAME%.*}"
MANIFEST_FILE="$PROCESSED_DIR/${FILENAME_NO_EXT}_manifest.json"

echo "Processed clips are in the '$PROCESSED_DIR' directory."
echo "A JSON manifest file has been created at: $MANIFEST_FILE"
echo ""
echo "JSON Manifest Structure:"
echo "The manifest is an array of objects, where each object represents a clip:"
echo "  - \"filename\": The name of the generated clip file."
echo "  - \"source_start_time\": The starting time (in seconds) of the clip"
echo "                         relative to the beginning of the original source file."

echo "--------------------------------------------------------"
echo ""
echo "===================="
echo "Done."
