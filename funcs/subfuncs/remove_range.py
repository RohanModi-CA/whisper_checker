#
# File: subfuncs/remove_range.py
# Description: This script is called by the main bash script. It removes
#              subtitle entries within a given time range from a VTT file,
#              modifying the file in-place safely using a temporary file.
#

import sys
import re
import os
import tempfile

def parse_time_to_seconds(time_str: str) -> float:
    """Converts HH:MM:SS.ms or MM:SS.ms string to total seconds."""
    try:
        parts = time_str.split(':')
        if len(parts) == 3:  # HH:MM:SS.ms format
            h, m, s_ms = parts
            s, ms = s_ms.split('.')
            return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000.0
        elif len(parts) == 2:  # MM:SS.ms format
            m, s_ms = parts
            s, ms = s_ms.split('.')
            return int(m) * 60 + int(s) + int(ms) / 1000.0
        else:
            raise ValueError("Timestamp format not recognized.")
    except (ValueError, IndexError) as e:
        print(f"Error: Could not parse timestamp '{time_str}'. Details: {e}.", file=sys.stderr)
        sys.exit(1)

def remove_range_from_vtt(filepath: str, range_start_sec: float, range_end_sec: float):
    """Safely removes lines within a time range from a VTT file."""
    
    # Regex to capture VTT timestamps, supporting optional HH: part.
    line_regex = re.compile(r'\[?((?:\d{2}:)?\d{2}:\d{2}\.\d{3}) --> ((?:\d{2}:)?\d{2}:\d{2}\.\d{3})\]?.*')
    
    # Create a temporary file in the same directory to ensure atomic rename
    file_dir = os.path.dirname(os.path.abspath(filepath))
    # delete=False is crucial because we manage the file's lifecycle ourselves
    temp_fd, temp_path = tempfile.mkstemp(suffix=".tmp", dir=file_dir, text=True)
    
    lines_removed_count = 0

    try:
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as temp_file:
            with open(filepath, 'r', encoding='utf-8') as original_file:
                for line in original_file:
                    match = line_regex.match(line.strip())
                    
                    if match:
                        start_str, end_str = match.groups()[0:2]
                        line_start_sec = parse_time_to_seconds(start_str)
                        line_end_sec = parse_time_to_seconds(end_str)
                        
                        # The condition for overlap: (start1 < end2) and (end1 > start2)
                        # We write the line if it does NOT overlap.
                        if not ((line_start_sec < range_end_sec) and (line_end_sec > range_start_sec)):
                            temp_file.write(line)
                        else:
                            lines_removed_count += 1
                    else:
                        # If it's not a timestamp line, write it as-is
                        temp_file.write(line)
        
        # If we reach here, the temp file was written successfully.
        # Now, replace the original file with the temporary one.
        # os.replace is atomic on most systems if src and dst are on the same filesystem.
        os.replace(temp_path, filepath)
        print(f"Successfully removed {lines_removed_count} subtitle entries.")

    except Exception as e:
        # If any error occurs, print it and ensure the temp file is cleaned up
        print(f"An error occurred during processing: {e}", file=sys.stderr)
        # Clean up the temporary file as we are aborting
        os.remove(temp_path)
        # Re-raise the exception to signal failure to the bash script
        raise
        
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 remove_range.py <input_file> <start_time> <end_time>", file=sys.stderr)
        sys.exit(1)
    
    input_file = sys.argv[1]
    start_str = sys.argv[2]
    end_str = sys.argv[3]
    
    start_seconds = parse_time_to_seconds(start_str)
    end_seconds = parse_time_to_seconds(end_str)
    
    if start_seconds >= end_seconds:
        print("Error: Start time must be before end time.", file=sys.stderr)
        sys.exit(1)
        
    remove_range_from_vtt(input_file, start_seconds, end_seconds)
