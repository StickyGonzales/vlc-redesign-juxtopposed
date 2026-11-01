# Filter sliders read their values correctly (branch wip/fix-slider-a11y-value)

Branch `wip/fix-slider-a11y-value`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/player/qml/VideoSettingsPage.qml`).

## Cause
The sidebar's Video > Filters sliders (Brightness, Contrast, Saturation, Gamma, Hue, Sharpen Sigma, Banding Removal Radius, Film Grain Variance, and the other filter groups) take their value from VLC's options, which VLC keeps as 32-bit floats:
- `RdEffects` caches every float option as `double(float)` (`rd_effects.cpp`), so 1.05 becomes 1.0499999523162842;
- a slider's value, minimum and maximum are what a screen reader announces (UI Automation's range value, AT-SPI's Value interface). After a move it read Brightness as "1.0499999523162842".

What AT-SPI reports for the Essential sliders in the Linux sandbox, before the fix:

| Slider | Value | Min | Max | Step |
|---|---|---|---|---|
| Brightness | 1.0 | 0.0 | 2.0 | 0.01 |
| Gamma | 1.0 | **0.009999999776482582** | 10.0 | 0.01 |
| Sharpen Sigma | **0.05000000074505806** | 0.0 | 2.0 | 0.01 |

The same float noise is in every value moved away from a round default, because the slider's value comes back from that cache.

## Fix
Each filter slider rounds its value and its range to its row's decimals (Brightness: 2): 1.05 is 1.05, Gamma's minimum 0.01. What VLC gets is unchanged; the rounding only affects what the slider shows and reports.

## Runs
| Run | Result |
|---|---|
| build-windows #147 (41253480087), this branch | build and **all smoke checks pass** |
| build-linux #53 (41253486005), test-only `wip/test-linux-small-fixes` | AT-SPI in the sandbox: Gamma's minimum now reads **0.01** (was 0.009999999776482582); Brightness 1.0 of 0.0 to 2.0, step 0.01 |

Checks: qmlcheck errors 0 on the file, privacycheck 0.

## Windows retest (PC session)
With NVDA (or Narrator) on. Play a video, open the sidebar (gear) > Video > Filters > Essential > Expand Settings.
1. Tab to **Brightness**: it reads "Brightness, slider, 1".
2. Right arrow 5 times: "1.05" (not "1.0499999…"). Left back to "1".
3. Gamma: its minimum (Home key) reads "0.01".
4. The other filter sliders read short values the same way.
