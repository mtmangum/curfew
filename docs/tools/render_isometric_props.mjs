// Curfew's bins and burn barrels: raised-camera cylinders with 2:1 top ellipses.
// Keep the original 2x pixel grid, texture sizes, and bottom-centre foot anchor.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Frame, rasterise} from './pixel_shapes.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const palette = {
  o:0x151923, d:0x303640, m:0x505b66, l:0x7c8991, h:0xa9b4b6,
  t:0x65737b, i:0x242a31, r:0x6e4937, s:0x49352d, b:0x977052,
  a:0xd09962, e:0xf16d25, f:0xffaa39, g:0xffd66b, w:0xffefb5,
};
function ellipse(frame,cx,cy,rx,ry,ch){
  for(let y=0;y<frame.h;y++)for(let x=0;x<frame.w;x++)
    if(((x+.5-cx)/rx)**2+((y+.5-cy)/ry)**2<=1)frame.set(x,y,ch);
}
function line(frame,x0,y0,x1,y1,ch){
  const n=Math.max(Math.abs(x1-x0),Math.abs(y1-y0));
  for(let i=0;i<=n;i++)frame.set(Math.round(x0+(x1-x0)*i/n),Math.round(y0+(y1-y0)*i/n),ch);
}
function polygon(frame,points,ch){
  for(let y=0;y<frame.h;y++)for(let x=0;x<frame.w;x++){
    let inside=false;
    for(let i=0,j=points.length-1;i<points.length;j=i++){
      const [xi,yi]=points[i], [xj,yj]=points[j];
      if((yi>y+.5)!==(yj>y+.5)&&x+.5<(xj-xi)*(y+.5-yi)/(yj-yi)+xi)inside=!inside;
    }
    if(inside)frame.set(x,y,ch);
  }
}
function cylinder(frame,cx,top,bottom,rx,ry,tones){
  // Vertical sides and a curved base; the light comes from above-left.
  ellipse(frame,cx,bottom,rx,ry,'o');
  for(let y=top;y<bottom;y++)for(let x=cx-rx;x<cx+rx;x++)frame.set(x,y,'o');
  for(let y=top;y<=bottom+ry-1;y++)for(let x=cx-rx+1;x<cx+rx-1;x++){
    if(frame.get(x,y)!=='o')continue;
    if(y>=bottom&&((x+.5-cx)/(rx-1))**2+((y+.5-bottom)/(ry-1))**2>1)continue;
    const shade=x<cx-rx*.55?0:x<cx+rx*.25?1:2;
    frame.set(x,y,tones[shade]);
  }
}
function frontRim(frame,cx,cy,rx,ry,ch){
  for(let x=cx-rx;x<cx+rx;x++){
    const u=(x+.5-cx)/rx;
    frame.set(x,Math.floor(cy+ry*Math.sqrt(1-u*u)),ch);
  }
}
export function trashBin(){
  const f=new Frame(30,36);
  cylinder(f,15,9,30,10,4,['m','d','i']);
  // Pressed vertical ribs follow the curvature of the lower rim.
  for(const [x,depth] of [[7,1],[10,2],[14,3],[18,3],[22,1]]){
    line(f,x,12,x,29+depth,x<15?'l':'m');
    line(f,x+1,12,x+1,29+depth,'o');
  }
  frontRim(f,15,14,10,3,'m');
  frontRim(f,15,28,10,3,'m');
  frontRim(f,15,30,10,4,'o');
  frontRim(f,15,29,9,3,'l');
  // A broad, visibly elliptical lid, with a separate dark lower lip.
  ellipse(f,15,9,12,5,'o');
  ellipse(f,15,8,11,4,'m');
  ellipse(f,15,7,11,4,'o');
  ellipse(f,15,7,10,3,'t');
  ellipse(f,13,6,7,2,'l');
  line(f,7,6,13,4,'h');
  // Raised handle lies along one ground axis (two across for one down).
  line(f,12,3,17,5,'o');line(f,12,2,17,4,'h');
  line(f,12,2,12,4,'o');line(f,17,4,17,6,'o');
  // Side lifting handles, with the far side kept in shadow.
  line(f,3,13,3,17,'o');line(f,4,13,4,16,'l');
  line(f,25,14,26,14,'m');line(f,26,14,26,18,'o');
  return f;
}
export function trashFire(variant){
  const f=new Frame(28,36);
  cylinder(f,14,19,30,10,4,['b','r','s']);
  // Steel hoops wrap around the barrel instead of reading as flat stripes.
  for(const y of [23,29]){
    frontRim(f,14,y,10,3,'o');
    frontRim(f,14,y-1,10,3,'m');
    frontRim(f,12,y-1,7,2,'l');
  }
  line(f,20,22,20,28,'s');line(f,7,21,7,24,'a');
  f.set(11,27,'s');f.set(12,27,'s');f.set(16,24,'b');
  // Open elliptical mouth: back rim and coals are visible behind the flames.
  ellipse(f,14,19,11,5,'o');ellipse(f,14,18,10,4,'l');
  ellipse(f,14,18,9,3,'i');ellipse(f,14,19,7,2,'e');
  const v=variant;
  polygon(f,[[7,20],[6,14],[9,16],[9+v,8],[12,11],[14-v,2],[17,8],[17,12],[21,7+v*2],[20,15],[23,13],[22,20],[17,22],[11,22]],'e');
  polygon(f,[[8,19],[10,13],[12,16],[14+v,6],[16,12],[18,16],[20,12+v],[21,19],[16,21],[11,21]],'f');
  polygon(f,[[11,19],[13,14],[14,16],[16-v,11],[17,17],[19,19],[16,21],[12,21]],'g');
  polygon(f,[[13,20],[14+v,16],[17,20],[15,21]],'w');
  // Foreground rim masks the flame roots, grounding the fire inside the can.
  frontRim(f,14,19,11,4,'o');frontRim(f,14,18,10,4,'b');
  line(f,9,21,14,22,'a');
  return f;
}
export function renderIsometricProps(){
  for(const [rel,frame] of [['trashbin/upright.png',trashBin()],['trashfire/flicker0.png',trashFire(0)],['trashfire/flicker1.png',trashFire(1)]]){
    const dest=path.join(root,'assets/sprites',rel);
    fs.mkdirSync(path.dirname(dest),{recursive:true});
    fs.writeFileSync(dest,rasterise([frame],2,palette));
    console.log(`Isometric ${rel}: ${frame.w*2} × ${frame.h*2}`);
  }
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  renderIsometricProps();
  if(process.argv[2]==='preview'){
    const frames=[trashBin(),...Array.from({length:2},(_,i)=>{
      const f=new Frame(30,36),fire=trashFire(i);
      fire.g.forEach((row,y)=>row.forEach((ch,x)=>f.set(x+1,y,ch)));
      return f;
    })];
    fs.writeFileSync(process.argv[3]||'/tmp/curfew-isometric-props.png',rasterise(frames,10,palette,0x1c2029));
  }
}
