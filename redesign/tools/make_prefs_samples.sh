#!/bin/sh
# redesign (Decision 70): Cone versions of the old preferences' layout previews
# (pixmaps/prefs/sample_{minimal,complete}.png): the Cone logo for VLC's cone in the video
# area and the title bar, "Cone" for the window title. Run from modules/gui/qt (ImageMagick 6, DejaVu Sans).
set -e
make_one() { # $1 VLC's preview, $2 the Cone one, $3 the cone's centre (y) in the video area
    tmp=$(mktemp -d)
    convert "$1" -crop 2x11+200+0 +repage "$tmp/strip.png"
    convert "$tmp/strip.png" -resize 90x11! "$tmp/title.png"
    convert "$tmp/strip.png" -resize 12x11! "$tmp/icon.png"
    convert pixmaps/brand/public/cone-16.png -resize 9x9 "$tmp/logo-small.png"
    convert pixmaps/brand/public/cone-64.png -resize 48x48 "$tmp/logo.png"
    convert "$1" \
        "$tmp/title.png" -geometry +66+0 -composite \
        "$tmp/icon.png" -geometry +2+0 -composite \
        "$tmp/logo-small.png" -geometry +4+1 -composite \
        -fill white -font DejaVu-Sans-Bold -pointsize 7 -gravity north -annotate +0+1 "Cone" \
        -gravity northwest -fill 'rgb(0,1,0)' -draw "rectangle 86,$(( $3 - 36 )) 158,$(( $3 + 36 ))" \
        "$tmp/logo.png" -geometry +98+$(( $3 - 24 )) -composite \
        -strip "$2"
    rm -r "$tmp"
}
make_one pixmaps/prefs/sample_minimal.png pixmaps/brand/public/prefs-sample-modern.png 76
make_one pixmaps/prefs/sample_complete.png pixmaps/brand/public/prefs-sample-classic.png 68
