import base64, json, pathlib, re
M = pathlib.Path(__file__).resolve().parent.parent
def svg(p): return (M/p).read_text().replace('#FF00FF','currentColor').replace('width="24" height="24"','width="100%" height="100%"')
I = {n: svg('i_%s.svg' % n) for n in ['audio','video','chapters','playback','repeat_direction-right','shuffle_direction-right','snapshot','record','bookmark','eye','view','window','next','previous','play','pause','tv','interface','hdr','info','file','sidebar_direction-right']}
I['vol'] = svg('volume_value-high.svg'); I['speed'] = svg('speed.svg'); I['subs'] = svg('subtitles.svg')
spk = re.search(r'<path d="[^"]+"[^>]*/>', I['vol']).group(0)
I['mute'] = '<svg width="100%" height="100%" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'+spk+'<path d="M16.5 9.5L21.5 14.5M21.5 9.5L16.5 14.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>'
b64 = lambda p: 'data:image/png;base64,' + base64.b64encode((M/p).read_bytes()).decode()
W = {k: b64('wedge_%s_dark.png' % k) for k in ('80','0','200')}
# (icon, label, value, key) ; value None = label only ; special 'cone80'/'cone0'
G = [
 ('1. Toggles', [('window','Scaled to screen',None,'O'),('window','Original size',None,'O'),('eye','Deinterlace','On (Yadif)','D'),
   ('record','Recording',None,'Shift + R'),('record','Recording done',None,'Shift + R'),('subs','Subtitle control','Secondary','Ctrl + Shift + V'),('mute','cone0','Muted','M')]),
 ('2. Values', [('vol','cone80','80%','Ctrl + ↑'),('vol','cone200','200%','Ctrl + ↑'),('speed','Speed','1.5×',']'),('audio','Audio delay','+50 ms','K'),('subs','Subtitle delay','−250 ms','G'),
   ('view','Zoom','×1.10','Alt + O'),('view','Zoom reset',None,'O'),('window','Top crop','12 px','Alt + R'),('subs','Subtitle position','40 px',None),
   ('subs','Sub sync','Audio time bookmarked','Shift + H'),('subs','Sub sync','Subtitle time bookmarked','Shift + J'),('subs','Sub sync','Set both bookmarks first','Shift + K'),
   ('subs','Sub sync','Corrected 120 ms (delay 370 ms)','Shift + K'),('subs','Sub sync','Delay reset','Ctrl + Shift + K')]),
 ('3. Tracks and modes', [('audio','Audio','English','B'),('subs','Subtitles','English','V'),('subs','Subtitles','Off','Shift + V'),('subs','Subtitles','English, Hindi',None),
   ('video','Video track','Track 2',None),('tv','Program','BBC One HD','X'),('window','Aspect ratio','16:9','A'),('window','Crop','2.35:1','C'),('view','Zoom','2:1 Double','Z'),
   ('view','Projection','Equirectangular',None),('shuffle_direction-right','Shuffle','On','R'),('repeat_direction-right','Loop','All','L'),('audio','Audio device','Speakers (Realtek)','Shift + A')]),
 ('4. Time and navigation', [('playback','00:12:40',' / 00:42:10','Shift + →'),('chapters','Next chapter',None,'Shift + N'),('chapters','Chapter 3','The Gate',None),
   ('disc' if False else 'playback','Next title',None,'Shift + B'),('next','Next',None,'N'),('previous','Previous',None,'P'),('playback','Next frame',None,'E')]),
 ('5. Play state', [('pause','Paused',None,'Space'),('play','Playing',None,'Space')]),
 ('6. Titles and files', [('snapshot','Snapshot saved','vlcsnap-2026-11-02-22h40.png','Shift + S'),('subs','Subtitle file added','Sintel.en.srt',None),('file','Sintel',None,None)]),
 ('8. Interface', [('interface','Interface scale','125%','Ctrl + ='),('interface','Minimal view',None,'Ctrl + H'),('bookmark','Bookmark added','00:12:40','Ctrl + B')]),
]
def pop(ic,label,val,key):
    k = f'<span class="key">{key}</span>' if key else ''
    if label.startswith('cone'):
        lvl = label[4:]
        img = W[lvl]
        style = ''
        return f'<div class="H"><span class="ic">{I[ic]}</span><img class="wedge" {style} src="{img}"><span class="{"tx" if val=="Muted" else "tv"}">{val}</span>{k}</div>'
    body = f'<span class="tx">{label}</span>' + (f'<span class="v">{val}</span>' if val else '')
    return f'<div class="H"><span class="ic">{I[ic]}</span>{body}{k}</div>'
frame = b64('dl/f_000310.png')
h = ['''<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}body{background:#0E0E0E;font-family:Inter;color:#EAEAEA;width:1280px;padding:28px 30px}
h1{font-size:22px;font-weight:600;margin-bottom:6px}.sub{font-size:13px;color:#969696;line-height:1.5;margin-bottom:18px}
h2{font-size:17px;font-weight:600;color:#D37918;margin:18px 0 8px}
.grid{display:flex;flex-wrap:wrap;gap:10px}
.cell{width:605px;height:84px;border-radius:6px;background:url(%s) 0 -130px/1280px auto;display:flex;align-items:center;justify-content:center}
.cell:nth-child(2n){background-position:-560px -150px}
.H{height:44px;border-radius:10px;background:rgba(25,25,25,.95);border:1px solid #222;box-shadow:0 8px 15px rgba(0,0,0,.46);
   display:flex;align-items:center;gap:10px;padding:0 10px 0 10px;font-size:15px;color:#8F8F8F;white-space:nowrap;max-width:585px}
.ic{width:24px;height:24px;color:#8F8F8F;flex:none;display:inline-block}
.tx{color:#C6C6C6;font-weight:500}.v{color:#EAEAEA;font-weight:500;overflow:hidden;text-overflow:ellipsis}.tv{color:#8F8F8F;font-variant-numeric:tabular-nums}
.wedge{width:94px;height:30px}
.key{display:inline-flex;align-items:center;height:22px;padding:0 7px;border-radius:4px;font-size:12px;font-weight:500;background:#222;color:#8F8F8F;border:1px solid #373737;margin-left:2px;flex:none}
</style></head><body><h1>Every on-screen message in the final style (dark theme, shown at 2x)</h1>
<div class="sub">The rows of OSD_INVENTORY.md by group, as Cone would show them, top center under the top bar's place, one at a time. Volume and Muted use the volume cone; every other message is icon, name, value and the key that did it (none for menu clicks or the mouse). The light theme uses the same layout with the light colors (see OSD_final_closeup.jpg). Wording fixes from the inventory are applied (chapters count from 1, Speed and the category names translated). Picture: Sintel (c) Blender Foundation, CC BY 3.0.</div>''' % frame]
for title, items in G:
    h.append(f'<h2>{title}</h2><div class="grid">')
    for it in items: h.append(f'<div class="cell">{pop(*it)}</div>')
    h.append('</div>')
h.append('</body></html>')
(M/'work/all.html').write_text(''.join(h))
