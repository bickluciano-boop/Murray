import { useRef, useState, type ReactNode } from "react";
import {
  Image,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  Text,
  useWindowDimensions,
  View,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from "react-native";
import { Icono, type NombreIcono } from "./Iconos";

// Bienvenida: 13 diapositivas que se muestran una sola vez, antes de pedir
// el acceso. Todo esta dibujado con vistas de React Native (sin imagenes ni
// librerias nuevas), con los colores de la paleta de la app, asi que sigue al
// modo claro/noche.

export type PaletaBienvenida = {
  fondo: string;
  superficie: string;
  texto: string;
  textoMedio: string;
  textoDebil: string;
  borde: string;
  doradoRelleno: string;
  sobreDorado: string;
};

const DORADO = "#D4A94D";
const ROJO = "#C9402F";

type Colores = {
  p: PaletaBienvenida;
  noche: boolean;
  azul: string;
  azulSuave: string;
  tarjeta: string;
  sombra: object;
};

function armarColores(p: PaletaBienvenida, noche: boolean): Colores {
  return {
    p,
    noche,
    azul: noche ? "#7C9CFF" : p.doradoRelleno,
    azulSuave: noche ? "#1A2757" : "#E4EBFC",
    tarjeta: noche ? "#16203F" : "#FFFFFF",
    sombra: noche
      ? {}
      : { shadowColor: "#14213D", shadowOpacity: 0.12, shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, elevation: 4 },
  };
}

function Avatar({ letra, fondo, color = "#fff", tam = 48 }: { letra: string; fondo: string; color?: string; tam?: number }) {
  return (
    <View
      style={{
        width: tam,
        height: tam,
        borderRadius: tam / 2,
        backgroundColor: fondo,
        borderWidth: 3,
        borderColor: "#fff",
        alignItems: "center",
        justifyContent: "center",
        elevation: 3,
      }}
    >
      <Text style={{ color, fontSize: tam * 0.42, fontWeight: "700" }}>{letra}</Text>
    </View>
  );
}

function Pastilla({ c, texto, color, fondo }: { c: Colores; texto: string; color?: string; fondo?: string }) {
  return (
    <View style={{ height: 24, paddingHorizontal: 10, borderRadius: 12, backgroundColor: fondo ?? c.azulSuave, justifyContent: "center" }}>
      <Text style={{ color: color ?? c.azul, fontSize: 11, fontWeight: "700" }}>{texto}</Text>
    </View>
  );
}

function Mosaico({ c, icono, tam = 62, texto }: { c: Colores; icono: NombreIcono; tam?: number; texto?: string }) {
  return (
    <View style={{ alignItems: "center", gap: 7 }}>
      <View style={[{ width: tam, height: tam, borderRadius: tam * 0.34, backgroundColor: c.tarjeta, alignItems: "center", justifyContent: "center" }, c.sombra]}>
        <Icono nombre={icono} color={c.azul} tam={tam * 0.46} />
      </View>
      {texto ? <Text style={{ color: c.p.texto, fontSize: 12, fontWeight: "700" }}>{texto}</Text> : null}
    </View>
  );
}

function Fila({ c, icono, titulo, sub, tilde }: { c: Colores; icono?: NombreIcono; titulo: string; sub: string; tilde?: boolean }) {
  return (
    <View style={[{ flexDirection: "row", alignItems: "center", gap: 14, minHeight: 70, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 22, backgroundColor: c.tarjeta }, c.sombra]}>
      <View style={{ width: 40, height: 40, borderRadius: tilde ? 20 : 14, backgroundColor: tilde ? c.azul : c.azulSuave, alignItems: "center", justifyContent: "center" }}>
        <Icono nombre={tilde ? "check" : (icono ?? "persona")} color={tilde ? "#fff" : c.azul} tam={22} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: c.p.texto, fontSize: 14.5, fontWeight: "700" }}>{titulo}</Text>
        <Text style={{ color: c.p.textoDebil, fontSize: 12, marginTop: 2 }}>{sub}</Text>
      </View>
    </View>
  );
}

const MARCO = { width: 320, height: 270 } as const;

