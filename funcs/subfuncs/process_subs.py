#
# File: subfuncs/process_subs.py
# Description: This script is called by the main bash script. It parses a
#              subtitle file, finds "bad" segments, and outputs the padded
#              timestamps to a JSON file.
#

import sys
import re
import json
from dataclasses import dataclass

# --- Configuration for "Bad Behavior" ---

# 1. A single subtitle line lasting longer than this (in seconds) is bad.
LONG_DURATION_THRESHOLD_SEC = 300.0

# 2. This many (or more) consecutive lines with identical text are bad.
REPETITIVE_TEXT_MIN_CONSECUTIVE = 3

# 3. A single subtitle line lasting less than this (in seconds) is bad.
SHORT_DURATION_THRESHOLD_SEC = 0.2


@dataclass
class SubtitleLine:
    """A dataclass to hold parsed subtitle information."""
    index: int
    start_str: str
    end_str: str
    text: str
    start_sec: float = 0.0
    end_sec: float = 0.0
    duration: float = 0.0
    is_bad: bool = False
    reason: str = ""

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
        print(f"Error: Could not parse timestamp '{time_str}'. Details: {e}. Exiting.")
        sys.exit(1)

def parse_subtitle_file(filepath: str) -> list[SubtitleLine]:
    """Reads and parses the entire subtitle file."""
    print("Parsing subtitle file...")
    # CORRECTED Regex: Makes the HH: part optional to handle both formats.
    # The (?:...) is a non-capturing group.
    line_regex = re.compile(r'\[((?:\d{2}:)?\d{2}:\d{2}\.\d{3}) --> ((?:\d{2}:)?\d{2}:\d{2}\.\d{3})\]\s*(.*)')
    
    subtitles = []
    with open(filepath, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            match = line_regex.match(line.strip())
            if match:
                start_str, end_str, text = match.groups()
                sub = SubtitleLine(index=len(subtitles), start_str=start_str, end_str=end_str, text=text.strip())
                sub.start_sec = parse_time_to_seconds(sub.start_str)
                sub.end_sec = parse_time_to_seconds(sub.end_str)
                sub.duration = sub.end_sec - sub.start_sec
                subtitles.append(sub)
    
    if not subtitles:
        print("Warning: No valid subtitle lines found in the file.")
    else:
        print(f"Successfully parsed {len(subtitles)} subtitle lines.")
    return subtitles

def flag_bad_lines(subs: list[SubtitleLine]):
    """Applies rules to flag lines as 'bad'."""
    print("Analyzing lines for anomalies...")
    # Rule 1 & 3: Duration anomalies
    for sub in subs:
        if sub.duration > LONG_DURATION_THRESHOLD_SEC:
            sub.is_bad = True
            sub.reason = f"Long duration ({sub.duration:.2f}s)"
        elif sub.duration < SHORT_DURATION_THRESHOLD_SEC:
            sub.is_bad = True
            sub.reason = f"Short duration ({sub.duration:.2f}s)"

    # Rule 2: Repetitive text
    if len(subs) >= REPETITIVE_TEXT_MIN_CONSECUTIVE:
        for i in range(len(subs) - REPETITIVE_TEXT_MIN_CONSECUTIVE + 1):
            # Get a slice of subtitles to check for repetition
            window = subs[i : i + REPETITIVE_TEXT_MIN_CONSECUTIVE]
            first_text = window[0].text
            
            # Check if all texts in the window are the same and not empty
            if first_text and all(s.text == first_text for s in window):
                # Flag all subs in this window as bad
                for sub in window:
                    if not sub.is_bad:
                        sub.is_bad = True
                        sub.reason = "Repetitive text"
    
    bad_line_count = sum(1 for s in subs if s.is_bad)
    print(f"Found {bad_line_count} potentially problematic lines.")

def group_bad_blocks(subs: list[SubtitleLine]) -> list[dict]:
    """Groups contiguous 'bad' lines into blocks."""
    if not any(s.is_bad for s in subs):
        return []

    print("Grouping bad lines into contiguous blocks...")
    blocks = []
    in_block = False
    for i, sub in enumerate(subs):
        if sub.is_bad and not in_block:
            # Start of a new block
            in_block = True
            blocks.append({'start_index': i, 'end_index': i})
        elif sub.is_bad and in_block:
            # Continue an existing block
            blocks[-1]['end_index'] = i
        elif not sub.is_bad and in_block:
            # End of a block
            in_block = False
    
    print(f"Identified {len(blocks)} distinct problematic blocks.")
    return blocks

def main(input_path: str, output_path: str):
    """Main execution function."""
    subtitles = parse_subtitle_file(input_path)
    if not subtitles:
        # Write empty JSON and exit if no subs found
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump([], f)
        return

    flag_bad_lines(subtitles)
    bad_blocks = group_bad_blocks(subtitles)

    final_output = []
    if bad_blocks:
        print("Extracting padded timestamps for final output...")
        for block in bad_blocks:
            # Apply padding: one line before, one line after
            padded_start_index = max(0, block['start_index'] - 1)
            padded_end_index = min(len(subtitles) - 1, block['end_index'] + 1)
            
            start_time = subtitles[padded_start_index].start_str
            end_time = subtitles[padded_end_index].end_str
            
            final_output.append({
                "start": start_time,
                "end": end_time
            })

    # Write the result to the JSON file
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, indent=2)
    
    print(f"Successfully wrote {len(final_output)} segments to JSON.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 process_subs.py <input_file> <output_file>")
        sys.exit(1)
    
    main(sys.argv[1], sys.argv[2])
