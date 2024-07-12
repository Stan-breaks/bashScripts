#!/usr/bin/env bash
work_min=25
rest_min=5
log_file="$HOME/.pomodoro.log"
countdown() {
	local seconds=$1
	local message=$2
	for ((i = seconds; i >= 0; i--)); do
		printf "\r$message %02d:%02d" $((i / 60)) $((i % 60))
		sleep 1
	done
	echo
}

while true; do
	start_time=$(date '+%Y-%m-%d %H:%M:%S')
	echo "Starting 25 minutes of work at $start_time"
	notify-send "Pomodoro" "Starting 25 minutes of work"
	echo "$start_time - Started work session" >>"$log_file"
	countdown $((work_min * 60)) "Work time remaining:"

	end_time=$(date '+%Y-%m-%d %H:%M:%S')
	echo "Work session complete at $end_time. Starting 5 minutes of rest"
	notify-send "Pomodoro" "Work session complete. Take a 5-minute break!"
	echo "$end_time - Ended work session, started break" >>"$log_file"
	countdown $((rest_min * 60)) "Break time remaining:"

	break_end=$(date '+%Y-%m-%d %H:%M:%S')
	echo "Break time over at $break_end. Ready for another session? (y/n)"
	echo "$break_end - Ended break" >>"$log_file"
	notify-send "Pomodoro" "Break time over. Ready for another session?"
	read -r response
	if [[ "$response" != "y" ]]; then
		echo "$break_end - Pomodoro session ended" >>"$log_file"
		break
	fi
done
