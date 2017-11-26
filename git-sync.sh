#!/bin/bash
wget -N http://people.ds.cam.ac.uk/ssb22/mwrhome/mwr2ly.y
wget -N http://people.ds.cam.ac.uk/ssb22/mwrhome/midi-add-depth.py
git commit -am "Update $(echo $(git diff|grep '^--- a/'|sed -e 's,^--- a/,,')|sed -e 's/ /, /g')" && git push
