# Up Next card: fine-tuned proportions (StickyGonzales, 2026-11-08, approved)

StickyGonzales keeps the current card design and approved the "Tuned" proportions in
`redesign/fix-shots/up_next_card_tune.png` (left: the card today, right: approved). Same parts, same colours,
same behaviour; only sizes, order and alignment change. File: `modules/gui/qt/player/qml/RdUpNextCard.qml`
(the full card; the compact pill stays as it is).

## What is wrong today
- **Next episode button:** the text almost touches the right edge. Its `implicitWidth` uses
  `implicitContentWidth`, which leaves out the play icon, and RdButton has only 8 px padding on each side,
  so the content is wider than the button and sits off-centre.
- **Texts:** small next to the 160x90 picture and stuck to its top, with a lot of empty space on the right.

## Approved values (all `VLCStyle.dp(…, VLCStyle.scale)`)
| Part | Today | Approved |
|---|---|---|
| Card width | 400 | **420** |
| Padding (all sides) | 12 | **16** |
| Picture | 160 x 90 | **168 x 95**, radius unchanged |
| Picture to texts | 14 | **16** |
| Text order | Up next / show / episode | **Up next / episode / show** |
| "Up next" | 12 DemiBold, accent | **13** DemiBold, accent |
| Episode line (`cardLine`) | 16 Medium, FG/2 | **22 DemiBold, FG/1**, still 2 lines max then elided |
| Show name | 14 Regular, FG/A2 | **15** Regular, FG/A1 |
| Spacing | 4 / 4 | **6** after "Up next", **4** after the episode line |
| Text block | top-aligned | **vertically centred on the picture** (the countdown / waiting line stays at the bottom of the block, 13, FG/A3, as today; when the block is taller than the picture the picture sets nothing and the block starts at the top) |
| Picture to buttons | 12 | **14** |
| Button height | as today | **36** |
| Next episode | 120 min, icon not counted | **as wide as the picture (168)**, icon + 8 + text **centred**; its width must count the icon (use the content row's width, not `implicitContentWidth`) and keep at least 16 px each side for longer translations (then wider than the picture); 15 DemiBold |
| Cancel | after Next episode, 10 gap | **starts at the text column's x** (lines up with "Up next"), 84 wide at least |
| Turn off autoplay | right | unchanged: right-aligned to the right padding, centred on the buttons |

The countdown fill inside Next episode, the Still watching state (no picture: the texts take the full width,
Keep watching / Stop in the same places), Tab order, accessible names and the 150 ms fade stay as they are.
Check at 100 / 125 / 150 % scaling that Cancel and "Turn off autoplay" never touch (420 - 2 x 16 leaves
room; if a translation is too long, elide the link).

## Retest (PC session)
Long Show from UP_NEXT_CREDITS_SCAN_NOTES.md: the card at the credits, a screenshot next to the "Tuned"
panel at the same scale; Next episode text centred in its button; Next episode / Cancel / Turn off autoplay
and the picture click still work; the countdown fill; Still watching after 3 episodes.
