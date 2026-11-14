import os, random, struct, subprocess, sys, wave, math
OUT = sys.argv[1]
def ff(*a):
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', *a], check=True)
def ts(t):
    h = int(t // 3600); m = int(t % 3600 // 60); s = t % 60
    return f'{h:02d}:{m:02d}:{int(s):02d},{int(round((s - int(s)) * 1000)):03d}'
def srt(path, lines):
    with open(path, 'w', encoding='utf-8') as f:
        for i, (a, b, text) in enumerate(lines, 1):
            f.write(f'{i}\n{ts(a)} --> {ts(b)}\n{text}\n\n')
# a show: 5 episodes x 7:00, two audio and two subtitle tracks each
show = os.path.join(OUT, 'Pass Show')
os.makedirs(show, exist_ok=True)
for e in range(1, 6):
    base = os.path.join(show, f'Pass Show S01E0{e}')
    en, fr = base + '.en.tmp.srt', base + '.fr.tmp.srt'
    srt(en, [(t, t + 3, f'English line {t // 10} (episode {e})') for t in range(5, 420, 10)])
    srt(fr, [(t, t + 3, f'Ligne {t // 10} (episode {e})') for t in range(5, 420, 10)])
    ff('-f', 'lavfi', '-i', f'testsrc2=size=320x180:rate=10,hue=h={e * 60}',
       '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=22050',
       '-f', 'lavfi', '-i', 'sine=frequency=660:sample_rate=22050',
       '-i', en, '-i', fr, '-t', '420',
       '-map', '0:v', '-map', '1:a', '-map', '2:a', '-map', '3:s', '-map', '4:s',
       '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '40', '-g', '100',
       '-c:a', 'aac', '-b:a', '24k', '-c:s', 'srt',
       '-metadata:s:a:0', 'language=eng', '-metadata:s:a:0', 'title=English',
       '-metadata:s:a:1', 'language=fre', '-metadata:s:a:1', 'title=Francais',
       '-metadata:s:s:0', 'language=eng', '-metadata:s:s:0', 'title=English',
       '-metadata:s:s:1', 'language=fre', '-metadata:s:s:1', 'title=Francais',
       base + '.mkv')
    os.remove(en); os.remove(fr)
# auto-sync: speech-like bursts where the lines are, the .srt 2.4 s late
sync = os.path.join(OUT, 'sync'); os.makedirs(sync, exist_ok=True)
random.seed(7)
rate, dur = 16000, 120
lines, t = [], 3.0
while t < dur - 6:
    d = random.uniform(1.6, 3.6); lines.append((t, t + d)); t += d + random.uniform(1.0, 4.0)
samples = [0.0] * (rate * dur)
for i in range(len(samples)):
    samples[i] = random.gauss(0, 0.01)
for a, b in lines:
    f = random.uniform(3.5, 5.5)
    for i in range(int(a * rate), int(b * rate)):
        env = max(0.0, math.sin(2 * math.pi * f * (i / rate))) ** 2
        samples[i] += random.gauss(0, 0.35) * env
wav = os.path.join(sync, 'speech.wav')
with wave.open(wav, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))
ff('-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24', '-i', wav, '-t', str(dur),
   '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '40', '-c:a', 'aac', '-b:a', '64k',
   os.path.join(sync, 'sync.mp4'))
os.remove(wav)
srt(os.path.join(sync, 'sync-late.srt'), [(a + 2.4, b + 2.4, f'Line {n}') for n, (a, b) in enumerate(lines, 1)])
print('lines', len(lines))
