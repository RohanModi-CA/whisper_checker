#!/usr/bin/env bash
# sample usage: ./gen_subtitles.sh "path/to/audio.mp3"

set -e
set -o pipefail
#
# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use SCRIPT_DIR as the base for relative paths
cd "$SCRIPT_DIR"

file_name="$1"

if [ -z file_name ]; then
	echo "Error: need to pass a filename."
	exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq is not installed. Please install it to proceed."
    echo "  On Debian/Ubuntu: sudo apt-get install jq"
    echo "  On macOS: brew install jq"
    exit 1
fi

# Let's get the full path to avoid issues.
file_name=$(realpath $1)

# Remove the directory path
filename_with_extension="${file_name##*/}"

# Remove the extension
just_filename="${filename_with_extension%.*}"



# Let's go into the directory where all of the fun is.
cd funcs

# Ensure we don't have a dirty file tree.
if [ -z "ls -A processed/" ]; then
	rm processed/*
fi

# First, we are going to split our audio file into its corresponding segments.
./split_audio.sh $file_name 5

# This has created a manifest.
manifest_filename="processed/${just_filename}_manifest.json"


# Get the total number of items to process
total_items=$(jq -r '. | length' "$manifest_filename")
current_item=0

# Iterate over each object in the JSON array and extract both filename and source_start_time
jq -r '.[] | .filename, .source_start_time' "$manifest_filename" | \
while IFS= read -r filename && IFS= read -r source_start_time; do
	filename="processed/${filename}"
	source_start_vtt_time=$(./to_vtt_time.sh ${source_start_time})


	current_item=$((current_item + 1))
    progress_percentage=$(awk "BEGIN {printf \"%.2f\", ($current_item / $total_items) * 100}")

	echo && echo && echo && echo
	echo ==================================
    echo "Processing item $current_item of $total_items ($progress_percentage%)"
	echo ==================================



    echo "  Filename: $filename"
    echo "  Source Start Time: $source_start_time seconds $source_start_vtt_time vtt."
	
	whisper_command="whisper '$filename' --model large-v3 --task transcribe --language fr --output_format srt > ${filename}_init.vtt"

	#echo $whisper_command
	#sleep 4
	eval "$whisper_command"

	# Once whisper is done, we will clean that up.
	./clean_vtt.sh ${filename}_init.vtt


	# Now, let's run the detect bad subs.
	./detect_bad_subs.sh ${filename}_init.vtt

	# This creates another json.
	bad_segments_filename="${filename}_init_bad_segments.json"

	
	# Iterate over each object in the JSON array and extract both start and end times
	jq -r '.[] | .start, .end' "$bad_segments_filename" | \
	while IFS= read -r start_time && IFS= read -r end_time; do
		echo "Fixing a bad segment, which is at:"
		echo "  Start Time: $start_time"
		echo "  End Time: $end_time"
		echo "------------------------"

		./extract_splice.sh ${filename} "${start_time}" "${end_time}"

		# This creates another file.
		temp_splice_filename=${filename%.*}_temp_splice.mp3
		temp_splice_vtt=${temp_splice_filename%.*}.vtt

		# Now, we have to run this one through whisper.
		whisper_temp_command="whisper '$temp_splice_filename' --model large-v3 --task transcribe --language fr --output_format srt > ${temp_splice_vtt}"
		#echo $whisper_temp_command
		#sleep 4
		eval "$whisper_temp_command"

		# Clean it.
		./clean_vtt.sh ${temp_splice_vtt}

		# Shift it the correct amount back.
		./shift_vtt.sh ${temp_splice_vtt} "${start_time}"

		# Insert it back into the main one.
		./insert_vtt.sh ${filename}_init.vtt ${temp_splice_vtt}

		# Now, delete the temporary files.
		rm ${temp_splice_filename}
		rm ${temp_splice_vtt}

		# Print the updated version.
		echo "New iteration!"
		cat ${filename}_init.vtt
	done

	# Now, we move it forward.
	./shift_vtt.sh ${filename}_init.vtt "${source_start_vtt_time}"

	# Put it at the end of the output.
	cat ${filename}_init.vtt >> processed/${just_filename}.vtt
	echo New Clip Added!
	echo; echo;
	cat processed/${just_filename}.vtt
	echo;
done

echo;
echo;
echo And, on est fini. Not buggs.
echo;
