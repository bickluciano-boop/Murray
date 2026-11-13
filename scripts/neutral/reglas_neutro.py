# Reglas para pasar los textos de Ojo Guard del español rioplatense (voseo) a un español neutro (tuteo), para ofrecer la app fuera de Argentina.
# Luciano (13/11/2026): "que sea mas generico; si no, usamos un español muy argentino y para ofrecer a Latinoamerica queda como muy informal".
# Las mismas reglas se usan en Python (para probar sobre copias) y se vuelcan a la tabla del instalador de PowerShell (para aplicarlas en su PC).
import re

IMPERATIVOS = {  # vos -> tu (mandato)
 'tocá':'toca','probá':'prueba','elegí':'elige','abrí':'abre','entrá':'entra','escribí':'escribe','revisá':'revisa','volvé':'vuelve','llamá':'llama','poné':'pon',
 'sumá':'suma','pedí':'pide','intentá':'intenta','permití':'permite','agregá':'agrega','pegá':'pega','activá':'activa','mirá':'mira','seguí':'sigue','usá':'usa',
 'creá':'crea','decí':'di','esperá':'espera','copiá':'copia','guardá':'guarda','subí':'sube','aceptá':'acepta','apretá':'aprieta','mové':'mueve','quitá':'quita',
 'cerrá':'cierra','cargá':'carga','vinculá':'vincula','avisá':'avisa','dejá':'deja','mandá':'manda','buscá':'busca','borrá':'borra','confirmá':'confirma',
 'desactivá':'desactiva','cambiá':'cambia','bajá':'baja','fijá':'fija','tené':'ten','hacé':'haz','salí':'sal','vení':'ven','contá':'cuenta','respondé':'responde',
 'recordá':'recuerda','ingresá':'ingresa','verificá':'verifica','completá':'completa','descargá':'descarga','instalá':'instala','actualizá':'actualiza',
 'reiniciá':'reinicia','conectá':'conecta','habilitá':'habilita','seleccioná':'selecciona','ajustá':'ajusta','configurá':'configura','compartí':'comparte',
 'leé':'lee','pasá':'pasa','andá':'ve','tomá':'toma','sacá':'saca','agarrá':'agarra','cancelá':'cancela','eliminá':'elimina','probalo':'pruébalo','activalo':'actívalo',
 'desactivalo':'desactívalo','abrilo':'ábrelo','cerralo':'ciérralo','borralo':'bórralo','sumalo':'súmalo','sumala':'súmala','cargalo':'cárgalo','mostrame':'muéstrame',
 'avisame':'avísame','avisanos':'avísanos','avisale':'avísale','mandale':'mándale','llamalo':'llámalo','comunicate':'comunícate','fijate':'fíjate','revocalo':'revócalo',
 'permitilo':'permítelo','extendelo':'extiéndelo','guardalo':'guárdalo','cambialo':'cámbialo','escribinos':'escríbenos','escribilo':'escríbelo','pedile':'pídele',
 'decile':'dile','contame':'cuéntame','mandame':'mándame','decime':'dime','escribime':'escríbeme','pasame':'pásame','dejame':'déjame','llamame':'llámame',
 'acordate':'acuérdate','asegurate':'asegúrate','ponete':'ponte','quedate':'quédate','andate':'vete','sumate':'súmate','esperame':'espérame','contanos':'cuéntanos',
 'elegilo':'elígelo','escribila':'escríbela','hacela':'hazla','llamala':'llámala','mostrales':'muéstrales','ponele':'ponle','prendelo':'enciéndelo','revisala':'revísala','tocala':'tócala','tocandola':'tocándola','usalo':'úsalo',
 'anotá':'anota','compará':'compara','comprá':'compra','consultá':'consulta','contestá':'contesta','deslizá':'desliza','destildá':'desmarca','marcá':'marca','reintentá':'reintenta',
 'soltá':'suelta','vinculalo':'vincúlalo','tildá':'marca','chequeá':'revisa','mantené':'mantén','pulsá':'pulsa','presioná':'presiona','empezá':'empieza','comenzá':'comienza',
 'terminá':'termina','aguardá':'aguarda','intentalo':'inténtalo','agregalo':'agrégalo','sacalo':'sácalo','ponelo':'ponlo','hacelo':'hazlo','dejalo':'déjalo','mostralo':'muéstralo',
 'apagá':'apaga','autorizá':'autoriza','bloqueá':'bloquea','evitá':'evita','llegá':'llega','mejorá':'mejora','prendé':'prende','protegé':'protege','silenciá':'silencia',
 'abrila':'ábrela','activala':'actívala','cancelalo':'cancélalo','comparala':'compárala','invitalo':'invítalo','mantenelo':'mantenlo','tocalo':'tócalo','ubicalo':'ubícalo','volvelo':'vuélvelo',
 'apagala':'apágala','apagalo':'apágalo','prendela':'enciéndela','prendelo':'enciéndelo','cargala':'cárgala','borrala':'bórrala','cerrala':'ciérrala','mandala':'mándala','mandalo':'mándalo',
 'escribile':'escríbele','avisales':'avísales','mirá':'mira','miralo':'míralo','pedinos':'pídenos','llamanos':'llámanos','mandanos':'mándanos','copialo':'cópialo',
}
PRESENTES = {  # vos -> tu (presente)
 'tenés':'tienes','podés':'puedes','querés':'quieres','sabés':'sabes','ponés':'pones','hacés':'haces','decís':'dices','venís':'vienes','salís':'sales',
 'elegís':'eliges','pedís':'pides','seguís':'sigues','recibís':'recibes','compartís':'compartes','dormís':'duermes','tardás':'tardas','llegás':'llegas',
 'necesitás':'necesitas','respondés':'respondes','lográs':'logras','cambiás':'cambias','apagás':'apagas','dejás':'dejas','cancelás':'cancelas','contestás':'contestas',
 'creás':'creas','escuchás':'escuchas','apretás':'aprietas','tocás':'tocas','aparecés':'apareces','invitás':'invitas','armás':'armas','prendés':'prendes','cargás':'cargas',
 'usás':'usas','mirás':'miras','andás':'vas','vivís':'vives','sentís':'sientes','escribís':'escribes','abrís':'abres','entrás':'entras','mandás':'mandas','volvés':'vuelves',
 'pasás':'pasas','buscás':'buscas','decidís':'decides','confirmás':'confirmas','activás':'activas','movés':'mueves','cerrás':'cierras','llamás':'llamas','esperás':'esperas',
 'intentás':'intentas','agregás':'agregas','borrás':'borras','guardás':'guardas','configurás':'configuras','instalás':'instalas','tomás':'tomas','desactivás':'desactivas',
 'pagás':'pagas','acabás':'acabas','bajás':'bajas','apagás':'apagas','bloqueás':'bloqueas','evitás':'evitas','protegés':'proteges','mejorás':'mejoras','elegís':'eliges','dejás':'dejas','sacás':'sacas','encendés':'enciendes','conectás':'conectas','conocés':'conoces','pensás':'piensas','perdés':'pierdes',
 'sumás':'sumas','avisás':'avisas','recordás':'recuerdas','cambiás':'cambias','quitás':'quitas','ocupás':'ocupas','verificás':'verificas','completás':'completas',
}
LEXICO = {'acá':'aquí'}
FRASES = [  # (frase, reemplazo): con "vos"/"sos" hay que mirar el contexto
 ('con vos','contigo'),('vos sos','tú eres'),('que sos','que eres'),('si sos','si eres'),('como sos','como eres'),('donde sos','donde eres'),('quién sos','quién eres'),
 ('quien sos','quien eres'),('cuando sos','cuando eres'),('porque sos','porque eres'),('no sos','no eres'),
]
PREPOSICIONES = ['a','para','por','sin','de','en','sobre','hacia','desde','hasta','según']
SOLO_MINUSCULA = {'tomás'}   # "Tomás" tambien es un nombre
# Estas formas tambien son el pasado de "yo" ("Te elegí como mi referente", "pedí", "abrí"): no se tocan si van despues de te/me/le/lo/la.
PASADO_YO = {'elegí','pedí','abrí','escribí','seguí','permití','subí','decí','salí','compartí','vení','mové'}
SIN_PRONOMBRE_ANTES = r'(?<![Tt]e )(?<![Mm]e )(?<![Ll][aeo] )(?<![Nn]os )'
ACENTOS = 'áéíóúñÁÉÍÓÚÑ'
B_ANTES = r'(?:(?<![A-Za-zÀ-ÿ0-9_])|(?<=\\[nrt])|(?<=\\u00bf)|(?<=\\u00a1)|(?<=\\u00ab)|(?<=\\u00bb)|(?<=\\u201[cC89]))'
B_DESPUES = r'(?![A-Za-zÀ-ÿ0-9_])'

