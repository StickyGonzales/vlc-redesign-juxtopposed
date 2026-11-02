const { chromium } = require('playwright'); const path=require('path');
(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:1920,height:1080},deviceScaleFactor:2});
await p.goto('file://'+path.join(__dirname,'out.html'));await p.evaluate(()=>document.fonts.ready);
for(const v of (process.env.V||'E1,E2').split(',')) for(const t of ['dark','light']) for(const m of ['mute','vol','speed','subs']){
  await p.evaluate(a=>render(...a),[v,t,true,m]); await p.waitForTimeout(40);
  await p.screenshot({path:path.join(__dirname,'tiles','big_'+v+'_'+t+'_'+m+'.png'),clip:{x:660,y:0,width:600,height:130}});
  if(m==='vol'&&t==='dark') await p.screenshot({path:path.join(__dirname,'tiles','whole_'+v+'.png')});
}
await b.close();})();
