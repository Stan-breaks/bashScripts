#!/usr/bin/env bash

TODAY=$(date +'%Y-%m-%d')
cd "/home/stan/vaults" || exit 1

git add .
git commit -m"$TODAY"
git push
