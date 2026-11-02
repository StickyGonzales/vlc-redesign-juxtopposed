import base64, re, pathlib, json
M = pathlib.Path(__file__).resolve().parent.parent
def b64(p): return base64.b64encode((M/p).read_bytes()).decode()
def svg(p):
    s = (M/p).read_text()
    return s.replace('#FF00FF', 'currentColor').replace('width="24" height="24"', 'width="100%" height="100%"')
vol = svg('volume_value-high.svg')
# mute: Cone's speaker (the volume icon's first path) and a cross
spk = re.search(r'<path d="[^"]+"[^>]*/>', vol).group(0)
mute = ('<svg width="100%" height="100%" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">' + spk +
        '<path d="M16.5 9.5L21.5 14.5M21.5 9.5L16.5 14.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>')
icons = {'mute': mute, 'vol': vol, 'speed': svg('speed.svg'), 'subs': svg('subtitles.svg')}
cone = (M/'cone-logo.svg').read_text().replace('#FF8800', 'currentColor').replace('width="240" height="240"', 'width="100%" height="100%"')
html = (M/'work/page.html').read_text()
html = html.replace('%%FRAME%%', b64('dl/f_000310.png'))
for t in ('dark', 'light'):
    html = html.replace('%%TOP_' + t.upper() + '%%', b64('top_%s.png' % t)).replace('%%BAR_' + t.upper() + '%%', b64('bar_%s.png' % t))
html = html.replace('%%ICONS%%', json.dumps(icons)).replace('%%CONE%%', json.dumps(cone))
wedge = {k: 'data:image/png;base64,' + b64('wedge_%s.png' % k) for k in ('80_dark', '80_light', '0_dark', '0_light')}
html = html.replace('%%WEDGE%%', json.dumps(wedge))
(M/'work/out.html').write_text(html)
