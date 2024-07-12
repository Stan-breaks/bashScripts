#!/usr/bin/env bash

work_min=25
rest_min=5

while true; do
	echo "Starting 25 minutes of work"
	notify-send "Pomodoro" "Starting 25 minutes of work"
	sleep ${work_min}m

	echo "Work session complete. Starting 5 minutes of rest"
	notify-send "Pomodoro" "Work session complete. Take a 5-minute break!"
	sleep ${rest_min}m

	echo "Break time over. Ready for another session? (y/n)"
	notify-send "Break time over. Navigate to terminal to start another session? (y/n)"
	read -r response
	if [[ "$response" != "y" ]]; then
		break
	fi
done
