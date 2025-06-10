#
# File: subfuncs/get_vtt_span.py
# Description: Reads a VTT file and prints its earliest start time and
#              latest end time to standard output, separated by a space.
#

import sys
import re

# --- Reusing utility functions from previous scripts ---
def parse_time_to_seconds(time_str: str) -> float:
    try:
        parts = time_str.split(':')
        if len(parts) == 3: h, m, s_ms = parts
        elif len(parts) == 2: h, m, s_ms = 0, *parts
        else: raise ValueError("Unrecognized format")
        s, ms = s_ms.split('.')
        return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000.0
    except Exception:
        print(f"Error parsing time: {time_str}", file=sys.stderr); sys.exit(1)

def format_seconds_to_time(total_seconds: float) -> str:
    if total_seconds < 0: total_seconds = 0
    hours = int(total_seconds // 3600)
    minutes = int((total_seconds % 3600) // 60)
    seconds = int(total_seconds % 60)
    milliseconds = int(round((total_seconds - int(total_seconds)) * 1000))
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{milliseconds:03d}"
# ---

def get_vtt_span(filepath: str):
    line_regex = re.compile(r'\[?((?:\d{2}:)?\d{2}:\d{2}\.\d{3}) --> ((?:\d{2}:)?\d{2}:\d{2}\.\d{3})\]?.*')
    
    start_times_sec = []
    end_times_sec = []

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            match = line_regex.match(line.strip())
            if match:
                start_str, end_str = match.groups()[0:2]
                start_times_sec.append(parse_time_to_seconds(start_str))
                end_times_sec.append(parse_time_to_seconds(end_str))

    if not start_times_sec:
        # If the file is empty or has no timestamps, exit gracefully
        return

    min_start_sec = min(start_times_sec)
    max_end_sec = max(end_times_sec)

    # Print the formatted times to stdout for the bash script to capture
    print(f"{format_seconds_to_time(min_start_sec)} {format_seconds_to_time(max_end_sec)}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 get_vtt_span.py <input_file>", file=sys.stderr)
        sys.exit(1)
    get_vtt_span(sys.argv[1])