function Calles({ c }: { c: Colores }) {
  const calle = c.noche ? "#243056" : "#FFFFFF";
  return (
    <>
      <View style={{ position: "absolute", left: -10, top: 62, width: 360, height: 12, backgroundColor: calle, transform: [{ rotate: "-2deg" }] }} />
      <View style={{ position: "absolute", left: -10, top: 164, width: 360, height: 10, backgroundColor: calle, transform: [{ rotate: "-2deg" }] }} />
      <View style={{ position: "absolute", left: 82, top: -10, width: 10, height: 300, backgroundColor: calle }} />
      <View style={{ position: "absolute", left: 206, top: -10, width: 12, height: 300, backgroundColor: calle }} />
    </>
  );
}

function FondoMapa({ c, children }: { c: Colores; children: ReactNode }) {
  return (
    <View style={[MARCO, { borderRadius: 30, overflow: "hidden", backgroundColor: c.noche ? "#16203F" : "#EAF0F7" }, c.sombra]}>
      <View style={{ position: "absolute", left: -20, top: 16, width: 360, height: 56, borderRadius: 28, backgroundColor: c.noche ? "#1B2D5E" : "#CFE2F6" }} />
      <View style={{ position: "absolute", left: 206, top: 126, width: 86, height: 70, borderRadius: 18, backgroundColor: c.noche ? "#1D3A33" : "#DCEFD8" }} />
      <Calles c={c} />
      {children}
    </View>
  );
}

function Circulo({ x, y, r, borde, relleno }: { x: number; y: number; r: number; borde?: string; relleno?: string }) {
  return (
    <View
      style={{
        position: "absolute",
        left: x - r,
        top: y - r,
        width: r * 2,
        height: r * 2,
        borderRadius: r,
        backgroundColor: relleno ?? "transparent",
        borderWidth: borde ? 2 : 0,
        borderColor: borde ?? "transparent",
        borderStyle: borde ? "dashed" : "solid",
      }}
    />
  );
}

function Logo({ ancho }: { ancho: number }) {
  return (
    <Image
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      source={require("../assets/ojo-logo.png")}
      style={{ width: ancho, height: ancho * 0.6 }}
      resizeMode="contain"
    />
  );
}

// ---- ilustraciones ----

function IlusEcosistema({ c }: { c: Colores }) {
  return (
    <View style={[MARCO, { alignItems: "center", justifyContent: "center" }]}>
      <Circulo x={160} y={135} r={120} relleno={c.noche ? "#16203F" : "#EEF2FB"} />
      <Circulo x={160} y={135} r={84} borde={DORADO} />
      <View style={{ position: "absolute", left: 28, top: 30 }}>
        <Mosaico c={c} icono="tel" texto="App" />
      </View>
      <View style={{ position: "absolute", left: 230, top: 36 }}>
        <Mosaico c={c} icono="pc" texto="Panel" />
      </View>
      <View style={{ position: "absolute", left: 130, top: 190 }}>
        <Mosaico c={c} icono="reloj" texto="Relojes" />
      </View>
      <Logo ancho={110} />
    </View>
  );
}

function IlusMapa({ c }: { c: Colores }) {
  return (
    <FondoMapa c={c}>
      <Circulo x={140} y={140} r={52} borde={DORADO} relleno="rgba(212,169,77,0.16)" />
      <View style={{ position: "absolute", left: 60, top: 70 }}>
        <Avatar letra="M" fondo={c.azul} tam={54} />
      </View>
      <View style={{ position: "absolute", left: 200, top: 40 }}>
        <Avatar letra="L" fondo={DORADO} color="#3A2A05" tam={54} />
      </View>
      <View style={{ position: "absolute", left: 230, top: 150 }}>
        <Avatar letra="P" fondo="#2A3F7A" tam={54} />
      </View>
      <View style={{ position: "absolute", left: 14, bottom: 14, flexDirection: "row", gap: 6 }}>
        <Pastilla c={c} texto="Adulto" fondo={c.tarjeta} />
        <Pastilla c={c} texto="Menor" fondo={c.tarjeta} color={c.noche ? "#E3B65A" : "#7A5200"} />
        <Pastilla c={c} texto="Amigo" fondo={c.tarjeta} color={c.p.textoDebil} />
      </View>
    </FondoMapa>
  );
}