def _tolerante(palabra):
    # cada letra con acento tambien se reconoce escrita como \uXXXX (asi estan muchos textos del servidor)
    out = []
    for c in palabra:
        if ord(c) > 127:
            out.append('(?:%s|\\\\u%04x)' % (c, ord(c)))
        elif c == ' ':
            out.append(' ')
        else:
            out.append(re.escape(c))
    return ''.join(out)

def reglas():
    """Lista de (regex, reemplazo, solo_minuscula). Los regex sirven igual en Python y en .NET (se aplican sin distinguir mayusculas)."""
    r = []
    for frase, nuevo in FRASES:
        r.append((B_ANTES + _tolerante(frase) + B_DESPUES, nuevo, False))
    for prep in PREPOSICIONES:
        r.append((B_ANTES + prep + ' vos' + B_DESPUES, prep + ' ti', False))
    for tabla in (IMPERATIVOS, PRESENTES, LEXICO):
        for viejo, nuevo in tabla.items():
            antes = B_ANTES + (SIN_PRONOMBRE_ANTES if viejo in PASADO_YO else '')
            r.append((antes + _tolerante(viejo) + B_DESPUES, nuevo, viejo in SOLO_MINUSCULA))
    # "vos" suelto como pronombre, solo en medio de un texto (no en codigo: variables como `vos`, `setVos`, `TarjetaVos`)
    r.append((r'(?<=[A-Za-zÀ-ÿ,;:)»"] )vos(?= [A-Za-zÀ-ÿ¿])', 'tú', False))
    r.append((r'(?<![A-Za-zÀ-ÿ0-9_.])Vos(?= [a-zà-ÿ])', 'Tú', False))
    # "vos" al final de una frase ("Si fuiste vos, ...", "los apagas vos."): detras de una palabra y antes de una coma, dos puntos, signo o fin de frase (no `vos.nombre` de codigo)
    r.append((r'(?<=[a-zà-ÿ] )vos(?=[,:?!"\']|\.(?:[ "\'`<]|$|\\\\n))', 'tú', False))
    # etiquetas sueltas: "Vos" entre comillas (titulo de un marcador) y el rotulo en mayusculas VOS ("PAPA → VOS"). Distinguen mayusculas de minusculas para no tocar variables.
    r.append((r'(?-i:(?<=["\'`>])Vos(?=["\'`<]))', 'tú', False))
    r.append((r'(?-i:(?<![A-Za-zÀ-ÿ0-9_])VOS(?![A-Za-zÀ-ÿ0-9_]))', 'tú', False))
    # "Sos" / "sos" como verbo ("Sos la única persona...", "(sos el titular)"): solo con mayuscula al empezar la frase, o seguido de articulo/palabra de persona. "sos" suelto puede ser el SOS (claves de codigo).
    r.append((r'(?-i:(?<![A-Za-zÀ-ÿ0-9_.])Sos(?= [a-zà-ÿ¿]))', 'eres', False))
    r.append((r'(?<![A-Za-zÀ-ÿ0-9_.])sos(?= (?:el|la|los|las|un|una|tu|su|mi|titular|menor|tutor|alguien|referente|quien|más|muy)(?![A-Za-zÀ-ÿ0-9_]))', 'eres', False))
    return r

