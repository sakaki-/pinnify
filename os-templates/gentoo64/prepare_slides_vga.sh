#!/bin/bash

# This script will be called before tarring up the slides_vga directory
# A single argument (the release string) will be passed, and the working
# directory will be inside slides_vga
#
# You can use this to e.g. programmatically set a version number
# in one or more of your slides

# A simple example from gentoo-on-rpi-64bit follows
if true; then
    if which convert &>/dev/null && which exiftool &>/dev/null; then
        F="/usr/share/fonts/liberation-fonts/LiberationSans-BoldItalic.ttf"
        FC=""
        [[ -e "${F}" ]] && FC="-font ${F}" ||
                echo "Please install LiberationSans-BoldItalic.ttf for best results" >&2
        convert -pointsize 12 -fill black \
                ${FC} \
                -draw 'text 150,253 "Release '"${1}"'"' \
                Slide1.png Slide1.png
        # make sure no metadata leaks
        exiftool -all= *.png
        rm -vf *original
    else
        echo "Can't update slide: please ensure convert and exiftool are installed" >&2
    fi
fi
