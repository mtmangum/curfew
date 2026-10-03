import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';
const SRC='/Users/bollox/Projects/sidescroller/src/gfx/';
const OUT='/Users/bollox/Projects/curfew/assets/';
const {PLAYER_GRID,PLAYER_POSES,playerFrameParts}=await import(SRC+'playerFrames.js');
const {DOG_GRID,DOG_POSES,dogFrameParts}=await import(SRC+'dogFrames.js');

const crcT=[...Array(256)].map((_,n)=>{let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
const crc=b=>{let c=~0;for(const x of b)c=crcT[(c^x)&255]^(c>>>8);return ~c>>>0;};
const chunk=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(t),d]);const c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);};
function png(w,h,px){ // px: RGBA Uint8Array
  const raw=Buffer.alloc((w*4+1)*h);
  for(let y=0;y<h;y++){raw[y*(w*4+1)]=0;Buffer.from(px.buffer,y*w*4,w*4).copy(raw,y*(w*4+1)+1);}
  const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]);
}
function render(w,h,rects,scale){ // rects: {x,y,w,h,color}
  const px=new Uint8Array(w*h*4);
  for(const r of rects){
    const R=(r.color>>16)&255,G=(r.color>>8)&255,B=r.color&255;
    for(let y=r.y*scale;y<(r.y+r.h)*scale;y++)for(let x=r.x*scale;x<(r.x+r.w)*scale;x++){
      if(x<0||y<0||x>=w||y>=h)continue;const i=(y*w+x)*4;px[i]=R;px[i+1]=G;px[i+2]=B;px[i+3]=255;}
  }
  return png(w,h,px);
}
const write=(p,b)=>{fs.mkdirSync(path.dirname(OUT+p),{recursive:true});fs.writeFileSync(OUT+p,b);console.log(p,b.length);};
const arr=a=>a.map(([x,y,w,h,color])=>({x,y,w,h,color}));

// Player (Nicole) and dog (Stella)
const P=PLAYER_GRID,D=DOG_GRID;
// The sidescroller dresses both characters in Santa hats; Curfew doesn't. The hat
// colours (red, dark red, white fur, shaded fur) are used by nothing else.
const HAT_COLORS=new Set([0xd62f3f,0x9e1f2f,0xffffff,0xd3d9e3]);
const noHat=parts=>parts.filter(p=>!HAT_COLORS.has(p.color));
const USED_PLAYER=['idle0','fallForward','walk0','walk1','walk2','walk3','walk4','walk5'];
const USED_DOG=['idle','extended0','gathered0'];
for(const pose of PLAYER_POSES.filter(p=>USED_PLAYER.includes(p)))write(`sprites/player/${pose}.png`,render(P.cols*P.pixelSize,P.rows*P.pixelSize,noHat(playerFrameParts(pose)),P.pixelSize));
for(const pose of DOG_POSES.filter(p=>USED_DOG.includes(p)))write(`sprites/dog/${pose}.png`,render(D.cols*D.pixelSize,D.rows*D.pixelSize,noHat(dogFrameParts(pose)),D.pixelSize));

// Stella's walk cycle (the sidescroller's dog only has a gallop and a sit). Same
// body as dogFrames.js `dog()` minus the hat: level back, low tail, four upright
// legs that step in diagonal pairs (front-near with rear-far, then the other pair).
{const DC={outline:0x252633,dark:0x555b68,body:0x9299a5,light:0xc7cbd1,eye:0x17131b,collar:0xd84a62,bell:0xffd54a};
 const q=(x,y,w,h,color)=>({x,y,w,h,color});
 // one leg over the four frames: [x offset, lifted]
 const LEG_A=[[3,0],[0,0],[-3,0],[0,1]], LEG_B=[[-3,0],[0,1],[3,0],[0,0]];
 const walkDog=(f)=>{
  const headX=21,headY=3+(f%2),bodyY=5,tailY=7;
  const leg=(x,pat)=>{const [dx,lift]=pat[f];return lift?[x+dx,10,2,4]:[x+dx,10,2,5];};
  const legs=[leg(9,LEG_A),leg(12,LEG_B),leg(19,LEG_B),leg(22,LEG_A)];
  return [
   q(3,tailY,7,2,DC.outline),q(2,tailY,7,1,DC.dark),q(8,bodyY,12,6,DC.outline),q(9,bodyY,11,4,DC.body),q(10,bodyY,7,1,DC.light),q(7,bodyY+2,5,3,DC.dark),
   q(18,bodyY-2,5,6,DC.outline),q(19,bodyY-2,4,5,DC.body),q(20,bodyY-1,2,1,DC.light),q(21,bodyY-1,1,4,DC.collar),
   q(headX,headY,6,5,DC.outline),q(headX+1,headY+1,5,3,DC.body),q(headX+1,headY-2,3,3,DC.outline),q(headX+2,headY-1,2,2,DC.dark),
   q(headX+5,headY+2,5,2,DC.outline),q(headX+5,headY+1,4,2,DC.body),q(headX+8,headY+1,1,1,DC.light),q(headX+4,headY+1,1,1,DC.eye),
   q(20,bodyY+3,3,2,DC.bell),
   ...legs.flatMap(([x,y,w,h])=>[q(x,y,w,h,DC.outline),q(x+1,y,Math.max(1,w-1),Math.max(1,h-1),DC.dark)])
  ];};
 for(let f=0;f<4;f++)write(`sprites/dog/walk${f}.png`,render(D.cols*D.pixelSize,D.rows*D.pixelSize,walkDog(f),D.pixelSize));}

// Audio: tiny chiptune synth mirroring sidescroller/ChiptuneAudio tone()
const SR=22050;
const mh=m=>440*Math.pow(2,(m-69)/12);
function synth(notes){ // [{f,dur,vol,type,slide,delay}]
  const total=Math.max(...notes.map(n=>(n.delay||0)+n.dur+0.02));
  const buf=new Float32Array(Math.ceil(total*SR));
  for(const n of notes){
    const s0=Math.floor((n.delay||0)*SR),len=Math.floor((n.dur+0.02)*SR);let phase=0;
    for(let i=0;i<len&&s0+i<buf.length;i++){
      const t=i/SR;const p=Math.min(t/n.dur,1);
      const f=n.slide?n.f*Math.pow(n.slide/n.f,p):n.f;
      phase+=f/SR;const ph=phase%1;
      const w=n.type==='sawtooth'?2*ph-1:(ph<0.5?1:-1);
      const env=t<n.dur?Math.pow(0.0001/n.vol,p)*n.vol/n.vol*n.vol:0; // exp decay vol->0.0001
      buf[s0+i]+=w*env;
    }
  }
  return buf;
}
function wav(f){
  const pcm=Buffer.alloc(f.length*2);let peak=0;for(const x of f)peak=Math.max(peak,Math.abs(x));
  const g=peak>0?0.8/peak:1;f.forEach((x,i)=>pcm.writeInt16LE(Math.round(Math.max(-1,Math.min(1,x*g))*32767),i*2));
  const h=Buffer.alloc(44);h.write('RIFF',0);h.writeUInt32LE(36+pcm.length,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(SR,24);h.writeUInt32LE(SR*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(pcm.length,40);
  return Buffer.concat([h,pcm]);
}
const arp=(notes,dur,vol,step)=>notes.map((m,i)=>({f:mh(m),dur,vol,type:'square',delay:i*step}));
write('audio/pickup.wav',wav(synth(arp([79,83,86],0.12,0.06,0.07))));
write('audio/tug.wav',wav(synth([{f:170,dur:0.28,vol:0.1,type:'sawtooth',slide:55}])));