function IlusGuardian({ c }: { c: Colores }) {
  return (
    <View style={[MARCO, { alignItems: "center" }]}>
      <View style={{ width: 196, height: 196, borderRadius: 98, borderWidth: 14, borderColor: c.noche ? "#243056" : "#E7EBF5", backgroundColor: c.tarjeta, marginTop: 8 }} />
      <View style={{ position: "absolute", left: 62, top: 8, width: 196, height: 196, borderRadius: 98, borderWidth: 14, borderColor: c.azul, borderBottomColor: "transparent", borderLeftColor: "transparent", transform: [{ rotate: "-20deg" }] }} />
      <View style={{ position: "absolute", left: 211, top: 28, width: 18, height: 18, borderRadius: 9, backgroundColor: DORADO, borderWidth: 3, borderColor: "#fff" }} />
      <View style={{ position: "absolute", left: 0, right: 0, top: 76, alignItems: "center" }}>
        <Text style={{ color: c.p.texto, fontSize: 48, fontWeight: "300", letterSpacing: -1 }}>08:42</Text>
        <Text style={{ color: c.p.textoDebil, fontSize: 12.5, marginTop: 6 }}>Llegá antes de las 19:52</Text>
      </View>
      <View style={{ position: "absolute", left: 40, right: 36, top: 232, height: 5, borderRadius: 3, backgroundColor: c.azul }} />
      <View style={{ position: "absolute", left: 34, top: 228, width: 13, height: 13, borderRadius: 7, backgroundColor: c.tarjeta, borderWidth: 3, borderColor: c.azul }} />
      <View style={{ position: "absolute", right: 28, top: 224, width: 20, height: 20, borderRadius: 10, backgroundColor: DORADO, borderWidth: 3, borderColor: "#fff" }} />
    </View>
  );
}

function IlusSos({ c }: { c: Colores }) {
  return (
    <View style={MARCO}>
      <Circulo x={160} y={135} r={128} relleno="rgba(201,64,47,0.06)" />
      <Circulo x={160} y={135} r={98} relleno="rgba(201,64,47,0.09)" />
      <Circulo x={160} y={135} r={70} relleno="rgba(201,64,47,0.14)" />
      <View style={{ position: "absolute", left: 100, top: 75, width: 120, height: 120, borderRadius: 60, backgroundColor: ROJO, alignItems: "center", justifyContent: "center", elevation: 8 }}>
        <Text style={{ color: "#fff", fontSize: 30, fontWeight: "800", letterSpacing: 2 }}>SOS</Text>
      </View>
      <View style={{ position: "absolute", left: 8, top: 40 }}>
        <Avatar letra="M" fondo={c.azul} tam={46} />
      </View>
      <View style={{ position: "absolute", left: 266, top: 40 }}>
        <Avatar letra="P" fondo="#2A3F7A" tam={46} />
      </View>
      <View style={{ position: "absolute", left: 266, top: 176 }}>
        <Avatar letra="L" fondo={DORADO} color="#3A2A05" tam={46} />
      </View>
      <Text style={{ position: "absolute", left: 0, right: 0, bottom: 0, textAlign: "center", color: "#A93526", fontSize: 13, fontWeight: "700" }}>
        Mantené 3 segundos
      </Text>
    </View>
  );
}

