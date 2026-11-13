# Pruebas de reglas_neutro.py: cada caso es (texto, esperado). Correr: python3 prueba_reglas.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reglas_neutro as R
CASOS = [
 ('Tocá «Lo tomé» para confirmar.', 'Toca «Lo tomé» para confirmar.'),
 ('¿Querés avisar a tu familia? Podés cambiarlo.', '¿Quieres avisar a tu familia? Puedes cambiarlo.'),
 ('Entr\\u00e1 al panel y revis\\u00e1 los dispositivos.', 'Entra al panel y revisa los dispositivos.'),
 ('\\u00bfSegu\\u00eds en camino? \\u00bfNecesit\\u00e1s m\\u00e1s tiempo?', '\\u00bfSigues en camino? \\u00bfNecesitas m\\u00e1s tiempo?'),
 ('Tocá los días en que lo tomás.', 'Toca los días en que lo tomas.'),
 ('Tomás es su nombre; los tomás todos los días.', 'Tomás es su nombre; los tomas todos los días.'),
 ('const [vos, setVos] = useState(null); if (!vos) return null; <TarjetaVos P={P} /> vos.nombre', 'const [vos, setVos] = useState(null); if (!vos) return null; <TarjetaVos P={P} /> vos.nombre'),
 ('Si fuiste vos, no pasa nada. Lo apagaste vos. Contigo: con vos; para vos; a vos.', 'Si fuiste tú, no pasa nada. Lo apagaste tú. Contigo: contigo; para ti; a ti.'),
 ('Vos sos el titular. Sos la única persona. (sos el titular) y que sos mi amigo', 'Tú eres el titular. Eres la única persona. (eres el titular) y que eres mi amigo'),
 ('estado.sos = familia.sos || []; "sos apagado"; SOS', 'estado.sos = familia.sos || []; "sos apagado"; SOS'),
 ('title = "Vos"; PAPA → VOS / VOS → PAPA', 'title = "Tú"; PAPA → TÚ / TÚ → PAPA'),
 ('PROBÁ y ELEGÍ', 'PRUEBA y ELIGE'),
 ('linea 1\\nTocá y esperá', 'linea 1\\nToca y espera'),
 ('Acá estás; mirá qué lindo.', 'Aquí estás; mira qué lindo.'),
 ('Avisanos; pedile; escribinos; Tocala y ponele; revisala.', 'Avísanos; pídele; escríbenos; Tócala y ponle; revísala.'),
 ('Te elegí como mi referente. Elegí uno.', 'Te elegí como mi referente. Elige uno.'),
 ('Pedí ayuda; me pedí perdón.', 'Pide ayuda; me pedí perdón.'),
 ('si compart\\u00eds tu ubicaci\\u00f3n', 'si compartes tu ubicaci\\u00f3n'),
]
mal = 0
for a, esperado in CASOS:
    n, _ = R.aplicar(a)
    if n != esperado:
        mal += 1; print('MAL', repr(a), '->', repr(n), 'esperaba', repr(esperado))
print('TODO BIEN %d casos' % len(CASOS) if not mal else '%d FALLAN' % mal)
sys.exit(1 if mal else 0)
