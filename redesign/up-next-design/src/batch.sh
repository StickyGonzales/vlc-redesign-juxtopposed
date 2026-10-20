#!/bin/bash
U=$(cd "$(dirname "$0")" && pwd); cd "$U"; mkdir -p out
r() { QT_QPA_PLATFORM=offscreen ${PYTHON:-python3} render.py "$U/$1" "$U/out/$2" $3 $4 $5 2>&1 | grep -v "^$" | head -5; }
r s_card_a.qml card-A-subtitles-dark.png 1920 1080 dark
r s_card_a_low.qml card-A-light.png 1920 1080 light
r s_card_b.qml card-B-dark.png 1920 1080 dark
r s_card_c.qml card-C-dark.png 1920 1080 dark
r s_cards_sheet.qml sheet-dark.png 1420 900 dark
r s_cards_sheet.qml sheet-light.png 1420 900 light
r s_prompt.qml prompt-dark.png 1920 1080 dark
r s_prompt.qml prompt-light.png 1920 1080 light
r s_mini_sheet.qml mini-dark.png 900 420 dark
r s_mini_sheet.qml mini-light.png 900 420 light
r s_library_sheet.qml library-dark.png 940 620 dark
r s_library_sheet.qml library-light.png 940 620 light
r s_sidebar_sheet.qml sidebar-dark.png 1320 720 dark
r s_sidebar_sheet.qml sidebar-light.png 1320 720 light
r s_settings.qml settings-dark.png 1088 905 dark
r s_settings_open.qml settings-open-dark.png 1088 905 dark
r s_settings_off.qml settings-off-dark.png 1088 905 dark
r s_settings.qml settings-light.png 1088 905 light
