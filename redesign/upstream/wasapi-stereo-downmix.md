# Draft: VideoLAN bug report and merge request (not posted)

Ready to paste into a new issue at https://code.videolan.org/videolan/vlc/-/issues once StickyGonzales
says so. It describes VLC's own code only (no Cone code in it), written for upstream readers. Cone
carries the patch below (branch wip/fix-wasapi-downmix); a merge request with it can follow the issue
once it is confirmed on the affected laptop.

---

**Title:** wasapi: 5.1 audio is distorted on stereo laptop speakers; VLC hands 6 channels to a 2-channel mix format

**Version:** VLC 4.0.0-dev, nightly win64 build of 2026-11-22 (5c415c4e). Windows 11 Pro 23H2. VLC 3.0
on the same machine and file plays cleanly.

**Device:** built-in laptop speakers, Realtek High Definition Audio, driver 6.0.9239.1 (2021). The
endpoint's shared-mode device format is WAVE_FORMAT_EXTENSIBLE, 2 channels, 48 kHz, 32-bit container
with 24 valid bits, channel mask 0x3. Speaker setup: Stereo. Realtek system effects (SFX/MFX/EFX APOs)
are registered on the endpoint and audio enhancements are on.

**File:** an MKV with an HE-AAC (SBR) 5.1 track, 48 kHz, decoded by faad.

**What happens:** the 5.1 track plays with heavy distortion (crackling, "farting"). Stereo files are
fine. Choosing Audio > Stereo mode / mix mode Stereo during playback removes the distortion at once.

**Log (--verbose=2):**

```
faad debug: AAC SBR (channels: 6, samplerate: 48000)
main debug: using audio output module "mmdevice"
main debug: using aout stream module "wasapi"
main debug: output 'f32l' 48000 Hz 3F2R/LFE frame=1 samples/24 bytes
main debug: input 'f32l' 48000 Hz 3F2R/LFE frame=1 samples/24 bytes
main debug: conversion: 'f32l'->'f32l' 48000 Hz->48000 Hz 3F2R/LFE->3F2R/LFE
```

There is no "modified format" line: `IAudioClient_IsFormatSupported()` in shared mode accepted the
6-channel float format on a device whose mix format has 2 channels, so VLC never downmixes. The
fold-down then happens in Windows or in the driver's per-stream effects, and that is where it breaks.

**Suggested fix:** in shared mode, compare the stream with `IAudioClient_GetMixFormat()`. When the
device mixes in fewer channels than the stream has, request the mix layout (stereo for 1 or 2
channels), so VLC's channel mixer downmixes, as VLC 3 effectively did. Devices that mix in as many
channels or more keep the stream unchanged, so real surround still works. Ambisonics (already rendered
on the mix format) and exclusive mode are unchanged.

```diff
@@ static HRESULT Start(aout_stream_t *s, audio_sample_format_t *restrict pfmt,
         else
         {
             shared_mode = AUDCLNT_SHAREMODE_SHARED;
+
+            if (pwf_mix == NULL
+             && SUCCEEDED(IAudioClient_GetMixFormat(sys->client, &pwf_mix)))
+            {
+                unsigned mix_channels;
+                uint32_t mix_physical = vlc_MixChannels(pwf_mix, &mix_channels);
+
+                if (mix_channels > 0 && mix_channels < fmt.i_channels)
+                {
+                    if (mix_channels <= 2 || mix_physical == 0)
+                        mix_physical = AOUT_CHANS_STEREO;
+                    msg_Dbg(s, "device mixes in %u channels, downmixing "
+                            "%u channels in VLC", mix_channels, fmt.i_channels);
+                    fmt.i_physical_channels = mix_physical;
+                    fmt.i_chan_mode = 0;
+                    aout_FormatPrepare(&fmt);
+                    vlc_ToWave(pwfe, &fmt);
+                }
+                CoTaskMemFree(pwf_mix);
+                pwf_mix = NULL;
+            }
+
             hr = IAudioClient_IsFormatSupported(sys->client, shared_mode,
                                                 pwf, &pwf_closest);
```

`vlc_MixChannels()` reads the mix format's channel mask into a VLC channel bitmap without checking the
bit depth (the mix format here has 24 valid bits in a 32-bit container, which `vlc_FromWave()` rejects).
The full patch is on the Cone branch.
