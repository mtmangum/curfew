import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';
const SRC='/Users/bollox/Projects/sidescroller/src/gfx/';
const OUT='/Users/bollox/Projects/leash-walk/assets/';
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
for(const pose of PLAYER_POSES)write(`sprites/player/${pose}.png`,render(P.cols*P.pixelSize,P.rows*P.pixelSize,playerFrameParts(pose),P.pixelSize));
for(const pose of DOG_POSES)write(`sprites/dog/${pose}.png`,render(D.cols*D.pixelSize,D.rows*D.pixelSize,dogFrameParts(pose),D.pixelSize));

// Pigeon: copied from sidescroller BootScene.drawPigeonFrame (24x14 grid, 2x)
{const O=0x252832,Dk=0x555b66,M=0x858b94,L=0xbcc0c5,NECK=0x5f7473,EYE=0xe4bb4f;
 for(const wp of [0,1,2]){
  const wings=wp===0?[[8,1,5,7,O],[9,2,4,6,L],[12,4,6,5,O],[13,5,5,3,M]]:wp===1?[[8,6,10,5,O],[9,7,8,3,L],[13,9,7,3,O],[14,9,6,2,M]]:[[9,5,8,5,O],[10,6,7,3,L],[12,9,5,4,O],[13,9,4,3,M]];
  const parts=[...wings,[6,6,12,6,O],[7,6,10,5,M],[8,7,6,2,L],[3,5,6,6,O],[4,6,5,4,NECK],[1,7,4,2,O],[0,8,4,1,0xd2a34b],[5,6,1,1,EYE],[17,7,6,3,O],[18,7,5,2,Dk],[20,6,4,2,O],[9,11,2,3,O],[10,11,1,2,0xb06d55],[14,11,2,3,O],[15,11,1,2,0xb06d55]];
  write(`sprites/pigeon/fly${wp}.png`,render(48,28,arr(parts),2));}}

// Squirrel and pizza: new, drawn in the same rect-list style (2x grid)
{const O=0x2a1a12,Dk=0x6b3d1f,M=0x9a5a2b,L=0xc98a4b,CR=0xe9d3a8,EYE=0x111111;
 const parts=[ // 20x20 facing right, big curled tail on the left
  [1,3,5,12,O],[2,2,5,3,O],[2,4,4,10,M],[3,3,3,2,L],[1,8,2,5,Dk],[4,13,6,3,O],
  [5,9,10,8,O],[6,10,8,6,M],[7,11,4,4,CR],[6,16,3,2,O],[12,16,4,2,O],[13,16,2,1,Dk],
  [13,5,6,7,O],[14,6,5,5,M],[16,7,1,1,EYE],[18,8,2,2,O],[19,8,1,1,0x111111],
  [14,3,2,3,O],[15,4,1,2,Dk],[17,3,2,3,O],[17,4,1,2,L],[9,12,3,2,L]];
 write('sprites/squirrel/idle.png',render(40,40,arr(parts),2));
 const hop=parts.map(([x,y,w,h,c])=>[x,y-2,w,h,c]);
 write('sprites/squirrel/hop.png',render(40,40,arr(hop),2));}
{const O=0x3a1a10,CR=0xe8b24a,CRD=0xc58a2c,SA=0xd9382b,SAL=0xf06a4f,CH=0xffd95a,PEP=0x8a1f24;
 const parts=[ // 20x20 slice pointing down-right
  [1,2,18,3,O],[2,2,16,2,CR],[2,2,16,1,CRD],
  [2,5,16,2,O],[3,5,14,1,CH],[3,6,14,1,SA],
  [3,7,14,2,O],[4,7,12,2,SA],[5,7,4,1,SAL],[7,8,2,2,PEP],[12,8,2,2,PEP],
  [4,9,12,2,O],[5,9,10,2,CH],[8,10,2,1,CRD],
  [5,11,10,2,O],[6,11,8,1,SA],[6,12,8,1,SAL],[9,12,2,2,PEP],
  [6,13,8,2,O],[7,13,6,1,CH],
  [7,15,6,2,O],[8,15,4,1,SA],[8,17,4,1,O],[9,17,2,1,SA],[9,18,2,1,O]];
 write('sprites/pizza/slice.png',render(40,40,arr(parts),2));}

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
write('audio/bark.wav',wav(synth([{f:185,dur:0.08,vol:0.075,type:'square',slide:115},{f:155,dur:0.1,vol:0.065,type:'square',slide:95,delay:0.11}])));
write('audio/lure_drop.wav',wav(synth([{f:330,dur:0.1,vol:0.06,type:'square',slide:620},{f:620,dur:0.08,vol:0.05,type:'square',slide:880,delay:0.1}])));
write('audio/tug.wav',wav(synth([{f:170,dur:0.28,vol:0.1,type:'sawtooth',slide:55}])));
