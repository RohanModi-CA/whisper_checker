#
# File: subfuncs/shift_timestamps.py
# Description: This script is called by the main bash script. It adds a
#              time offset to all timestamps in a VTT file, modifying it
#              safely in-place.
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
        print(f"Error: Could not parse timestamp '{time_str}'. Details: {e}", file=sys.stderr)
        raise

def format_seconds_to_time(total_seconds: float) -> str:
    """Converts total seconds to a zero-padded HH:MM:SS.ms string."""
    if total_seconds < 0:
        total_seconds = 0 # Prevent negative timestamps
    
    hours = int(total_seconds / 3600)
    minutes = int((total_seconds % 3600) / 60)
    seconds = total_seconds % 60
    
    # Format to HH:MM:SS.ms with zero padding
    return f"{hours:02d}:{minutes:02d}:{seconds:06.3f}"

def main(input_path: str, offset_str: str):
    """
    Reads the input VTT, shifts timestamps, and writes the result back
    to the original file path using a safe temporary file method.
    """
    print("Processing...")
    
    try:
        offset_sec = parse_time_to_seconds(offset_str)
    except ValueError:
        sys.exit(1) # Error message is already printed by the function

    # Regex to capture timestamps, handling both HH:MM:SS.ms and MM:SS.ms
    time_line_regex = re.compile(r'\[((?:\d{2}:)?\d{2}:\d{2}\.\d{3}) --> ((?:\d{2}:)?\d{2}:\d{2}\.\d{3})\](.*)')

    # Use a temporary file for safe in-place editing
    temp_fd, temp_path = tempfile.mkstemp()
    
    try:
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as temp_file:
            with open(input_path, 'r', encoding='utf-8') as input_file:
                for line in input_file:
                    match = time_line_regex.match(line.strip())
                    if match:
                        start_str, end_str, rest_of_line = match.groups()
                        
                        # Calculate new times
                        start_sec = parse_time_to_seconds(start_str) + offset_sec
                        end_sec = parse_time_to_seconds(end_str) + offset_sec
                        
                        # Format back to string
                        new_start_str = format_seconds_to_time(start_sec)
                        new_end_str = format_seconds_to_time(end_sec)
                        
                        # Write the modified line
                        new_line = f"[{new_start_str} --> {new_end_str}]{rest_of_line}\n"
                        temp_file.write(new_line)
                    else:
                        # If it's not a timestamp line, write it as-is
                        temp_file.write(line)
        
        # If we get here, the temp file was written successfully.
        # Now, replace the original file with the temporary one.
        os.replace(temp_path, input_path)
        print("File successfully updated.")

    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
        print("The original file has NOT been modified.", file=sys.stderr)
        os.remove(temp_path) # Clean up the temp file on error
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 shift_timestamps.py <input_file> <offset_time>", file=sys.stderr)
        sys.exit(1)
    
    main(sys.argv[1], sys.argv[2])
