import math, base64
def iris(cx,cy,r,rp,id):
    L=[]
    for i in range(72):
        a=i*math.pi/36+(0.02 if i%2 else 0); r0=rp+1.5; r1=r*(0.92 if i%3 else 0.98)
        L.append(f'<line x1="{cx+r0*math.cos(a):.2f}" y1="{cy+r0*math.sin(a):.2f}" x2="{cx+r1*math.cos(a):.2f}" y2="{cy+r1*math.sin(a):.2f}" stroke="#ffe7a8" stroke-opacity="{0.25 if i%2 else 0.5}" stroke-width="0.8"/>')
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#iris{id})"/>'+"".join(L)+
      f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#5a3d0c" stroke-width="2"/><circle cx="{cx}" cy="{cy}" r="{rp}" fill="#070707"/>'
      f'<circle cx="{cx-rp*0.45:.1f}" cy="{cy-rp*0.5:.1f}" r="{rp*0.28:.1f}" fill="#fff" fill-opacity=".85"/>')
def defs(id,glow):
    g=f'<filter id="glow{id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>' if glow else ""
    return (f'<defs><radialGradient id="iris{id}" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#3a2606"/><stop offset=".35" stop-color="#b9851f"/><stop offset=".75" stop-color="#f2c45a"/><stop offset="1" stop-color="#8a5f14"/></radialGradient>'
            f'<linearGradient id="gold{id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd978"/><stop offset=".5" stop-color="#e2a93a"/><stop offset="1" stop-color="#9c6a1a"/></linearGradient>{g}</defs>')
RY=52; RX=64; CX=154; TIP=8; CY=100; EX0=60; EX1=196; EH=37
OUT=f"M{TIP},{CY} C{TIP+40},{CY-RY*0.55} {CX-70},{CY-RY} {CX},{CY-RY} A{RX},{RY} 0 0 1 {CX},{CY+RY} C{CX-70},{CY+RY} {TIP+40},{CY+RY*0.55} {TIP},{CY} Z"
EYE=f"M{EX0},{CY} C{EX0+30},{CY-EH} {EX1-30},{CY-EH} {EX1},{CY} C{EX1-30},{CY+EH} {EX0+30},{CY+EH} {EX0},{CY} Z"
def mark(id,glow=True,fill_eye="#0b0b0b"):
    f=f' filter="url(#glow{id})"' if glow else ""
    return (defs(id,glow)+f'<g{f}><path d="{OUT}" fill="none" stroke="url(#gold{id})" stroke-width="6.5" stroke-linejoin="round"/>'
            f'<path d="{EYE}" fill="{fill_eye}" stroke="url(#gold{id})" stroke-width="4.5"/></g>'+iris((EX0+EX1)/2,CY,29,11.5,id))
# viewBox of mark: x -4..234, y 34..166
font=base64.b64encode(open("fonts/Jost.ttf","rb").read()).decode()
style=f'<style>@font-face{{font-family:J;src:url(data:font/ttf;base64,{font})}}</style>'
def svg_mark(glow=True): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-14 24 258 152">{mark("m",glow)}</svg>'
def svg_lockup(textcol,glow): return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-14 24 880 152">{style}{mark("l",glow)}'
    f'<text x="280" y="124" font-family="J, sans-serif" font-weight="300" font-size="92" letter-spacing="11" fill="{textcol}">ojo guard</text></svg>')
def svg_icon(): return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" rx="228" fill="#0b0a08"/>'
    f'<radialGradient id="bg" cx="50%" cy="50%" r="60%"><stop offset="0" stop-color="#2a1f0c"/><stop offset="1" stop-color="#0b0a08" stop-opacity="0"/></radialGradient><rect width="1024" height="1024" rx="228" fill="url(#bg)"/>'
    f'<g transform="translate(512 512) scale(3.4) translate(-115 -100)">{mark("i",True)}</g></svg>')
files={"ojoguard-marca.svg":svg_mark(),"ojoguard-logo-fondo-oscuro.svg":svg_lockup("#F5F0E6",True),
       "ojoguard-logo-fondo-claro.svg":svg_lockup("#171916",False),"ojoguard-icono-app.svg":svg_icon()}
for n,s in files.items(): open("final/"+n,"w").write(s)
