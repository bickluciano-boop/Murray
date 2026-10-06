import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch
plt.rcParams["font.family"] = "DejaVu Sans"
GOLD="#947626"; DARK="#171916"; GRAY="#62665e"; PALE="#d8cfb4"; LIGHT="#c4ad6e"
W,H=1708,480; DPI=200; S=2  # render at 2x
def canvas():
    fig=plt.figure(figsize=(W*S/DPI,H*S/DPI),dpi=DPI)
    fig.patch.set_alpha(0)
    ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,W); ax.set_ylim(H,0); ax.axis("off")
    return fig,ax
def pt(px): return px*S*72/DPI  # px (slide units) -> points

# ---------- Imagen 1: celulares ----------
fig,ax=canvas()
ax.text(0,235,"877.078",fontsize=pt(170),fontweight="bold",color=GOLD,va="baseline")
ax.text(4,305,"celulares denunciados por robo, hurto",fontsize=pt(40),color=DARK,va="baseline")
ax.text(4,358,"o extravío en Argentina durante 2024",fontsize=pt(40),color=DARK,va="baseline")
ax.plot([980,980],[30,450],color=PALE,lw=pt(3))
stats=[("2.400","por día"),("100","por hora"),("1 cada 36 s","todo el año")]
for i,(n,l) in enumerate(stats):
    y=105+i*140
    ax.text(1040,y,n,fontsize=pt(72),fontweight="bold",color=DARK,va="baseline")
    ax.text(1045,y+48,l,fontsize=pt(34),color=GRAY,va="baseline")
# barra de "un día": 24 segmentos
fig.savefig("celulares.png",transparent=True); plt.close(fig)

# ---------- Imagen 2: cuidado ----------
fig,ax=canvas()
# panel A: barras demencia
ax.text(0,40,"Demencia en Argentina",fontsize=pt(32),fontweight="bold",color=DARK,va="baseline")
base=430; scale=300/892180
for x,v,lab,c in [(40,412268,"2019",LIGHT),(260,892180,"2050*",GOLD)]:
    h=v*scale
    ax.add_patch(FancyBboxPatch((x,base-h),150,h,boxstyle="round,pad=0,rounding_size=6",fc=c,ec="none"))
    ax.text(x+75,base-h-14,f"{round(v/1000)} mil",ha="center",fontsize=pt(36),fontweight="bold",color=DARK,va="baseline")
    ax.text(x+75,base+40,lab,ha="center",fontsize=pt(30),color=GRAY,va="baseline")
ax.plot([0,470],[base,base],color=GRAY,lw=pt(2))
ax.text(470,300,"+116%",ha="right",fontsize=pt(44),fontweight="bold",color=GOLD,va="baseline",alpha=0)  # reservado
ax.text(115,base-412268*scale-75,"+116%",ha="center",fontsize=pt(40),fontweight="bold",color=GOLD,va="baseline")
# divisores
for x in (580,1150): ax.plot([x,x],[20,460],color=PALE,lw=pt(3))
# panel B: caidas 1 de 3
ax.text(640,40,"Caídas, mayores de 65",fontsize=pt(32),fontweight="bold",color=DARK,va="baseline")
for i in range(3):
    ax.add_patch(Circle((700+i*150,190),58,fc=GOLD if i==0 else PALE,ec="none"))
ax.text(640,340,"1 de cada 3",fontsize=pt(60),fontweight="bold",color=GOLD,va="baseline")
ax.text(642,395,"se cae al menos una vez al año",fontsize=pt(30),color=DARK,va="baseline")
# panel C: discapacidad 1 de 10
ax.text(1210,40,"Discapacidad",fontsize=pt(32),fontweight="bold",color=DARK,va="baseline")
for i in range(10):
    r,cidx=divmod(i,5)
    ax.add_patch(Circle((1250+cidx*100,130+r*110),38,fc=GOLD if i==0 else PALE,ec="none"))
ax.text(1210,340,"1 de cada 10",fontsize=pt(60),fontweight="bold",color=GOLD,va="baseline")
ax.text(1212,395,"la más frecuente es la motora",fontsize=pt(30),color=DARK,va="baseline")
fig.savefig("cuidado.png",transparent=True); plt.close(fig)
print("ok")
