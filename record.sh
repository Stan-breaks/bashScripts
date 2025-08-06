#!/usr/bin/env bash
set -euo pipefail

# Config
OUTPUT_DIR="$HOME/Videos/records"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
VIDEO_FILE="$OUTPUT_DIR/video_$TIMESTAMP.mkv"
AUDIO_FILE="$OUTPUT_DIR/audio_$TIMESTAMP.wav"
FINAL_FILE="$OUTPUT_DIR/recording_$TIMESTAMP.mkv"

VIDEO_PID_FILE="/tmp/video_rec.pid"
AUDIO_PID_FILE="/tmp/audio_rec.pid"

# If already recording — STOP
if [[ -f "$VIDEO_PID_FILE" || -f "$AUDIO_PID_FILE" ]]; then
	echo "Recording detected — stopping..."

	# Stop audio
	if [[ -f "$AUDIO_PID_FILE" ]]; then
		AUDIO_PID=$(cat "$AUDIO_PID_FILE")
		kill -TERM "$AUDIO_PID" 2>/dev/null || true
		sleep 2
		kill -9 "$AUDIO_PID" 2>/dev/null || true
		rm -f "$AUDIO_PID_FILE"
	fi

	# Stop video
	if [[ -f "$VIDEO_PID_FILE" ]]; then
		VIDEO_PID=$(cat "$VIDEO_PID_FILE")
		kill -TERM "$VIDEO_PID" 2>/dev/null || true
		sleep 2
		kill -9 "$VIDEO_PID" 2>/dev/null || true
		rm -f "$VIDEO_PID_FILE"
	fi

	echo "Stopped recording. Merging..."

	[[ -s "$VIDEO_FILE" && -s "$AUDIO_FILE" ]] && echo true || echo false
	if [[ -s "$VIDEO_FILE" && -s "$AUDIO_FILE" ]]; then
		ffmpeg -i "$VIDEO_FILE" -i "$AUDIO_FILE" \
			-c:v copy -c:a aac -b:a 192k \
			-avoid_negative_ts make_zero \
			-fflags +genpts \
			"$FINAL_FILE" -y -loglevel error

		echo "Recording saved: $(basename "$FINAL_FILE")"
		rm -f "$VIDEO_FILE" "$AUDIO_FILE"

		if command -v notify-send >/dev/null; then
			notify-send "Recording Stopped" "Saved as $(basename "$FINAL_FILE")"
		fi
	else
		echo "Recording failed — missing audio/video."
	fi

	exit 0
fi

# Not recording — START

echo "No recording detected — starting..."
echo "Output: $(basename "$FINAL_FILE")"

# Start video
wf-recorder -f "$VIDEO_FILE" &
echo $! >"$VIDEO_PID_FILE"

# Start audio
ffmpeg -f pulse -i default \
	-af "afftdn=nf=-75" \
	-acodec pcm_s16le -ar 44100 \
	-avoid_negative_ts make_zero \
	"$AUDIO_FILE" -loglevel error &
echo $! >"$AUDIO_PID_FILE"

if command -v notify-send >/dev/null; then
	notify-send "Recording Started" "Press toggle again to stop"
fi

echo "Recording started. Run script again to stop."
