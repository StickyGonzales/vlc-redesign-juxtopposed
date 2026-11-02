const { chromium } = require('playwright'); const path=require('path');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:2040,height:1000}});
await p.goto('file://'+path.join(__dirname,'compare.html'));await p.evaluate(()=>document.fonts.ready);await p.waitForTimeout(500);
await p.screenshot({path:path.join(__dirname,'compare.png'),fullPage:true});await b.close();})();
