#
# File: subfuncs/find_and_split.py
# Description: This script is called by the main bash script. It uses ffmpeg
#              to find silent moments, splits an audio file accordingly, and
#              creates a JSON manifest of the results.
#

import sys
import os
import re
import subprocess
import json

# --- Configuration ---
# How quiet does it need to be to be considered "silent"? -30dB is a good starting point.
SILENCE_DB = "-30dB"
# How long does the silence need to last to be a valid split point? 0.5 seconds is reasonable.
SILENCE_DURATION = "0.25"


def run_command(command):
    """Runs a command and returns its output."""
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        # FFMPEG often prints to stderr even on success, so we check for "Error"
        if "Error" in result.stderr or "failed" in result.stderr:
             print(f"Error executing command: {' '.join(command)}")
             print(f"STDERR: {result.stderr}")
             sys.exit(1)
    return result.stderr


def get_total_duration(input_file):
    """Gets the total duration of the audio file in seconds."""
    print("Getting total audio duration...")
    command = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        input_file
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    try:
        return float(result.stdout.strip())
    except (ValueError, IndexError):
        print("Error: Could not determine audio duration from ffprobe.")
        sys.exit(1)


def find_silences(input_file):
    """Uses ffmpeg's silencedetect to find all periods of silence."""
    print(f"Detecting silent moments (min duration: {SILENCE_DURATION}s, threshold: {SILENCE_DB})...")
    command = [
        "ffmpeg",
        "-i", input_file,
        "-af", f"silencedetect=noise={SILENCE_DB}:d={SILENCE_DURATION}",
        "-f", "null",
        "-"
    ]
    output = run_command(command)
    
    start_times = re.findall(r"silence_start: (\d+\.?\d*)", output)
    end_times = re.findall(r"silence_end: (\d+\.?\d*)", output)

    if not start_times or not end_times:
        print("Error: No silences detected with the current settings. Try adjusting SILENCE_DB or SILENCE_DURATION.")
        sys.exit(1)

    silences = []
    for start, end in zip(start_times, end_times):
        silences.append((float(start), float(end)))
        
    print(f"Found {len(silences)} potential split points.")
    return silences


def split_audio(input_file, target_duration_sec, output_dir, silences, total_duration):
    """Splits the audio file at the best silent moments and creates a JSON manifest."""
    file_basename = os.path.splitext(os.path.basename(input_file))[0]
    file_ext = os.path.splitext(input_file)[1]
    
    clip_manifest = []
    current_pos = 0.0
    clip_num = 1

    while current_pos < total_duration:
        target_split_time = current_pos + target_duration_sec

        if target_split_time >= total_duration:
            split_point = total_duration
        else:
            best_silence = None
            min_dist = float('inf')
            
            for start, end in silences:
                if start > current_pos:
                    silence_mid_point = start + (end - start) / 2
                    dist = abs(silence_mid_point - target_split_time)
                    if dist < min_dist:
                        min_dist = dist
                        best_silence = (start, end)
            
            if best_silence:
                split_point = best_silence[0] + (best_silence[1] - best_silence[0]) / 2
            else:
                split_point = total_duration

        if split_point - current_pos < 1.0:
            break

        output_filename = f"{file_basename}_clip_{clip_num:03d}{file_ext}"
        output_filepath = os.path.join(output_dir, output_filename)
        
        print(f"\n--> Creating Clip {clip_num}: From {current_pos:.2f}s to {split_point:.2f}s")
        
        command = [
            "ffmpeg",
            "-i", input_file,
            "-ss", str(current_pos),
            "-to", str(split_point),
            "-c", "copy",
            "-y",
            output_filepath
        ]
        
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        
        # Add clip info to our manifest list
        clip_info = {
            "filename": output_filename,
            "source_start_time": round(current_pos, 4)
        }
        clip_manifest.append(clip_info)
        
        current_pos = split_point
        clip_num += 1

    # Write the manifest file
    manifest_filepath = os.path.join(output_dir, f"{file_basename}_manifest.json")
    print(f"\n--> Writing manifest file to: {manifest_filepath}")
    with open(manifest_filepath, 'w') as f:
        json.dump(clip_manifest, f, indent=4)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 find_and_split.py <input_file> <duration_minutes> <output_dir>")
        sys.exit(1)

    input_file_path = sys.argv[1]
    target_minutes = float(sys.argv[2])
    output_directory = sys.argv[3]
    
    target_seconds = target_minutes * 60

    total_duration_secs = get_total_duration(input_file_path)
    detected_silences = find_silences(input_file_path)
    split_audio(input_file_path, target_seconds, output_directory, detected_silences, total_duration_secs)
