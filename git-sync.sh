#!/bin/bash
git pull --no-edit
wget -N http://ssb22.user.srcf.net/mwrhome/mwr2ly.y
wget -N http://ssb22.user.srcf.net/mwrhome/midi-add-depth.py
git commit -am "Update $(echo $(git diff|grep '^--- a/'|sed -e 's,^--- a/,,')|sed -e 's/ /, /g')" && git push
