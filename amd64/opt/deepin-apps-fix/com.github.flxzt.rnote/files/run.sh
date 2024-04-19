#!/bin/bash
ROOT="$(dirname $(readlink -f $0))/root"

bwrap \
    --ro-bind $ROOT / \
    --dev /dev \
    --proc /proc \
    --dev-bind /sys /sys \
    --dev-bind /run /run \
    --dev-bind /dev/dri /dev/dri \
    --ro-bind /usr/share/fonts /usr/share/fonts \
    --ro-bind /usr/share/fontconfig /usr/share/fontconfig \
    --bind /home /home \
    --setenv LANG "$LANG" \
    --setenv LC_COLLATE "$LC_COLLATE" \
    --setenv LC_CTYPE "$LC_CTYPE" \
    --setenv LC_MONETARY "$LC_MONETARY" \
    --setenv LC_MESSAGES "$LC_MESSAGES" \
    --setenv LC_NUMERIC "$LC_NUMERIC" \
    --setenv LC_TIME "$LC_TIME" \
    --setenv LC_ALL "$LC_ALL" \
    -- /usr/bin/rnote "$@"