function IlusAntirrobo({ c }: { c: Colores }) {
  const chip = (icono: NombreIcono, texto: string) => (
    <View style={[{ flexDirection: "row", alignItems: "center", gap: 10, height: 48, paddingHorizontal: 12, borderRadius: 16, backgroundColor: c.tarjeta }, c.sombra]}>
      <Icono nombre={icono} color={c.azul} tam={22} />
      <Text style={{ color: c.p.texto, fontSize: 12.5, fontWeight: "700", flexShrink: 1 }}>{texto}</Text>
    </View>
  );
  return (
    <View style={MARCO}>
      <View style={{ position: "absolute", left: 6, top: 6, width: 128, height: 230, borderRadius: 26, backgroundColor: "#0B1020", borderWidth: 4, borderColor: "#14213D", alignItems: "center", paddingTop: 34 }}>
        <Text style={{ color: "rgba(255,255,255,0.88)", fontSize: 32 }}>09:41</Text>
        <View style={{ flexDirection: "row", gap: 8, marginTop: 22 }}>
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <View key={i} style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: i < 3 ? "#fff" : "rgba(255,255,255,0.25)" }} />
          ))}
        </View>
        <Text style={{ color: "rgba(255,255,255,0.55)", fontSize: 9.5, letterSpacing: 1, marginTop: 14 }}>INGRESÁ EL CÓDIGO</Text>
      </View>
      <View style={{ position: "absolute", left: 150, top: 6, width: 170, gap: 10 }}>
        {chip("cam", "Foto delantera y trasera")}
        {chip("mic", "Audio de 10 segundos")}
        {chip("pin", "Ubicación")}
      </View>
      <View style={{ position: "absolute", left: 150, top: 188, width: 170, minHeight: 50, borderRadius: 18, backgroundColor: c.azulSuave, justifyContent: "center", paddingHorizontal: 12 }}>
        <Text style={{ color: c.azul, fontSize: 11.5, fontWeight: "700", lineHeight: 15 }}>Sin internet: se envía al reconectar</Text>
      </View>
    </View>
  );
}

function IlusPerdido({ c }: { c: Colores }) {
  return (
    <View style={MARCO}>
      <Circulo x={160} y={84} r={76} relleno={c.noche ? "#16203F" : "#EEF2FB"} />
      <View style={{ position: "absolute", left: 123, top: 20, width: 74, height: 128, borderRadius: 20, backgroundColor: "#14213D", alignItems: "center", justifyContent: "center", elevation: 8 }}>
        <View style={{ width: 62, height: 112, borderRadius: 14, backgroundColor: "#1B2D5E", alignItems: "center", justifyContent: "center" }}>
          <Logo ancho={44} />
        </View>
      </View>
      <View style={{ position: "absolute", left: 0, right: 0, top: 176, flexDirection: "row", justifyContent: "center", gap: 14 }}>
        <Mosaico c={c} icono="campana" tam={60} texto="Hacer sonar" />
        <Mosaico c={c} icono="pin" tam={60} texto="Localizar" />
        <Mosaico c={c} icono="cam" tam={60} texto="Evidencia" />
      </View>
    </View>
  );
}

function IlusCercania({ c }: { c: Colores }) {
  return (
    <View style={MARCO}>
      <Circulo x={130} y={135} r={112} relleno={c.noche ? "#16203F" : "#EEF2FB"} />
      <Circulo x={130} y={135} r={84} borde={DORADO} relleno="rgba(212,169,77,0.12)" />
      <Circulo x={130} y={135} r={46} borde={c.azul} />
      <View style={{ position: "absolute", left: 98, top: 103 }}>
        <Mosaico c={c} icono="tel" tam={64} />
      </View>
      <View style={{ position: "absolute", left: 238, top: 30 }}>
        <Mosaico c={c} icono="mochila" tam={64} texto="Mochila" />
      </View>
      <View style={{ position: "absolute", left: 152, bottom: 8, width: 166, padding: 10, borderRadius: 16, backgroundColor: c.noche ? "#3A1D1A" : "#FBEAE7" }}>
        <Text style={{ color: "#A93526", fontSize: 12, fontWeight: "700", lineHeight: 16 }}>Tu mochila se alejó del radio seguro</Text>
      </View>
      <View style={{ position: "absolute", left: 14, bottom: 14 }}>
        <Pastilla c={c} texto="Radio seguro · 5 m" fondo={c.tarjeta} />
      </View>
    </View>
  );
}

