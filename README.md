# mwr2ly
Manuscript Writer to Lilypond converter + MIDI add-depth script, from http://ssb22.user.srcf.net/mwrhome
(also mirrored at http://ssb22.gitlab.io/mwrhome just in case)

Manuscript Writer was a C++ music notation program I made in the mid-1990s to help with school music work. Its input was based on SMX code (e.g. `O2L4cdL8efL4g`) with many additions.

Manuscript Writer is rarely needed nowadays, because GNU Lilypond produces much better typesetting.  [mwr2ly.y](mwr2ly.y) in this repository is a mostly-automatic converter from Manuscript Writer code to Lilypond code; read the comments at the start of the file for how to compile and use it.

This repository also contains [midi-add-depth.py](midi-add-depth.py) to change MIDI files to add the pan and reverb settings that Manuscript Writer would have used for different instruments, and [lilypond-svg-fixer.py](lilypond-svg-fixer.py) to improve the display of Lilypond 2.18's SVG files in some Web browsers.
