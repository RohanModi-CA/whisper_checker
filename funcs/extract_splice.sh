#!/bin/bash
#
# File: extract_splice.sh
# Description: Extracts a subclip from an audio file based on start and end
#              timestamps and saves it to the 'processed/' directory.
#
# Sample Call:
# ./extract_splice.sh "/path/to/my_audio.mp3" "00:03:42.940" "00:05:10.000"
#

# --- Argument Validation ---
if [[ "$#" -ne 3 ]]; then
    echo "Usage: $0 \"/path/to/audio_file\" \"<start_time>\" \"<end_time>\"" >&2
    echo "Example: $0 \"./audio/interview.wav\" \"00:10:30.500\" \"00:12:05.000\"" >&2
    exit 1
fi

INPUT_FILE="$1"
START_TIME="$2"
END_TIME="$3"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found at '$INPUT_FILE'" >&2
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed or not in your PATH. Please install it." >&2
    exit 1
fi

# --- Directory and Filename Setup ---
PROCESSED_DIR="processed"

# Create the output directory if it doesn't exist.
# The -p flag prevents errors if the directory already exists.
mkdir -p "$PROCESSED_DIR"

# Construct the output filename
# 1. Get the filename from the full path (e.g., "my_audio.mp3")
FILENAME=$(basename -- "$INPUT_FILE")
# 2. Get the extension (e.g., "mp3")
EXTENSION="${FILENAME##*.}"
# 3. Get the filename without the extension (e.g., "my_audio")
BASENAME="${FILENAME%.*}"
# 4. Assemble the new output path
OUTPUT_FILE="$PROCESSED_DIR/${BASENAME}_temp_splice.${EXTENSION}"


# --- Script Execution ---
echo "Extracting subclip from '$FILENAME'..."
echo "  Start: $START_TIME"
echo "  End:   $END_TIME"
echo "  Output: $OUTPUT_FILE"
echo "--------------------------------------------------------"

# Execute the ffmpeg command
# -i: input file
# -ss: seek to start time
# -to: stop at end time (absolute time from original file)
# -c:a copy: stream copy the audio codec (fast, no quality loss)
# -y: overwrite output file without asking
# -v quiet -stats: Shows progress but hides verbose ffmpeg banner info
ffmpeg -v quiet -stats -i "$INPUT_FILE" -ss "$START_TIME" -to "$END_TIME" -c:a copy -y "$OUTPUT_FILE"

# Check the exit code of ffmpeg
if [[ "$?" -ne 0 ]]; then
    echo "--------------------------------------------------------" >&2
    echo "Error: ffmpeg command failed." >&2
    exit 1
fi

echo "--------------------------------------------------------"
echo ""
echo "===================="
echo "Done."
echo "Subclip saved to: $OUTPUT_FILE"
