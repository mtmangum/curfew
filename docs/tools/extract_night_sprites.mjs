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
// Street characters, authored here (the sidewalk source has none): a crazy hobo, a
// street punk and a mean skateboarder, all facing right like the cop, on a 24x40 grid.
{const q=(x,y,w,h,color)=>[x,y,w,h,color];
 const mk=(parts)=>({w:24,h:40,parts});
 // --- hobo: beanie, grey beard, ragged olive coat, a bottle in one hand
 const H={O:0x1a1612,coat:0x5b5a3a,coatD:0x3d3d27,patch:0x7a4a3a,skin:0xc99a7a,beard:0x9aa0a6,hat:0x7a2f2f,hatD:0x4f1f1f,pants:0x3a3a45,pantsD:0x2a2a33,shoe:0x2a2420,bottle:0x6b4a2a,glass:0x58a068,mouth:0x2a0f0f};
 const hobo=(legsPhase,rant,mouth)=>{
  const bob=legsPhase%2;
  const legs=legsPhase<2?[q(7,27,5,11,H.O),q(8,28,3,9,H.pants),q(5,36,7,3,H.shoe),q(13,27,5,11,H.O),q(14,28,3,9,H.pantsD),q(13,36,7,3,H.shoe)]
                         :[q(8,27,5,11,H.O),q(9,28,3,9,H.pants),q(6,36,7,3,H.shoe),q(12,27,5,11,H.O),q(13,28,3,9,H.pantsD),q(12,36,7,3,H.shoe)];
  const front=rant?[q(17,8,4,10,H.O),q(18,9,2,8,H.coat),q(17,5,4,4,H.skin),q(18,0,3,6,H.bottle),q(19,1,1,4,H.glass)]
                   :[q(17,15,4,9,H.O),q(18,16,2,7,H.coat),q(18,23,3,3,H.skin),q(20,18,2,6,H.bottle),q(20,19,1,3,H.glass)];
  return [...legs,
   q(5,12+bob,14,15,H.O),q(6,12+bob,12,14,H.coat),q(6,12+bob,12,2,H.coatD),q(9,17+bob,4,3,H.patch),
   q(6,26,3,2,H.coat),q(11,27,2,1,H.coat),q(15,26,3,2,H.coat),
   q(3,14+bob,4,10,H.O),q(4,15+bob,2,8,H.coatD),q(3,23+bob,3,3,H.skin),
   q(7,2+bob,10,4,H.O),q(8,2+bob,8,3,H.hat),q(8,4+bob,8,2,H.hatD),
   q(8,6+bob,9,8,H.O),q(9,6+bob,7,5,H.skin),q(14,7+bob,1,1,H.O),q(9,10+bob,8,4,H.O),q(10,10+bob,6,3,H.beard),
   ...(mouth?[q(12,11+bob,3,2,H.mouth)]:[]),
   ...front];
 };
 save('hobo/shuffle0.png',mk(hobo(0,false,false)));save('hobo/shuffle1.png',mk(hobo(1,false,false)));
 save('hobo/shuffle2.png',mk(hobo(2,false,false)));save('hobo/shuffle3.png',mk(hobo(3,false,false)));
 save('hobo/rant0.png',mk(hobo(0,true,true)));save('hobo/rant1.png',mk(hobo(1,true,false)));

 // --- punk: pink mohawk, black studded jacket, torn jeans, boots
 const P={O:0x14161c,mohawk:0xff3d8b,mohawkL:0xff86b4,skin:0xd6a285,jacket:0x23252e,jacketL:0x3a3d4b,stud:0xd0d4dc,jeans:0x3a5a8a,jeansD:0x2a4268,boot:0x15171d,chain:0xaab0bc,mouth:0x2a0f0f};
 const punk=(phase,shove)=>{
  const bob=phase%2;
  const legs=phase<2?[q(7,26,5,11,P.O),q(8,27,3,9,P.jeans),q(5,36,8,3,P.boot),q(13,26,5,11,P.O),q(14,27,3,9,P.jeansD),q(13,36,8,3,P.boot)]
                     :[q(9,26,5,11,P.O),q(10,27,3,9,P.jeans),q(7,36,8,3,P.boot),q(12,26,5,11,P.O),q(13,27,3,9,P.jeansD),q(12,36,8,3,P.boot)];
  const arms=shove?[q(3,15,5,4,P.O),q(4,16,3,2,P.jacket),q(16,15,8,4,P.O),q(17,16,6,2,P.jacket),q(22,15,2,4,P.skin)]
                  :[q(3,14,4,11,P.O),q(4,15,2,9,P.jacket),q(3,24,3,3,P.skin),q(17,14,4,11,P.O),q(18,15,2,9,P.jacketL),q(18,24,3,3,P.skin)];
  return [...legs,
   q(5,11+bob,14,15,P.O),q(6,11+bob,12,14,P.jacket),q(6,11+bob,12,2,P.jacketL),
   q(8,13+bob,1,1,P.stud),q(11,13+bob,1,1,P.stud),q(14,13+bob,1,1,P.stud),q(16,15+bob,1,1,P.stud),q(8,20+bob,1,1,P.stud),q(10,17+bob,5,1,P.chain),
   ...arms,
   q(11,0+bob,2,4,P.mohawk),q(9,1+bob,2,3,P.mohawk),q(13,1+bob,2,3,P.mohawk),q(11,0+bob,1,3,P.mohawkL),
   q(8,3+bob,9,8,P.O),q(9,3+bob,7,7,P.skin),q(14,6+bob,1,1,P.O),q(12,9+bob,4,1,P.mouth)];
 };
 for(let i=0;i<4;i++)save(`punk/walk${i}.png`,mk(punk(i,false)));
 save('punk/shove.png',mk(punk(0,true)));

 // --- skateboarder: cap, red hoodie, crouched on a teal board
 const S={O:0x15161c,cap:0x2a3f6a,hood:0xb04a3a,hoodD:0x7a3228,skin:0xc99a7a,jeans:0x4a5470,deck:0x2a8a8a,deckL:0x5ac0c0,wheel:0x0f1014,mouth:0x2a0f0f};
 const skater=(tilt,bail)=>{
  if(bail)return [q(2,35,20,3,S.O),q(3,35,18,2,S.hood),q(14,33,7,3,S.O),q(15,33,5,2,S.skin),q(0,34,5,3,S.deck),q(19,36,3,2,S.jeans),q(20,38,4,2,S.wheel)];
  const t=tilt?1:0;
  return [
   q(2,35+t,20,3,S.O),q(3,35+t,18,2,S.deck),q(3,35+t,18,1,S.deckL),q(4,38+t,4,2,S.wheel),q(16,38-t,4,2,S.wheel),
   q(7,24+t,5,12,S.O),q(8,25+t,3,10,S.jeans),q(13,24-t,5,12,S.O),q(14,25-t,3,10,S.jeans),
   q(6,14,12,12,S.O),q(7,14,10,10,S.hood),q(7,14,10,2,S.hoodD),
   q(1,15+t,7,3,S.O),q(2,16+t,5,1,S.hood),q(16,14-t,7,3,S.O),q(17,15-t,5,1,S.hood),
   q(7,4,10,9,S.O),q(8,5,8,7,S.skin),q(14,7,1,1,S.O),q(11,10,4,1,S.mouth),
   q(6,2,12,4,S.O),q(7,2,10,3,S.cap),q(15,4,6,2,S.cap)];
 };
 save('skater/ride0.png',mk(skater(false,false)));save('skater/ride1.png',mk(skater(true,false)));save('skater/bail.png',mk(skater(false,true)));
}
save('cat/hiss0.png',run('drawCatObstacle','k',false));save('cat/hiss1.png',run('drawCatObstacle','k',true));
save('steamvent/puff0.png',run('drawSteamStackObstacle','k',false));save('steamvent/puff1.png',run('drawSteamStackObstacle','k',true));
save('trashfire/flicker0.png',run('drawTrashFireObstacle','k',false));save('trashfire/flicker1.png',run('drawTrashFireObstacle','k',true));
save('rats/scurry0.png',run('drawScurryingRatsObstacle','k',false));save('rats/scurry1.png',run('drawScurryingRatsObstacle','k',true));
save('boombox/idle.png',run('drawBoomboxObstacle','k',false));save('boombox/boom.png',run('drawBoomboxObstacle','k',true));
save('trashbin/upright.png',run('drawTrashBinObstacle','k',null));
