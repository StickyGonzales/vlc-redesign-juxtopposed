const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const dir = __dirname;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  await p.goto('file://' + path.join(dir, 'out.html'));
  await p.evaluate(() => document.fonts.ready);
  const only = process.argv[2];
  const rects = {};
  for (const v of ['A', 'B', 'C']) for (const t of ['dark', 'light']) for (const bar of [1, 0]) for (const m of ['mute', 'vol', 'speed', 'subs']) {
    const name = `${v}_${t}_${bar ? 'bar' : 'nobar'}_${m}`;
    if (only && name !== only) continue;
    rects[name] = await p.evaluate(([v, t, bar, m]) => render(v, t, !!bar, m), [v, t, bar, m]);
    await p.waitForTimeout(30);
    await p.screenshot({ path: path.join(dir, 'tiles', name + '.png'), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  }
  require('fs').writeFileSync(path.join(dir, 'tiles', 'rects.json'), JSON.stringify(rects));
  await b.close();
})();