function IlusFacial({ c }: { c: Colores }) {
  const esquina = (estilo: object) => <View style={[{ position: "absolute", width: 26, height: 26, borderColor: c.azul }, estilo]} />;
  return (
    <View style={MARCO}>
      <View style={[{ position: "absolute", left: 70, top: 0, width: 180, height: 166, borderRadius: 26, backgroundColor: c.noche ? "#243056" : "#CAD5EC", overflow: "hidden" }, c.sombra]}>
        <View style={{ position: "absolute", left: 62, top: 26, width: 56, height: 60, borderRadius: 30, backgroundColor: c.noche ? "#41507F" : "#9CABCB" }} />
        <View style={{ position: "absolute", left: 30, top: 96, width: 120, height: 100, borderTopLeftRadius: 60, borderTopRightRadius: 60, backgroundColor: c.noche ? "#41507F" : "#9CABCB" }} />
      </View>
      {esquina({ left: 58, top: 12, borderLeftWidth: 3, borderTopWidth: 3, borderTopLeftRadius: 10 })}
      {esquina({ left: 236, top: 12, borderRightWidth: 3, borderTopWidth: 3, borderTopRightRadius: 10 })}
      {esquina({ left: 58, top: 128, borderLeftWidth: 3, borderBottomWidth: 3, borderBottomLeftRadius: 10 })}
      {esquina({ left: 236, top: 128, borderRightWidth: 3, borderBottomWidth: 3, borderBottomRightRadius: 10 })}
      <View style={{ position: "absolute", left: 0, right: 0, top: 180, flexDirection: "row", justifyContent: "center", gap: 8 }}>
        {[0, 1, 2, 3].map((i) => (
          <View key={i} style={{ width: 44, height: 40, borderRadius: 12, backgroundColor: c.noche ? "#243056" : "#CAD5EC" }} />
        ))}
      </View>
      <View style={{ position: "absolute", left: 0, right: 0, top: 228, alignItems: "center" }}>
        <View style={{ height: 38, paddingHorizontal: 22, borderRadius: 19, backgroundColor: c.p.doradoRelleno, justifyContent: "center" }}>
          <Text style={{ color: c.p.sobreDorado, fontSize: 13, fontWeight: "700" }}>Buscar coincidencia</Text>
        </View>
      </View>
    </View>
  );
}

function IlusDispositivos({ c }: { c: Colores }) {
  const tarjeta = (icono: NombreIcono, nombre: string, sub: string, chips: ReactNode) => (
    <View style={[{ flexDirection: "row", alignItems: "center", gap: 12, padding: 9, borderRadius: 20, backgroundColor: c.tarjeta }, c.sombra]}>
      <View style={{ width: 44, height: 44, borderRadius: 16, backgroundColor: c.azulSuave, alignItems: "center", justifyContent: "center" }}>
        <Icono nombre={icono} color={c.azul} tam={24} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={{ color: c.p.texto, fontSize: 14, fontWeight: "700" }}>{nombre}</Text>
        <Text style={{ color: c.p.textoDebil, fontSize: 12, marginTop: 1 }}>{sub}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 5, marginTop: 5 }}>{chips}</View>
      </View>
    </View>
  );
  return (
    <View style={[MARCO, { justifyContent: "center", gap: 8 }]}>
      {tarjeta("reloj", "Reloj GPS de Abuela", "Con chip · última señal hace 2 min", <>
        <Pastilla c={c} texto="Pidió ayuda: avisa" />
        <Pastilla c={c} texto="Posible caída · en validación" color={c.noche ? "#E3B65A" : "#7A5200"} fondo={c.noche ? "#3A2F12" : "#FFF3D6"} />
      </>)}
      {tarjeta("tel", "Teléfono de Lu", "Piso estimado: 3", <>
        <Pastilla c={c} texto="Batería" />
        <Pastilla c={c} texto="En vivo" />
      </>)}
      {tarjeta("mochila", "Mochila", "Cerca · por Bluetooth", <Pastilla c={c} texto="Radio seguro" />)}
    </View>
  );
}

