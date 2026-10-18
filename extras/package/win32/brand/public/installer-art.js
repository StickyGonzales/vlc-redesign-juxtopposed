// redesign: brand layer, draws Cone's installer bitmaps in this folder at their exact sizes
// (redesign/CONE_RELEASE_NOTES.md): the NSIS welcome / finish side image and page header image,
// and the WixUI banner and dialog images of the MSI. App style: background Dark/BG/B1 #0E0E0E,
// the Cone logo in Accent #D37918, Inter text in Dark/FG/1 #EAEAEA and Dark/FG/A1 #969696.
// Needs Node with Playwright (Chromium), the Inter font and ImageMagick:
//   NODE_PATH=<folder holding playwright> node installer-art.js
// then for each name: convert <name>.png -alpha off -type TrueColor BMP3:<name>.bmp
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
// the logo file fills with #FF8800, the accent slot of the in-app SVG colorizer
const logo = fs.readFileSync(path.join(__dirname, '../../../../../modules/gui/qt/pixmaps/brand/public/cone-logo.svg'),
                             'utf8').replace(/#FF8800/gi, '#D37918');
const logoUri = 'data:image/svg+xml;base64,' + Buffer.from(logo).toString('base64');
const base = `*{margin:0;padding:0;box-sizing:border-box}
html,body{background:#0E0E0E;font-family:Inter,sans-serif;-webkit-font-smoothing:antialiased;overflow:hidden}`;
const pages = {
  // MUI2 welcome / finish side image: 164 x 314
  'nsis-welcome': { w: 164, h: 314, html: `<style>${base}
    .glow{position:absolute;left:-40px;top:52px;width:244px;height:180px;
      background:radial-gradient(closest-side,rgba(211,121,24,.16),rgba(211,121,24,0))}
    .logo{position:absolute;left:42px;top:96px;width:72px;height:72px}
    .name{position:absolute;left:0;right:0;top:184px;text-align:center;color:#EAEAEA;
      font-size:26px;font-weight:600;letter-spacing:-0.4px}
    .sub{position:absolute;left:0;right:0;top:220px;text-align:center;color:#969696;font-size:11px;
      font-weight:400;letter-spacing:.2px}
    .bar{position:absolute;left:0;right:0;bottom:0;height:3px;background:#D37918}
    </style><div class=glow></div><img class=logo src="${logoUri}"><div class=name>Cone</div>
    <div class=sub>Media player</div><div class=bar></div>` },
  // MUI2 page header image: 150 x 57
  'nsis-header': { w: 150, h: 57, html: `<style>${base}
    .logo{position:absolute;left:28px;top:14px;width:29px;height:29px}
    .name{position:absolute;left:62px;top:15px;color:#EAEAEA;font-size:20px;font-weight:600;
      letter-spacing:-0.3px;line-height:26px}
    </style><img class=logo src="${logoUri}"><div class=name>Cone</div>` },
  // WixUI banner: 493 x 58, the dialog title is drawn in black over its left part
  'msi-banner': { w: 493, h: 58, html: `<style>${base} body{background:#FFFFFF}
    .panel{position:absolute;right:0;top:0;width:150px;height:58px;background:#0E0E0E}
    .logo{position:absolute;left:28px;top:14px;width:29px;height:29px}
    .name{position:absolute;left:62px;top:15px;color:#EAEAEA;font-size:20px;font-weight:600;
      letter-spacing:-0.3px;line-height:26px}
    </style><div class=panel><img class=logo src="${logoUri}"><div class=name>Cone</div></div>` },
  // WixUI welcome / exit dialog image: 493 x 312, text is drawn right of x = 164
  'msi-dialog': { w: 493, h: 312, html: `<style>${base} body{background:#FFFFFF}
    .panel{position:absolute;left:0;top:0;width:164px;height:312px;background:#0E0E0E;overflow:hidden}
    .glow{position:absolute;left:-40px;top:51px;width:244px;height:180px;
      background:radial-gradient(closest-side,rgba(211,121,24,.16),rgba(211,121,24,0))}
    .logo{position:absolute;left:42px;top:95px;width:72px;height:72px}
    .name{position:absolute;left:0;right:0;top:183px;text-align:center;color:#EAEAEA;
      font-size:26px;font-weight:600;letter-spacing:-0.4px}
    .sub{position:absolute;left:0;right:0;top:219px;text-align:center;color:#969696;font-size:11px;letter-spacing:.2px}
    .bar{position:absolute;left:0;right:0;bottom:0;height:3px;background:#D37918}
    </style><div class=panel><div class=glow></div><img class=logo src="${logoUri}">
    <div class=name>Cone</div><div class=sub>Media player</div><div class=bar></div></div>` },
};
(async () => {
  const browser = await chromium.launch();
  for (const [name, p] of Object.entries(pages)) {
    const page = await browser.newPage({ viewport: { width: p.w, height: p.h }, deviceScaleFactor: 1 });
    await page.setContent(p.html);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: `${__dirname}/${name}.png` });
  }
  await browser.close();
})();
