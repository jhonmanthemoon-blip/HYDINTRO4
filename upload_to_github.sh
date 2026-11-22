#!/usr/bin/env bash
# Run this inside the folder that contains the sheets, audio.mp3 and kishou_xmas_sheets.lua
# (GitHub's web uploader caps at 100 files per commit, so use git for 413 files.)
git init
git branch -M main
git remote add origin https://github.com/jhonmanthemoon-blip/HYDINTRO4.git
git add .
git commit -m "Add video sheets, audio and loader"
git push -u origin main --force
