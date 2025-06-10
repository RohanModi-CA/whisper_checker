#!/bin/bash
#
# File: to_vtt_time.sh
# Description: Converts a total number of seconds (including decimals)
#              into the VTT timestamp format HH:MM:SS.ms.
#
# Sample Call:
# ./to_vtt_time.sh 3661.512
# Output: 01:01:01.512
#
# ./to_vtt_time.sh 59.9
# Output: 00:00:59.900
#

# --- Argument Validation ---
if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <seconds>"
    echo "Example: $0 125.5"
    exit 1
fi

TOTAL_SECONDS_FLOAT=$1

# Check if the input is a valid positive number (integer or float)
if ! [[ "$TOTAL_SECONDS_FLOAT" =~ ^[0-9]+([.][0-9]*)?$ ]]; then
    echo "Error: Input must be a positive number of seconds."
    echo "You provided: '$TOTAL_SECONDS_FLOAT'"
    exit 1
fi

# --- Calculation ---

# Separate the whole seconds from the fractional part using shell parameter expansion
total_seconds_int=${TOTAL_SECONDS_FLOAT%.*}
# In case there was no decimal, the above gives the whole string. Re-assign.
if [[ "$TOTAL_SECONDS_FLOAT" != *"."* ]]; then
    total_seconds_int=$TOTAL_SECONDS_FLOAT
    fractional_part="0"
else
    # Extract the part after the decimal
    fractional_part="0.${TOTAL_SECONDS_FLOAT#*.}"
fi


# Calculate hours, minutes, and seconds using integer arithmetic
hours=$((total_seconds_int / 3600))
minutes=$(( (total_seconds_int % 3600) / 60 ))
seconds=$((total_seconds_int % 60))

# Calculate milliseconds from the fractional part using 'bc' for precision
# We multiply by 1000 and take the integer part.
milliseconds=$(echo "$fractional_part * 1000" | bc)
# bc might output a float like 512.0, so we truncate it to an integer
milliseconds=${milliseconds%.*}


# --- Formatting and Output ---

# Use printf to format the numbers with leading zeros
# %02d -> pad with a '0' to a width of 2 digits
# %03d -> pad with a '0' to a width of 3 digits
printf "%02d:%02d:%02d.%03d\n" $hours $minutes $seconds $milliseconds