function IlusLugares({ c }: { c: Colores }) {
  return (
    <FondoMapa c={c}>
      <Circulo x={190} y={170} r={64} borde={DORADO} relleno="rgba(212,169,77,0.18)" />
      <View style={[{ position: "absolute", left: 166, top: 146, width: 48, height: 48, borderRadius: 24, backgroundColor: c.tarjeta, alignItems: "center", justifyContent: "center" }, c.sombra]}>
        <Icono nombre="casa" color={c.azul} tam={26} />
      </View>
      <View style={{ position: "absolute", left: 66, top: 190 }}>
        <Avatar letra="L" fondo={DORADO} color="#3A2A05" tam={44} />
      </View>
      <View style={[{ position: "absolute", left: 18, right: 18, top: 16, minHeight: 54, borderRadius: 20, backgroundColor: c.tarjeta, flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 14, paddingVertical: 8 }, c.sombra]}>
        <Avatar letra="L" fondo={DORADO} color="#3A2A05" tam={34} />
        <View style={{ flex: 1 }}>
          <Text style={{ color: c.p.texto, fontSize: 13, fontWeight: "700" }}>Lu llegó a Casa</Text>
          <Text style={{ color: c.p.textoDebil, fontSize: 11.5, marginTop: 1 }}>19:42 · Ya no hace falta que hagas nada</Text>
        </View>
      </View>
    </FondoMapa>
  );
}

function IlusAcceso({ c }: { c: Colores }) {
  return (
    <View style={[MARCO, { justifyContent: "center", gap: 12 }]}>
      <Fila c={c} icono="correo" titulo="Correo y SMS" sub="Avisos de seguridad y evidencias" />
      <Fila c={c} icono="candado" titulo="Huella o Face ID" sub="Entrás sin QR, con passkey" />
      <Fila c={c} icono="persona" titulo="Código de 6 números" sub="Te llega por correo" />
    </View>
  );
}

function IlusPanel({ c }: { c: Colores }) {
  const fila = (fondo: string) => (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 7, height: 30 }}>
      <View style={{ width: 22, height: 22, borderRadius: 11, backgroundColor: fondo }} />
      <View style={{ height: 7, width: "62%", borderRadius: 4, backgroundColor: c.noche ? "#2B3868" : "#D5DBEA" }} />
    </View>
  );
  return (
    <View style={[MARCO, { alignItems: "center", paddingTop: 34 }]}>
      <View style={{ width: 300, height: 190, borderTopLeftRadius: 16, borderTopRightRadius: 16, borderBottomLeftRadius: 6, borderBottomRightRadius: 6, backgroundColor: "#14213D", padding: 8, elevation: 8 }}>
        <View style={{ flex: 1, borderRadius: 8, backgroundColor: c.noche ? "#0B1020" : "#FAF8F3", overflow: "hidden" }}>
          <View style={{ height: 22, backgroundColor: c.tarjeta, flexDirection: "row", alignItems: "center", paddingHorizontal: 8 }}>
            <Logo ancho={32} />
          </View>
          <View style={{ flex: 1, flexDirection: "row" }}>
            <View style={{ width: 92, backgroundColor: c.tarjeta, paddingHorizontal: 7, paddingTop: 6 }}>
              {fila(c.azul)}
              {fila(DORADO)}
              {fila("#2A3F7A")}
            </View>
            <View style={{ flex: 1, backgroundColor: c.noche ? "#16203F" : "#EAF0F7" }}>
              <View style={{ position: "absolute", left: 20, top: 24, width: 20, height: 20, borderRadius: 10, backgroundColor: c.azul, borderWidth: 2, borderColor: "#fff" }} />
              <View style={{ position: "absolute", left: 64, top: 52, width: 20, height: 20, borderRadius: 10, backgroundColor: DORADO, borderWidth: 2, borderColor: "#fff" }} />
              <Circulo x={74} y={62} r={26} borde={DORADO} />
            </View>
          </View>
        </View>
      </View>
      <View style={{ width: 330, height: 14, borderBottomLeftRadius: 16, borderBottomRightRadius: 16, backgroundColor: "#AEB6CC" }} />
    </View>
  );
}

function IlusListo({ c }: { c: Colores }) {
  return (
    <View style={[MARCO, { justifyContent: "center", gap: 12 }]}>
      <Fila c={c} tilde titulo="Ubicación «Siempre»" sub="Para que los avisos lleguen con la app cerrada" />
      <Fila c={c} tilde titulo="Avisos activados" sub="Llegadas, salidas y pedidos de ayuda" />
      <Fila c={c} tilde titulo="Tu círculo" sub="Invitás con un código, vos decidís quién entra" />
    </View>
  );
}