def _escapar(s):
    return ''.join(c if ord(c) < 128 else '\\u%04x' % ord(c) for c in s)

def _poner_mayusculas(encontrado, nuevo):
    visible = re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), encontrado)
    letras = [c for c in visible if c.isalpha()]
    if len(letras) > 1 and all(c.isupper() for c in letras):
        nuevo = nuevo.upper()
    elif letras and letras[0].isupper():
        nuevo = nuevo[0].upper() + nuevo[1:]
    return _escapar(nuevo) if '\\u' in encontrado else nuevo

def aplicar(texto, tabla=None):
    """Devuelve (texto_nuevo, cuantos_cambios). Equivale a lo que hace el instalador."""
    total = 0
    for rx, nuevo, solo_min in (tabla or reglas()):
        comp = re.compile(rx, re.IGNORECASE)
        def cambiar(m):
            nonlocal total
            if solo_min and not m.group(0)[0].islower():
                return m.group(0)
            total += 1
            return _poner_mayusculas(m.group(0), nuevo)
        texto = comp.sub(cambiar, texto)
    return texto, total

BUENAS = set('disparé mandé miré volví mostrará volverá través abrirá actualizará habilitará caché nomás revés está será habrá podrá verá hará dará irá tendrá quedará llegará deberá estará aquí así allí sí ahí allá más además demás atrás detrás después qué quizá mamá papá café sofá aún algún según país mié esté estés estás llegué tomé entré encontré cuándo cómo dónde quién cuál también tomé puedo'.split())
BUENAS_ENCLITICAS = set('comprime congela coordinate estimate incomplete interpolate manipulate mochila modelo paquete polite rescate vigila acredite authenticate estilo grayscale intervalo satellite username autocomplete caminos cancela cancelo candidate carrete cautela cercanos create deactivate delete destinos duplicate escala filename hostname instala invite limite locate mobile paralelo pathname permite private profile promete rename repite revalidate rotate satelite scheme template titila tranquilo translate vibrate'.split())
def restos(texto):
    """Palabras que todavia parecen voseo (para revisar a mano)."""
    t = re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), texto)
    hallados = {}
    for m in re.finditer(r'(?<![A-Za-zÀ-ÿ0-9_])[a-záéíóúñ]{2,}(?:á|é|í|ás|és|ís)(?![A-Za-zÀ-ÿ0-9_])', t, re.I):
        w = m.group(0).lower()
        if w not in BUENAS:
            hallados[w] = hallados.get(w, 0) + 1
    for m in re.finditer(r'(?<![A-Za-zÀ-ÿ0-9_])(?:vos|sos)(?![A-Za-zÀ-ÿ0-9_])', t):
        w = m.group(0)
        if w == 'vos' or w == 'sos':
            hallados['«%s»' % w] = hallados.get('«%s»' % w, 0) + 1
    return hallados
