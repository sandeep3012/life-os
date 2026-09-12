// LifeOS icon generator — used by the asset build script.
export function makeIcon(createCanvas, s, variant, bleed){
  const D = Math.PI/180;
  const c = createCanvas(s,s), ctx = c.getContext('2d');
  const r = s*0.2237;
  if(!bleed){
    ctx.beginPath(); ctx.moveTo(r,0);
    ctx.lineTo(s-r,0); ctx.quadraticCurveTo(s,0,s,r);
    ctx.lineTo(s,s-r); ctx.quadraticCurveTo(s,s,s-r,s);
    ctx.lineTo(r,s); ctx.quadraticCurveTo(0,s,0,s-r);
    ctx.lineTo(0,r); ctx.quadraticCurveTo(0,0,r,0); ctx.closePath();
  } else { ctx.beginPath(); ctx.rect(0,0,s,s); }
  let ring, dot;
  if(variant==='brand'){
    const g = ctx.createLinearGradient(0,0,s,s);
    g.addColorStop(0,'#0A6E4D'); g.addColorStop(1,'#0C8058');
    ctx.fillStyle=g; ring='#F5F1E9'; dot='#34D399';
  } else if(variant==='light'){ ctx.fillStyle='#F5F1E9'; ring='#0B7C56'; dot='#0E9F6E'; }
  else { ctx.fillStyle='#0C0B09'; ring='#F4F0E7'; dot='#34D399'; }
  ctx.fill();
  if(variant==='brand'){
    ctx.save(); ctx.clip();
    const rg=ctx.createRadialGradient(s*.22,s*.14,0,s*.22,s*.14,s*.95);
    rg.addColorStop(0,'rgba(255,255,255,.16)'); rg.addColorStop(1,'rgba(255,255,255,0)');
    ctx.fillStyle=rg; ctx.fillRect(0,0,s,s); ctx.restore();
  }
  const small=s<=48, cx=s/2, cy=s/2;
  const rad=s*(small?.285:.295), lw=s*(small?.145:.118), gap=small?84:70;
  ctx.strokeStyle=ring; ctx.lineWidth=lw; ctx.lineCap='round';
  ctx.beginPath(); ctx.arc(cx,cy,rad,(-60+gap/2)*D,(-60-gap/2)*D+2*Math.PI); ctx.stroke();
  ctx.fillStyle=dot; ctx.beginPath();
  ctx.arc(cx+Math.cos(-60*D)*rad, cy+Math.sin(-60*D)*rad, s*(small?.105:.082),0,7); ctx.fill();
  return c;
}