function IlusLogo({ c }: { c: Colores }) {
  return (
    <View style={[MARCO, { alignItems: "center", justifyContent: "center" }]}>
      <Circulo x={160} y={135} r={130} relleno={c.noche ? "#16203F" : "#EEF2FB"} />
      <Circulo x={160} y={135} r={92} relleno={c.noche ? "#1B2D5E" : "#E1E9FB"} />
      <Logo ancho={190} />
    </View>
  );
}

type Diapo = { titulo: string; texto: string; ilus: (c: Colores) => ReactNode; boton: string };

export const DIAPOSITIVAS: Diapo[] = [
  { titulo: "Bienvenido a Ojo Guard", texto: "Ojo Guard es un ecosistema: la app en tu teléfono, el panel en la computadora y tus dispositivos trabajan juntos para cuidar a los tuyos. Te mostramos qué podés hacer.", ilus: (c) => <IlusEcosistema c={c} />, boton: "Empezar" },
  { titulo: "Mirá dónde están los tuyos", texto: "Mapa en vivo de tu círculo, con filtros En vivo, Hoy y 7 días. Cada persona es Adulto, Menor o Amigo, y cada uno ve solo lo que le corresponde.", ilus: (c) => <IlusMapa c={c} />, boton: "Siguiente" },
  { titulo: "Camino seguro con Modo Guardián", texto: "Elegís a dónde vas y cuánto tardás. Si no llegás a tiempo, les avisamos a tus referentes con tu última ubicación. Al llegar, tocás «Llegué».", ilus: (c) => <IlusGuardian c={c} />, boton: "Siguiente" },
  { titulo: "Pedí ayuda en un segundo", texto: "Mantené el botón SOS 3 segundos y tu círculo recibe el aviso con tu ubicación en vivo. También podés pedir ayuda sin abrir la app: con los botones de volumen en Android o un atajo en iPhone.", ilus: (c) => <IlusSos c={c} />, boton: "Siguiente" },
  { titulo: "Defensa antirrobo", texto: "Tenés dos claves: la tuya y una señuelo, por si alguien te obliga a abrir. Si alguien se equivoca en la pantalla de guardia, se guarda una foto, 10 segundos de audio y la ubicación. Sin internet, todo espera y se envía al reconectar.", ilus: (c) => <IlusAntirrobo c={c} />, boton: "Siguiente" },
  { titulo: "Si perdés el teléfono", texto: "Hacelo sonar, ubicalo en el mapa y activá el Modo perdido con un mensaje para quien lo encuentre: contacto y recompensa, sin mostrar tu clave ni tu correo.", ilus: (c) => <IlusPerdido c={c} />, boton: "Siguiente" },
  { titulo: "Que nada se aleje", texto: "Sumá tus objetos y accesorios con Bluetooth. Si uno sale del radio seguro que elegiste, por ejemplo 5 metros, te avisamos. Con «Detectar cerca» buscás accesorios a tu alrededor.", ilus: (c) => <IlusCercania c={c} />, boton: "Siguiente" },
  { titulo: "Evidencias y reconocimiento facial", texto: "Pedí una evidencia de tus equipos vinculados, con foto, audio y ubicación. Y comparala con tus propias fotos y con intentos anteriores para saber quién fue.", ilus: (c) => <IlusFacial c={c} />, boton: "Siguiente" },
  { titulo: "Tus dispositivos y cuidado de mayores", texto: "Sumá teléfonos, relojes con chip, auriculares y objetos. Ves ubicación, batería y piso estimado. Un reloj GPS puede avisar si la persona pide ayuda; el aviso de posible caída está en validación.", ilus: (c) => <IlusDispositivos c={c} />, boton: "Siguiente" },
  { titulo: "Avisos de llegada y salida", texto: "Elegí un lugar, como Casa o el Colegio, y te avisamos cuando alguien llega o se va. La persona siempre se entera de que armaste el aviso: nada oculto.", ilus: (c) => <IlusLugares c={c} />, boton: "Siguiente" },
  { titulo: "Alertas y acceso seguro", texto: "Los movimientos de tu círculo te llegan como aviso en el teléfono. Los avisos de seguridad y las evidencias, por correo y, si lo activás, por SMS. Entrás sin QR, con huella o código de 6 números.", ilus: (c) => <IlusAcceso c={c} />, boton: "Siguiente" },
  { titulo: "Tu panel en la computadora", texto: "Ojo Guard MS: el mapa de la familia, tus equipos, las evidencias y los ajustes en una pantalla grande. Es parte del mismo ecosistema que tu app.", ilus: (c) => <IlusPanel c={c} />, boton: "Siguiente" },
  { titulo: "Todo listo para empezar", texto: "Falta darle a Ojo Guard dos permisos para poder avisarte a tiempo. Te los pedimos uno por uno, con una explicación cada vez.", ilus: (c) => <IlusListo c={c} />, boton: "Continuar" },
];

