#!/usr/bin/env bash
#
# File: gen_subtitles.sh
# Description: A wrapper script to fully automate the process of generating
#              and correcting subtitles for a long audio file.
#
# Workflow:
# 1. Splits the audio into manageable, silence-aware clips.
# 2. Transcribes each clip using Whisper.
# 3. Detects potentially "bad" segments in the transcription.
# 4. For each bad segment:
#    a. Extracts the corresponding audio splice.
#    b. Re-transcribes only that small splice.
#    c. Patches the corrected transcription back into the clip's VTT.
# 5. Shifts all clip VTTs to their correct absolute time.
# 6. Concatenates all corrected VTTs into a final output file.
#
# Sample Usage:
# ./gen_subtitles.sh "/path/to/my audio file.mp3"
#

# ---
# Script Configuration
# ---
WHISPER_MODEL="large-v3"
WHISPER_LANGUAGE="fr"
TARGET_CLIP_MINUTES=5

# ---
# Strict Mode and Setup
# ---
# -e: exit immediately if a command exits with a non-zero status.
# -o pipefail: the return value of a pipeline is the status of the last command to exit with a non-zero status.
# -u: treat unset variables as an error when substituting.
set -e -o pipefail -u

# Find the directory where this script is located to robustly call other scripts
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROCESSED_DIR="$SCRIPT_DIR/processed"

# ---
# Helper Functions
# ---
log() {
    echo "[INFO] $1"
}

error() {
    echo >&2 "[ERROR] $1"
    exit 1
}

# Check for all required command-line tools
check_dependencies() {
    local missing_deps=0
    for cmd in jq whisper ffmpeg python3 awk bc; do
        if ! command -v "$cmd" &>/dev/null; then
            echo >&2 "[ERROR] Dependency not found: '$cmd'. Please install it."
            missing_deps=1
        fi
    done
    if [[ $missing_deps -eq 1 ]]; then
        exit 1
    fi
}

