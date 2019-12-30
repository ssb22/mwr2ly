#!/usr/bin/env python2

# Lilypond SVG Fixer
# (c) 2019 Silas S. Brown
# License: GPL (same as Lilypond)

# Usage: python2 lilypond-svg-fixer.py < in.svg > out.svg

# What this does
# --------------

# Firefox bug 935056 : some versions of Firefox apply the
# 'minimum font size' (in Preferences/Content/Fonts/Advanced)
# to SVG files, even though SVG units are not usually pixels.

# Lilypond 2.18 generates SVG files with units about 5pt each.
# So most Lilypond text ends up below the minimum font size,
# and gets munged by Firefox if the user has that setting on.

# Workaround: multiply all font-size values by 10, and add
# "scale(0.1)" to the transform list of those elements.

# But then low-vision CSS on Safari 6 causes multi-word
# strings to overprint their words (I'm not sure why);
# work around this by replacing space with nbsp within
# tspan lines.

def filter(line):
    if not "font-size" in line:
        if line.rstrip().endswith("</tspan>") and ' ' in line: line = line.replace(' ',unichr(0xa0).encode('utf-8'))
        return line
    if "scale(0.1)" in line: return line # we've been here before?
    assert line.startswith('<text transform="translate'), "is this really a Lilypond-generated SVG?"
    line = line.replace('" ',' scale(0.1)" ',1)
    line = re.sub(r'font-size="([^"]*)"',lambda m:'font-size="'+str(10*float(m.group(1)))+'"',line)
    return line

import sys, re
if __name__ == "__main__":
    for l in sys.stdin: sys.stdout.write(filter(l))
