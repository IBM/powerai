#!/usr/bin/env bash

set -e

FEEDSTOCK_ROOT=$(cd "$(dirname "$0")/.."; pwd;)
FTP_HOST='oplab9.parqtec.unicamp.br'
LOCALPATH=$FEEDSTOCK_ROOT/build_artefacts
REMOTEPATH='/ppc64el/power-ai'

# Upload .tar.bz2 files from LOCALPATH recursively to REMOTEPATH
lftp -f "
set dns:order "inet"
set xfer:use-temp-file yes
set xfer:temp-file-name *.tmp
open ftp://$FTP_HOST
user $FTP_USER $FTP_PASSWORD
mirror -R --continue --reverse --no-empty-dirs --no-perms -i \.tar.bz2$ $LOCALPATH $REMOTEPATH
bye
"
