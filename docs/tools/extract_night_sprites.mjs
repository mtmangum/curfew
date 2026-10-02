import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';
const {COLORS}=await import('/Users/bollox/Projects/sidescroller/src/config.js');
const src=fs.readFileSync('/Users/bollox/Projects/sidescroller/src/scenes/BootScene.js','utf8');
const OUT='/Users/bollox/Projects/curfew/assets/sprites/';
const crcT=[...Array(256)].map((_,n)=>{let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
const crc=b=>{let c=~0;for(const x of b)c=crcT[(c^x)&255]^(c>>>8);return ~c>>>0;};
const chunk=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]);const c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);};
function png(w,h,px){const raw=Buffer.alloc((w*4+1)*h);for(let y=0;y<h;y++){raw[y*(w*4+1)]=0;Buffer.from(px.buffer,y*w*4,w*4).copy(raw,y*(w*4+1)+1);}
 const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;
 return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]);}
function method(name){
  const m=src.match(new RegExp(`\\n  ${name}\\(([^)]*)\\) \\{`));
  if(!m)throw new Error('no '+name);
  const start=m.index+m[0].length, end=src.indexOf('\n  }\n',start);
  return {args:m[1],body:src.slice(start,end)};
}
let captured;
function run(name,...args){
  const {args:a,body}=method(name);
  const fake={drawObstacleTexture:(key,w,h,parts)=>{captured={w,h,parts};}};
  new Function('COLORS',...a.split(',').map(s=>s.trim().split('=')[0].trim()).filter(Boolean),body).call(fake,COLORS,...args);
  return captured;
}
function save(rel,c){
  const w=c.w*2,h=c.h*2,px=new Uint8Array(w*h*4);
  for(const [x,y,rw,rh,col] of c.parts){const R=(col>>16)&255,G=(col>>8)&255,B=col&255;
    for(let yy=y*2;yy<(y+rh)*2;yy++)for(let xx=x*2;xx<(x+rw)*2;xx++){if(xx<0||yy<0||xx>=w||yy>=h)continue;const i=(yy*w+xx)*4;px[i]=R;px[i+1]=G;px[i+2]=B;px[i+3]=255;}}
  fs.mkdirSync(path.dirname(OUT+rel),{recursive:true});fs.writeFileSync(OUT+rel,png(w,h,px));console.log(rel,w,h);
}
for(let i=0;i<4;i++)save(`cop/patrol${i}.png`,run('drawCopObstacle','k',i));
for(let i=0;i<4;i++)save(`cat/run${i}.png`,run('drawCatRunObstacle','k',i));
save('cat/hiss0.png',run('drawCatObstacle','k',false));save('cat/hiss1.png',run('drawCatObstacle','k',true));
save('steamvent/puff0.png',run('drawSteamStackObstacle','k',false));save('steamvent/puff1.png',run('drawSteamStackObstacle','k',true));
save('trashfire/flicker0.png',run('drawTrashFireObstacle','k',false));save('trashfire/flicker1.png',run('drawTrashFireObstacle','k',true));
save('rats/scurry0.png',run('drawScurryingRatsObstacle','k',false));save('rats/scurry1.png',run('drawScurryingRatsObstacle','k',true));
save('boombox/idle.png',run('drawBoomboxObstacle','k',false));save('boombox/boom.png',run('drawBoomboxObstacle','k',true));
save('trashbin/upright.png',run('drawTrashBinObstacle','k',null));
