#!/usr/bin/env bash
set -euo pipefail

# Check dependencies
command -v ffmpeg >/dev/null || {
	echo "ffmpeg not found. Install with: sudo apt install ffmpeg"
	exit 1
}
command -v grim >/dev/null || {
	echo "grim not found. Install with: sudo apt install grim"
	exit 1
}
command -v bc >/dev/null || {
	echo "bc not found. Install with: sudo apt install bc"
	exit 1
}

# Configuration
OUTPUT_DIR="$HOME/Videos/records"
mkdir -p "$OUTPUT_DIR"

# File names with timestamp
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
VIDEO_FILE="$OUTPUT_DIR/video_$TIMESTAMP.mkv"
AUDIO_FILE="$OUTPUT_DIR/audio_$TIMESTAMP.wav"
FINAL_FILE="$OUTPUT_DIR/recording_$TIMESTAMP.mkv"

# PID files for cleanup
VIDEO_PID_FILE="/tmp/video_rec.pid"
AUDIO_PID_FILE="/tmp/audio_rec.pid"
GRIM_PID_FILE="/tmp/grim_loop.pid"

cleanup() {
	echo
	echo "Stopping recording gracefully..."

	# Stop the grim loop first (this will cause ffmpeg video to finish naturally)
	if [[ -f "$GRIM_PID_FILE" ]]; then
		GRIM_PID=$(cat "$GRIM_PID_FILE" 2>/dev/null || echo "")
		if [[ -n "$GRIM_PID" ]]; then
			kill "$GRIM_PID" 2>/dev/null || true
			# Kill any remaining grim processes
			pkill -f "grim -t ppm" 2>/dev/null || true
		fi
		rm -f "$GRIM_PID_FILE"
	fi

	# Give ffmpeg time to finish processing the last frames
	echo "Finalizing video..."
	sleep 3

	# Now stop audio recording with SIGTERM (graceful)
	if [[ -f "$AUDIO_PID_FILE" ]]; then
		AUDIO_PID=$(cat "$AUDIO_PID_FILE" 2>/dev/null || echo "")
		if [[ -n "$AUDIO_PID" ]] && kill -0 "$AUDIO_PID" 2>/dev/null; then
			kill -TERM "$AUDIO_PID" 2>/dev/null || true
			# Wait for graceful shutdown
			sleep 2
			# Force kill if still running
			kill -9 "$AUDIO_PID" 2>/dev/null || true
		fi
		rm -f "$AUDIO_PID_FILE"
	fi

	# Stop video recording with SIGTERM (graceful)
	if [[ -f "$VIDEO_PID_FILE" ]]; then
		VIDEO_PID=$(cat "$VIDEO_PID_FILE" 2>/dev/null || echo "")
		if [[ -n "$VIDEO_PID" ]] && kill -0 "$VIDEO_PID" 2>/dev/null; then
			kill -TERM "$VIDEO_PID" 2>/dev/null || true
			# Wait for graceful shutdown
			sleep 2
			# Force kill if still running
			kill -9 "$VIDEO_PID" 2>/dev/null || true
		fi
		rm -f "$VIDEO_PID_FILE"
	fi

	echo "Recording stopped. Processing..."

	# Wait a moment for files to finalize
	sleep 1

	# Check if files exist and have content
	if [[ ! -f "$VIDEO_FILE" ]] || [[ ! -s "$VIDEO_FILE" ]]; then
		echo "Error: Video file missing or empty"
		exit 1
	fi

	if [[ ! -f "$AUDIO_FILE" ]] || [[ ! -s "$AUDIO_FILE" ]]; then
		echo "Error: Audio file missing or empty"
		exit 1
	fi

	echo "Video file size: $(du -h "$VIDEO_FILE" | cut -f1)"
	echo "Audio file size: $(du -h "$AUDIO_FILE" | cut -f1)"

	# Merge video and audio with sync correction
	echo "Merging video and audio..."

	if ffmpeg -i "$VIDEO_FILE" -i "$AUDIO_FILE" \
		-c:v copy -c:a aac -b:a 192k \
		-avoid_negative_ts make_zero \
		-fflags +genpts \
		"$FINAL_FILE" -y -loglevel error; then

		echo "Merge successful: $(basename "$FINAL_FILE")"

		# Delete separate files
		rm -f "$VIDEO_FILE" "$AUDIO_FILE"
		echo "Cleaned up temporary files"

		# Notification
		if command -v notify-send >/dev/null; then
			notify-send "Recording Complete" "Saved as $(basename "$FINAL_FILE")"
		fi

	else
		echo "Merge failed. Separate files kept:"
		echo "Video: $(basename "$VIDEO_FILE")"
		echo "Audio: $(basename "$AUDIO_FILE")"
	fi

	exit 0
}

# Handle Ctrl+C
trap cleanup INT TERM

# Check if already recording
if [[ -f "$VIDEO_PID_FILE" ]] || [[ -f "$AUDIO_PID_FILE" ]]; then
	echo "Recording already in progress. Stop it first."
	exit 1
fi

echo "Starting screen recording..."
echo "Output will be: $(basename "$FINAL_FILE")"
echo "Press Ctrl+C to stop"
echo

# Start the grim screenshot loop in background
{
	frame_duration=$(echo "scale=6; 1/30" | bc -l)
	while true; do
		grim -t ppm - 2>/dev/null || break
		sleep "$frame_duration"
	done
} &
GRIM_PID=$!
echo $GRIM_PID >"$GRIM_PID_FILE"

# Start video recording (reads from the grim loop above)
ffmpeg -f image2pipe -r 30 -i <(
	while kill -0 $GRIM_PID 2>/dev/null; do
		grim -t ppm - 2>/dev/null || break
		sleep $(echo "scale=6; 1/30" | bc -l)
	done
) -c:v libx264 -crf 18 -preset fast -pix_fmt yuv420p \
	-avoid_negative_ts make_zero \
	"$VIDEO_FILE" -loglevel error &

echo $! >"$VIDEO_PID_FILE"

# Start audio recording
ffmpeg -f pulse -i default \
	-af "afftdn=nf=-75" \
	-acodec pcm_s16le -ar 44100 \
	-avoid_negative_ts make_zero \
	"$AUDIO_FILE" -loglevel error &

echo $! >"$AUDIO_PID_FILE"

# Notification
if command -v notify-send >/dev/null; then
	notify-send "Recording Started" "Press Ctrl+C to stop"
fi

echo "Recording in progress..."
echo "Video PID: $(cat "$VIDEO_PID_FILE")"
echo "Audio PID: $(cat "$AUDIO_PID_FILE")"
echo

# Monitor recording and show progress
while [[ -f "$VIDEO_PID_FILE" ]] && [[ -f "$AUDIO_PID_FILE" ]]; do
	if [[ -f "$VIDEO_FILE" ]] && [[ -f "$AUDIO_FILE" ]]; then
		printf "\rVideo: %s | Audio: %s" \
			"$(du -h "$VIDEO_FILE" 2>/dev/null | cut -f1 || echo "0B")" \
			"$(du -h "$AUDIO_FILE" 2>/dev/null | cut -f1 || echo "0B")"
	fi
	sleep 2
done

# This should never be reached due to trap, but just in case
wait
