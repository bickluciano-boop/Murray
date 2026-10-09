# Pendientes de Ojo Guard (app + Ojo Guard MS)

Actualizado: 09/10/2026.

## En curso

- [x] **Familia, menores, parte 1** (script `aplicar-familia-menores.ps1`,
  falta correrlo y probarlo). Desde el panel, el titular y los adultos de la
  familia pueden usar **Ubicar ahora**, **Hacer sonar** (y Detener) y
  **Seguir en vivo** sobre el teléfono de una persona con rol MENOR. Los
  amigos no. Cada pedido le avisa al menor por push y por correo ("Luciano
  pidió tu ubicación"), sin modo oculto.
- [ ] **Panel: gestionar a las personas de la familia** (cambiar el rol o
  quitar a alguien). Hoy solo se pueden anular invitaciones sin usar.
- [ ] **Familia, menores, parte 2.** **Pedir evidencia** (foto y audio corto)
  del teléfono del menor, verla en el panel y que el mail le llegue al tutor.

## iPhone

- [ ] **"Hacer sonar" con la app abierta y la perilla en silencio no suena**
  (sí suena con la perilla activa). La app pide sonar en silencio
  (`playsInSilentMode`), pero algo lo pisa. Próxima build: volver a aplicar
  el modo de audio justo antes de sonar y guardar un registro de lo que pasó.
- [ ] **Alertas críticas de Apple.** Pedido enviado o a enviar por Lu (texto
  ya preparado). Si lo aprueban: permiso
  `com.apple.developer.usernotifications.critical-alerts`, sonido de alarma
  propio en el push y pedir el permiso al usuario. Con eso suena en silencio,
  con volumen bajo y con la app cerrada, como "Buscar".
- [ ] **Probar la build 21 en la calle:** app cerrada, caminar unas cuadras y
  ver si "LB iPhone" se mueve solo en el panel.
- [ ] **iPhone de la mujer de Lu:** darla de alta en TestFlight (pruebas
  internas), cuenta propia con "Empresa", unirla a la familia como Adulto.
- [ ] **Consejos de seguridad en la configuración inicial (iPhone):** activar
  "Protección de dispositivo robado" y desactivar el Centro de control con el
  iPhone bloqueado (Ajustes → Face ID y código → "Acceso con el iPhone
  bloqueado"), para que no puedan poner el modo avión sin desbloquearlo.
- [ ] Botón **"Compartir de nuevo"** cortado en Configuración → Familia y
  amigos (va en la próxima build).
- [ ] `eas.json`: agregar el perfil `submit.production` para poder usar
  `--auto-submit` (hoy se manda con `eas submit --platform ios --latest`).

## Android

- [ ] **Modo perdido: al enchufar el cargador**, mandar la ubicación y la
  evidencia al instante (Android avisa a la app cuando lo conectan). Idea
  tomada de un atajo de iPhone que circula en redes, que con el teléfono
  bloqueado probablemente no funciona; Ojo Guard sí puede hacerlo.
- [ ] Instalar y probar la última build de Android (en vivo caminando).

## Familia, más adelante

- [ ] Etapa B: lugares (casa, colegio) y avisos al llegar o salir.
- [ ] Etapa C: SOS del menor.

## Panel y otros

- [ ] Ubicación automática de la notebook cada 15 minutos.
- [ ] Encabezado del panel en el celular, apretado.
- [ ] Actualizar la presentación con una captura del mapa.
- [ ] Tiempo de viaje en auto en "Cómo llegar" (es pago: decide Lu).
