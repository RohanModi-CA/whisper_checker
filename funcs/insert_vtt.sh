#!/bin/bash
#
# File: insert_vtt.sh
# Description: Inserts the contents of a source VTT file into a destination
#              VTT file, overwriting any conflicting entries.
#
# Sample Call:
# ./insert_vtt.sh "destination.vtt" "source.vtt"
#

# --- Configuration ---
SUBFUNCS_DIR="subfuncs"
GET_SPAN_SCRIPT="$SUBFUNCS_DIR/get_vtt_span.py"
SORT_SCRIPT="$SUBFUNCS_DIR/sort_vtt.py"
REMOVE_RANGE_SCRIPT="./remove_vtt_range.sh" # Assumes it's in the same directory

# --- Argument Validation ---
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 \"/path/to/destination.vtt\" \"/path/to/source.vtt\"" >&2
    exit 1
fi

DEST_FILE="$1"
SOURCE_FILE="$2"

if [[ ! -f "$DEST_FILE" ]]; then
    echo "Error: Destination file not found at '$DEST_FILE'" >&2
    exit 1
fi
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file not found at '$SOURCE_FILE'" >&2
    exit 1
fi

# Check for all required script dependencies
for script in "$GET_SPAN_SCRIPT" "$SORT_SCRIPT" "$REMOVE_RANGE_SCRIPT"; do
    if [[ ! -f "$script" ]]; then
        echo "Error: Required helper script not found: $script" >&2
        exit 1
    fi
done
if [[ ! -x "$REMOVE_RANGE_SCRIPT" ]]; then
    echo "Error: The script '$REMOVE_RANGE_SCRIPT' is not executable. Please run 'chmod +x $REMOVE_RANGE_SCRIPT'." >&2
    exit 1
fi


# --- Script Execution ---
echo "Starting VTT insertion process..."
echo "Destination: $DEST_FILE"
echo "Source:      $SOURCE_FILE"
echo "--------------------------------------------------------"

# Step 1: Find the time span of the source file
echo "Step 1: Analyzing time span of source file..."
read START_TIME END_TIME <<< $(python3 "$GET_SPAN_SCRIPT" "$SOURCE_FILE")

if [[ -z "$START_TIME" || -z "$END_TIME" ]]; then
    echo "Error: Could not determine time span from source file. Is it empty or invalid?" >&2
    exit 1
fi
echo "-> Source file spans from $START_TIME to $END_TIME."

# Step 2: "Punch a hole" in the destination file by removing the conflicting range
echo "Step 2: Removing conflicting entries from destination file..."
"$REMOVE_RANGE_SCRIPT" "$DEST_FILE" "$START_TIME" "$END_TIME"
if [[ "$?" -ne 0 ]]; then
    echo "Error: Failed to remove range from destination file." >&2
    exit 1
fi

# Step 3: Append the source content to the destination file
echo "Step 3: Appending new entries..."
# Add a newline just in case the destination file doesn't end with one
echo "" >> "$DEST_FILE"
cat "$SOURCE_FILE" >> "$DEST_FILE"
echo "-> Appended source content."

# Step 4: Sort the combined file to fix the chronological order
echo "Step 4: Sorting the final file..."
python3 "$SORT_SCRIPT" "$DEST_FILE"
if [[ "$?" -ne 0 ]]; then
    echo "Error: Failed to sort the final file." >&2
    exit 1
fi
echo "-> File sorted successfully."


echo ""
echo "===================="
echo "Done."
echo "Source VTT has been successfully inserted into the destination file."