# ---
# Main Logic
# ---
main() {
    # --- Argument and File Validation ---
    if [[ "$#" -ne 1 ]]; then
        error "Usage: $0 \"/path/to/audio_file\""
    fi

    local input_file_raw="$1"
    if [[ ! -f "$input_file_raw" ]]; then
        error "Input file not found at '$input_file_raw'"
    fi

    check_dependencies
    log "All dependencies found."

    # Use realpath to get the absolute path, which prevents many issues.
    local input_file
    input_file=$(realpath "$input_file_raw")
    local input_basename
    input_basename=$(basename -- "$input_file")
    local filename_no_ext="${input_basename%.*}"

    # --- Directory and File Setup ---
    mkdir -p "$PROCESSED_DIR"
    local manifest_file="$PROCESSED_DIR/${filename_no_ext}_manifest.json"
    local final_vtt_file="$PROCESSED_DIR/${filename_no_ext}_final_subs.vtt"

    # Clean up previous final output file to prevent appending to old results
    log "Preparing workspace. Final output will be: $final_vtt_file"
    # The > operator creates the file or truncates it if it exists.
    > "$final_vtt_file"

    # --- Step 1: Split Audio ---
    log "Splitting audio file into clips of ~${TARGET_CLIP_MINUTES} minutes..."
    if ! "$SCRIPT_DIR/split_audio.sh" "$input_file" "$TARGET_CLIP_MINUTES"; then
        error "Failed to split the audio file."
    fi
    log "Audio splitting complete. Manifest created at '$manifest_file'."

    # --- Step 2: Process Each Clip ---
    log "Beginning processing for each audio clip..."

    # Use jq to read the manifest and pipe it into a while loop.
    # This is a robust way to handle JSON parsing in bash.
    jq -c '.[]' "$manifest_file" | while IFS= read -r clip_json; do
        local clip_filename
        clip_filename=$(jq -r '.filename' <<< "$clip_json")
        local start_time_sec
        start_time_sec=$(jq -r '.source_start_time' <<< "$clip_json")

        local clip_filepath="$PROCESSED_DIR/$clip_filename"
        local clip_basename="${clip_filename%.*}"
        local clip_vtt_base="$PROCESSED_DIR/${clip_basename}.vtt"

        log "--------------------------------------------------------"
        log "Processing clip: $clip_filename"

        # --- Step 2a: Initial Transcription ---
        log "  Transcribing clip with Whisper (Model: $WHISPER_MODEL)..."
        # Directly call whisper. Safer and cleaner than building a string to execute.
        if ! whisper "$clip_filepath" --model "$WHISPER_MODEL" --language "$WHISPER_LANGUAGE" --task transcribe --output_format vtt --output_dir "$PROCESSED_DIR"; then
            error "Whisper failed to transcribe '$clip_filepath'."
        fi
        # The output file is now named correctly (e.g., myclip.vtt)

        # --- Step 2b: Detect Bad Segments ---
        log "  Analyzing transcription for bad segments..."
        local bad_segments_json="$PROCESSED_DIR/${clip_basename}_bad_segments.json"
        if ! "$SCRIPT_DIR/detect_bad_subs.sh" "$clip_vtt_base"; then
            error "Failed to detect bad segments for '$clip_vtt_base'."
        fi

        # --- Step 2c: Correct Bad Segments (if any) ---
        if [[ $(jq 'length' "$bad_segments_json") -gt 0 ]]; then
            log "  Found bad segments. Starting correction process..."
            jq -c '.[]' "$bad_segments_json" | while IFS= read -r segment_json; do
                local start_time end_time
                start_time=$(jq -r '.start' <<< "$segment_json")
                end_time=$(jq -r '.end' <<< "$segment_json")

                log "    Fixing segment: $start_time --> $end_time"

                local splice_audio_path="$PROCESSED_DIR/${clip_basename}_temp_splice.mp3"
                local splice_vtt_path="$PROCESSED_DIR/${clip_basename}_temp_splice.vtt"

                # Extract audio for the bad segment
                "$SCRIPT_DIR/extract_splice.sh" "$clip_filepath" "$start_time" "$end_time"
                
                # Re-transcribe only the small splice
                whisper "$splice_audio_path" --model "$WHISPER_MODEL" --language "$WHISPER_LANGUAGE" --task transcribe --output_format vtt --output_dir "$PROCESSED_DIR"
                
                # Shift the new, tiny VTT to its correct position *within the clip*
                "$SCRIPT_DIR/shift_vtt.sh" "$splice_vtt_path" "$start_time"
                
                # Insert the corrected segment back into the main clip's VTT
                "$SCRIPT_DIR/insert_vtt.sh" "$clip_vtt_base" "$splice_vtt_path"
                
                # Clean up temporary splice files
                rm "$splice_audio_path" "$splice_vtt_path"
            done
            log "  All bad segments for this clip have been corrected."
        else
            log "  No bad segments found in this clip."
        fi

        # --- Step 2d: Shift Timestamps and Finalize Clip ---
        log "  Shifting clip timestamps to absolute time..."
        local start_time_vtt
        start_time_vtt=$("$SCRIPT_DIR/to_vtt_time.sh" "$start_time_sec")
        
        "$SCRIPT_DIR/shift_vtt.sh" "$clip_vtt_base" "$start_time_vtt"

        # Append the fully processed VTT to the final output file
        cat "$clip_vtt_base" >> "$final_vtt_file"
        # Add a newline for separation between concatenated files
        echo "" >> "$final_vtt_file"

        log "Clip '$clip_filename' processed and added to final output."
    done

    # --- Final Cleanup and Success Message ---
    # Optional: Clean up intermediate files
    # log "Cleaning up intermediate clip files..."
    # rm "$PROCESSED_DIR/${filename_no_ext}"_clip_*.{mp3,wav,vtt,json} 2>/dev/null

    log "========================================================"
    log "Done. All clips processed."
    log "The final, combined subtitle file is located at:"
    log "$final_vtt_file"
    log "========================================================"
}

# Execute the main function with all script arguments
main "$@"
