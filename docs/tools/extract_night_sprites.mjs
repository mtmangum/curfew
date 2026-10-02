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
// A calm cop: the same frames without the raised arm and club (which the source
// draws first: CLUB parts, then 3 raised-arm parts, then the body with its
// ordinary arm hanging at his side). The raised-club frames above are for a chase.
const CLUB_PARTS=[4,4,5,4];
// ...and his front arm comes down holding a flashlight out in front of him (the
// source only draws that arm raised). Canvas coordinates are absolute.
{const O=0x151923,B=0x355783,S=0xe6ad92,BODY=0x2a2d38,RING=0x9aa3b5,LENS=0xfff2b0;
 for(let i=0;i<4;i++){const c=run('drawCopObstacle','k',i);const b=i%2;
  const torch=[
   [19,20+b,5,8,O],[20,21+b,3,6,B],            // upper arm
   [21,26+b,6,4,O],[22,27+b,4,2,B],             // forearm, bent forward
   [25,27+b,3,3,S],                              // hand
   [26,26+b,3,3,BODY],[28,26+b,1,3,RING],[29,26+b,1,3,LENS] // flashlight: body, rim, lens
  ];
  save(`cop/walk${i}.png`,{...c,parts:[...c.parts.slice(CLUB_PARTS[i]+3),...torch]});}}
for(let i=0;i<4;i++)save(`cat/run${i}.png`,run('drawCatRunObstacle','k',i));
// A sitting cat (the source art only has a run cycle and a hiss), in the same
// palette and facing left like the others. sit1 is a blink with the tail tip up.
{const O=0x1d1b25,D=0x34323e,M=COLORS.catBody,L=0x716d7b,E=COLORS.catEye,NOSE=0xd88a8a;
 const sit=(blink)=>({w:30,h:27,parts:[
  // tail along the ground behind, tip lifted on the blink frame
  [16,24,11,2,O],[17,24,10,1,M],...(blink?[[26,21,2,4,O],[26,22,1,3,M]]:[[27,23,2,2,O]]),
  // haunch and hind paw
  [14,13,10,12,O],[15,14,8,10,M],[16,15,4,5,L],[15,22,7,2,D],[13,23,7,3,O],[14,24,5,1,D],
  // upright chest
  [8,9,9,16,O],[9,10,7,14,M],[9,11,3,5,L],[9,22,7,2,D],
  // front legs and paws
  [7,18,3,8,O],[8,19,1,6,M],[5,24,6,2,O],[6,25,4,1,D],
  // head: ears, face, eye and nose
  [3,0,3,4,O],[4,1,1,3,L],[9,0,3,4,O],[10,1,1,3,L],
  [3,3,10,9,O],[4,4,8,7,M],[4,4,4,2,L],
  ...(blink?[[5,7,3,1,O]]:[[5,7,2,2,E],[5,7,1,1,O]]),
  [2,8,2,2,O],[3,8,1,1,NOSE],[3,11,7,1,D]
 ]});
 save('cat/sit0.png',sit(false));save('cat/sit1.png',sit(true));}
save('cat/hiss0.png',run('drawCatObstacle','k',false));save('cat/hiss1.png',run('drawCatObstacle','k',true));
save('steamvent/puff0.png',run('drawSteamStackObstacle','k',false));save('steamvent/puff1.png',run('drawSteamStackObstacle','k',true));
save('trashfire/flicker0.png',run('drawTrashFireObstacle','k',false));save('trashfire/flicker1.png',run('drawTrashFireObstacle','k',true));
save('rats/scurry0.png',run('drawScurryingRatsObstacle','k',false));save('rats/scurry1.png',run('drawScurryingRatsObstacle','k',true));
save('boombox/idle.png',run('drawBoomboxObstacle','k',false));save('boombox/boom.png',run('drawBoomboxObstacle','k',true));
save('trashbin/upright.png',run('drawTrashBinObstacle','k',null));
