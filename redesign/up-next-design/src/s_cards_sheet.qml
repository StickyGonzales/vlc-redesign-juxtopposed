import QtQuick
import "lib"
// component sheet: the three variants and the states of the recommended one
Rectangle {
    width: 1420; height: 900; color: T.isDark ? "#2A2A2A" : "#F2F2F2"
    component Cap: Txt { font.pixelSize: 13; color: T.isDark ? "#9A9A9A" : "#555555" }
    Cap { x: 40; y: 28; text: "A · recommended: panel card (400 wide)"; font.weight: Font.DemiBold }
    CardA { id: a1; x: 40; y: 56 }
    Cap { x: 40; y: a1.y + a1.height + 16; text: "A · Play now hovered (Accent/Bright), keyboard focus ring" }
    CardA { id: a2; x: 40; y: a1.y + a1.height + 40; seconds: 3; playHovered: true; playFocused: true }
    Cap { x: 40; y: a2.y + a2.height + 16; text: "A · last episode of a season: the next season's first" }
    CardA { id: a3; x: 40; y: a2.y + a2.height + 40; mode: "season"; episode: "S02E01 · Winter Light"; thumb: ASSETS + "thumb_s02e01.png"; seconds: 9 }
    Cap { x: 40; y: a3.y + a3.height + 16; text: "A · after 3 episodes in a row (no countdown, playback paused)" }
    CardA { x: 40; y: a3.y + a3.height + 40; mode: "still"; episode: "Next: S01E05 · Ashes" }
    Cap { x: 520; y: 28; text: "B · thumbnail first (320 wide)"; font.weight: Font.DemiBold }
    CardB { x: 520; y: 56 }
    Cap { x: 900; y: 28; text: "C · pill, the resume toast's shape (60 high)"; font.weight: Font.DemiBold }
    CardC { x: 900; y: 56 }
    Cap { x: 900; y: 150; width: 480; wrapMode: Text.Wrap
          text: "All three: opaque (no blur over the native video), effect \"bg blur + shadow\" without the blur, Inter, Figma tokens, buttons = RdButton (Primary / BG/A1 like the resume toast's close button). Countdown line: 3 px BG/B2 track, accent part = time left." }
}
