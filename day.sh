#!/usr/bin/env bash

#assigning the date to the variables TODAY and YESTERDAY
TODAY=$(date +'%Y-%m-%d')
YESTERDAY=$(date -d "yesterday" +'%Y-%m-%d')

#changing the directory to the location of my daily notes
cd "$HOME/vaults/personal/notes/dailies/" || exit 1

#checking if the file with the current date exists
if [ ! -f "${TODAY}.md" ]; then
	#create the new note
	{
		echo "---"
		echo "id: ${TODAY}"
		echo "aliases: []"
		echo "tags: []"
		echo "---"
		echo ""
		echo "# ${TODAY}"
		echo ""
		echo "# [[${YESTERDAY}]]"
		echo ""
		#ships the first five with the template
		tail -n +6 template.md
	} >"${TODAY}.md"
fi

#opens the file with the current date in the filename
nvim "${TODAY}.md"
