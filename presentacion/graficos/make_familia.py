from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
S=3; W,H=440,880
def F(sz,b=False): return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if b else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", int(sz*S))
def p(*v): return tuple(int(round(x*S)) for x in v)
img=Image.new("RGBA",p(W,H),(0,0,0,0))
# sombra
sh=Image.new("RGBA",img.size,(0,0,0,0)); ds=ImageDraw.Draw(sh)
ds.rounded_rectangle(p(14,18,W-6,H-2),radius=60*S,fill=(0,0,0,110)); sh=sh.filter(ImageFilter.GaussianBlur(10*S)); img.alpha_composite(sh)
d=ImageDraw.Draw(img)
d.rounded_rectangle(p(8,6,W-12,H-14),radius=58*S,fill="#111111",outline="#2a2a2a",width=2*S)
SX0,SY0,SX1,SY1=22,20,W-26,H-28
# pantalla (capa aparte para recortar con esquinas redondeadas)
scr=Image.new("RGBA",p(W,H),(0,0,0,0)); s=ImageDraw.Draw(scr)
s.rectangle(p(SX0,SY0,SX1,SY1),fill="#efe9dc")
# mapa: manzanas
mx0,my0,mx1,my1=SX0,96,SX1,600
s.rectangle(p(mx0,my0,mx1,my1),fill="#ffffff")
blk=52; st=12
for i in range(-1,10):
    for j in range(-1,12):
        x=mx0-20+i*(blk+st); y=my0-14+j*(blk+st)
        s.rounded_rectangle(p(x,y,x+blk,y+blk),radius=4*S,fill="#ece5d6")
# parque y río
s.rounded_rectangle(p(mx0+212,my0+300,mx0+212+116,my0+300+116),radius=6*S,fill="#d3e4c4")
s.polygon([p(mx1-58,my0),p(mx1,my0),p(mx1,my1),p(mx1-30,my1),p(mx1-46,my0+340),p(mx1-70,my0+160)],fill="#c9dde8")
# avenidas
s.line([p(mx0,my0+420),p(mx1,my0+120)],fill="#f7d79a",width=14*S)
s.line([p(mx0+148,my0),p(mx0+148,my1)],fill="#fbe7c0",width=10*S)
s.rectangle(p(SX0,my1,SX1,SY1),fill="#ffffff")
# encabezado
s.rectangle(p(SX0,SY0,SX1,96),fill="#ffffff")
s.text(p(48,34),"9:41",font=F(13,True),fill="#171916")
s.text(p(40,62),"Familia",font=F(20,True),fill="#171916")
s.text(p(W-140,68),"5 personas",font=F(12),fill="#62665e")
mask=Image.new("L",img.size,0); ImageDraw.Draw(mask).rounded_rectangle(p(SX0,SY0,SX1,SY1),radius=46*S,fill=255)
img.paste(scr,(0,0),mask); d=ImageDraw.Draw(img)
# integrantes
vx,vy=190,330
people=[("Mamá","M","#b5523b",86,170,"Trabajo","4,2 km · hace 1 min","r"),
        ("Sofía","S","#4f74b0",330,262,"Colegio","1,4 km · hace 3 min","l"),
        ("Tomás","T","#3f8466",330,430,"Club","2,1 km · ahora","l"),
        ("Mía","M","#9a5a86",80,528,"Casa de la abuela","3,0 km · hace 8 min","r")]
for n,ini,c,x,y,lug,info,side in people:
    for k in range(0,100,9):  # línea punteada ámbar hacia "vos"
        t0=k/100; t1=min(1,(k+4)/100)
        d.line([p(vx+(x-vx)*t0,vy+(y-vy)*t0),p(vx+(x-vx)*t1,vy+(y-vy)*t1)],fill="#e0a21a",width=int(2*S))
# vos
d.ellipse(p(vx-34,vy-34,vx+34,vy+34),fill=(255,180,0,60))
d.ellipse(p(vx-21,vy-21,vx+21,vy+21),fill="#171916",outline="#ffb400",width=4*S)
d.text(p(vx,vy),"P",font=F(17,True),fill="#ffffff",anchor="mm")
d.rounded_rectangle(p(vx-36,vy+28,vx+36,vy+50),radius=11*S,fill="#171916")
d.text(p(vx,vy+39),"Vos · Papá",font=F(10,True),fill="#ffffff",anchor="mm")
for n,ini,c,x,y,lug,info,side in people:
    d.ellipse(p(x-22,y-22,x+22,y+22),fill=c,outline="#ffffff",width=4*S)
    d.text(p(x,y),ini,font=F(17,True),fill="#ffffff",anchor="mm")
    bw=max(d.textlength(f"{n} · {lug}",font=F(12,True)),d.textlength(info,font=F(11)))/S+20
    bx=x+30 if side=="r" else x-30-bw
    by=y-24
    d.rounded_rectangle(p(bx+1,by+2,bx+bw+1,by+50),radius=10*S,fill=(0,0,0,40))
    d.rounded_rectangle(p(bx,by,bx+bw,by+48),radius=10*S,fill="#ffffff")
    d.text(p(bx+10,by+8),f"{n} · {lug}",font=F(12,True),fill="#171916")
    d.text(p(bx+10,by+28),info,font=F(11),fill="#62665e")
# hoja inferior
y0=618
d.rounded_rectangle(p(SX0+150,y0-12,SX1-150,y0-7),radius=3*S,fill="#d6d0c2")
rows=[("#3f8466","Tomás llegó al club","17:42"),("#9a5a86","Mía · batería baja 18%","17:25")]
for i,(c,t,h) in enumerate(rows):
    y=y0+8+i*54
    d.ellipse(p(44,y+4,62,y+22),fill=c)
    d.text(p(76,y+3),t,font=F(14,True),fill="#171916")
    d.text(p(SX1-20,y+5),h,font=F(12),fill="#62665e",anchor="ra")
    d.line([p(44,y+42),p(SX1-20,y+42)],fill="#ece5d6",width=S)
y=y0+118
d.ellipse(p(44,y+4,62,y+22),fill="#4f74b0")
d.text(p(76,y+3),"Sofía · 14 años",font=F(14,True),fill="#171916")
d.text(p(SX1-20,y+5),"menor de 18",font=F(12),fill="#62665e",anchor="ra")
bx0=44; bw=(SX1-20-44-12)/2; by=y+36
d.rounded_rectangle(p(bx0,by,bx0+bw,by+44),radius=22*S,fill="#171916")
d.text(p(bx0+bw/2,by+22),"Hacer sonar",font=F(13,True),fill="#ffffff",anchor="mm")
d.rounded_rectangle(p(bx0+bw+12,by,bx0+2*bw+12,by+44),radius=22*S,fill="#ffffff",outline="#171916",width=2*S)
d.text(p(bx0+bw+12+bw/2,by+22),"Pedir foto",font=F(13,True),fill="#171916",anchor="mm")
d.rounded_rectangle(p(W/2-60,H-44,W/2+60,H-39),radius=3*S,fill="#171916")
img.save("familia.png"); print(img.size)
bg=Image.new("RGBA",img.size,(246,243,233,255)); bg.alpha_composite(img); bg.convert("RGB").save("prev_familia.png")
