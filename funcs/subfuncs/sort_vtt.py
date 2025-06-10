#
# File: subfuncs/sort_vtt.py
# Description: Reads a VTT file, sorts all entries by start time,
#              and saves the result back to the file in-place.
#

import sys
import re
import os
import tempfile
from dataclasses import dataclass

# --- Reusing utility functions ---
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

@dataclass
class SubtitleBlock:
    start_sec: float
    original_block_text: str

def sort_vtt_file(filepath: str):
    """Safely sorts a VTT file in-place by start time."""
    line_regex = re.compile(r'\[?((?:\d{2}:)?\d{2}:\d{2}\.\d{3}) --> .*')
    
    header_lines = []
    subtitle_blocks = []
    
    # --- Parse the file into blocks ---
    with open(filepath, 'r', encoding='utf-8') as f:
        current_block_text = ""
        in_header = True
        for line in f:
            match = line_regex.match(line.strip())
            if match:
                in_header = False # We've hit the first timestamp
                if current_block_text: # Save the previous block
                    start_time_str = line_regex.match(current_block_text).groups()[0]
                    start_sec = parse_time_to_seconds(start_time_str)
                    subtitle_blocks.append(SubtitleBlock(start_sec, current_block_text))
                current_block_text = line
            else:
                if in_header:
                    header_lines.append(line)
                else:
                    current_block_text += line
        
        # Add the last block
        if current_block_text:
            match = line_regex.match(current_block_text)
            if match:
                start_time_str = match.groups()[0]
                start_sec = parse_time_to_seconds(start_time_str)
                subtitle_blocks.append(SubtitleBlock(start_sec, current_block_text))

    # --- Sort the blocks ---
    subtitle_blocks.sort(key=lambda x: x.start_sec)

    # --- Write to temp file and replace (safe in-place write) ---
    file_dir = os.path.dirname(os.path.abspath(filepath))
    temp_fd, temp_path = tempfile.mkstemp(suffix=".tmp", dir=file_dir, text=True)
    
    try:
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as temp_file:
            # Write header
            for line in header_lines:
                temp_file.write(line)
            
            # Write sorted blocks
            for block in subtitle_blocks:
                temp_file.write(block.original_block_text.strip() + "\n\n")

        os.replace(temp_path, filepath)
    except Exception as e:
        print(f"An error occurred during sorting: {e}", file=sys.stderr)
        os.remove(temp_path)
        raise

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 sort_vtt.py <file_to_sort>", file=sys.stderr)
        sys.exit(1)
    sort_vtt_file(sys.argv[1])