export function Bienvenida({
  paleta,
  noche,
  onTerminar,
}: {
  paleta: PaletaBienvenida;
  noche: boolean;
  onTerminar: () => void;
}) {
  const { width } = useWindowDimensions();
  const c = armarColores(paleta, noche);
  const lista = useRef<ScrollView>(null);
  const [indice, setIndice] = useState(0);
  const total = DIAPOSITIVAS.length;
  const ultima = indice === total - 1;

  function irA(n: number) {
    lista.current?.scrollTo({ x: n * width, animated: true });
    setIndice(n);
  }

  function alTerminarDeDeslizar(e: NativeSyntheticEvent<NativeScrollEvent>) {
    const n = Math.round(e.nativeEvent.contentOffset.x / width);
    if (n !== indice) setIndice(Math.max(0, Math.min(total - 1, n)));
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: paleta.fondo }}>
      <StatusBar barStyle={noche ? "light-content" : "dark-content"} backgroundColor={paleta.fondo} />
      <View style={{ height: 44, flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 22, marginTop: 14 }}>
        <Logo ancho={52} />
        {ultima ? null : (
          <Pressable accessibilityRole="button" accessibilityLabel="Saltar la presentación" hitSlop={12} onPress={() => irA(total - 1)}>
            <Text style={{ color: paleta.textoDebil, fontSize: 14, fontWeight: "600" }}>Saltar</Text>
          </Pressable>
        )}
      </View>
      <ScrollView
        ref={lista}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={alTerminarDeDeslizar}
        style={{ flex: 1 }}
      >
        {DIAPOSITIVAS.map((d, i) => (
          <ScrollView key={i} style={{ width }} contentContainerStyle={{ alignItems: "center", paddingTop: 12, paddingBottom: 12 }}>
            <View style={{ transform: [{ scale: Math.min(1, (width - 24) / 320) }], height: 270 * Math.min(1, (width - 24) / 320), justifyContent: "center" }}>
              {d.ilus(c)}
            </View>
            <View style={{ width: Math.min(width - 48, 420), marginTop: 22 }}>
              <Text accessibilityRole="header" style={{ color: paleta.texto, fontSize: 26, fontWeight: "700", letterSpacing: -0.4, lineHeight: 31 }}>
                {d.titulo}
              </Text>
              <Text style={{ color: paleta.textoMedio, fontSize: 15, lineHeight: 23, marginTop: 10 }}>{d.texto}</Text>
            </View>
          </ScrollView>
        ))}
      </ScrollView>
      <View style={{ paddingHorizontal: 24, paddingBottom: 22, paddingTop: 8 }}>
        <View style={{ flexDirection: "row", justifyContent: "center", gap: 6, marginBottom: 16 }}>
          {DIAPOSITIVAS.map((_, i) => (
            <View key={i} style={{ width: i === indice ? 22 : 7, height: 6, borderRadius: 3, backgroundColor: i === indice ? c.azul : paleta.borde }} />
          ))}
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={() => (ultima ? onTerminar() : irA(indice + 1))}
          style={{ height: 54, borderRadius: 27, backgroundColor: paleta.doradoRelleno, alignItems: "center", justifyContent: "center" }}
        >
          <Text style={{ color: paleta.sobreDorado, fontSize: 16, fontWeight: "800" }}>{DIAPOSITIVAS[indice].boton}</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}
