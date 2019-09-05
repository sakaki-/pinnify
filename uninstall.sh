#!/bin/bash
#
# Trivial uninstaller for pinnify. Invoke as root (or using sudo)
# in the top-level pinnify directory.
#
# Copyright (c) 2019 sakaki <sakaki@deciban.com>
#
# License (GPL v3.0)
# ------------------
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

set -e
set -u
shopt -s nullglob

LOCAL="/local" # TODO set as "" for live
METATEMPLATEDIR="/usr${LOCAL}/share/pinnify/templates"
TEMPLATEDIR="/var${LOCAL}/lib/pinnify/templates"
SOURCEDIR="${PWD}"
BINDIR="/usr${LOCAL}/sbin"

echo "Uninstalling pinnify and templates..."
rm -rfv "${METATEMPLATEDIR}" "${TEMPLATEDIR}"
rm -fv "${BINDIR}/pinnify"
echo "Done!"
