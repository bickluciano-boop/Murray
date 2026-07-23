# Ojo GPS para Android (borrador, sin probar)

Primer esqueleto de la app companion de Android. Implementa lo mínimo
para validar el mecanismo antes de construir toda la interfaz:

- `MockLocationController.kt`: registra Ojo GPS como proveedor de
  ubicación de prueba (`LocationManager.addTestProvider`) y le manda
  coordenadas.
- `MainActivity.kt`: pantalla con lat/lon a mano — el modo solo-celular.
- `LocationCommandReceiver.kt`: recibe comandos por `adb shell am
  broadcast` — lo que va a usar la PC en el modo Windows+Android.

## Importante: esto no se compiló ni se probó

Este proyecto se escribió en un entorno sin el SDK de Android instalado
(no hay forma de bajarlo acá: hace falta `dl.google.com`, bloqueado por
la política de red de este entorno de desarrollo). Gradle sí llegó a leer
los archivos `build.gradle.kts` sin errores de sintaxis, pero no se pudo
resolver el plugin de Android ni compilar ni un solo archivo `.kt`. Tratá
este código como un borrador razonado según la documentación de Android,
no como algo verificado.

## Cómo probarlo

1. Instalá [Android Studio](https://developer.android.com/studio).
2. Abrí esta carpeta (`android/`) como proyecto — Android Studio baja el
   SDK y el wrapper de Gradle solos la primera vez.
3. Conectá un Android por USB con "Depuración por USB" activada (Ajustes
   > Opciones de desarrollador > Depuración por USB; si no ves Opciones
   de desarrollador, tocá 7 veces "Número de compilación" en Ajustes >
   Acerca del teléfono).
4. Con el botón ▶ (Run) instalás la app en el celular.
5. En el celular: Ajustes > Opciones de desarrollador > Seleccionar app
   de ubicación de simulación > elegí "Ojo GPS". Sin este paso, la app
   va a mostrar un cartel avisando que falta y no va a poder simular
   nada — es un permiso que Android exige sí o sí, no depende de la app.
6. Probá primero el modo solo-celular: abrí la app, escribí una latitud
   y longitud, tocá "Aplicar ubicación", y confirmá en otra app con mapa
   (Google Maps, por ejemplo) que la ubicación cambió.
7. Para probar el modo controlado por PC, con la app ya elegida como
   ubicación de simulación y el celular conectado, desde una PC con
   `adb` instalado:
   ```
   adb shell am broadcast -a app.ojogps.android.SET_LOCATION -e lat -34.6037 -e lon -58.3816
   ```
   Debería moverse igual que con el botón de la app, sin tocar la
   pantalla del celular. `ojo_gps_android_bridge.py` (en la raíz del
   repo) hace exactamente este mismo llamado desde Python, pero todavía
   no está conectado a la interfaz principal de Ojo GPS.

## Qué falta (a propósito, no es un olvido)

- Integrarlo a `ojo_gps_app.py`: hoy `ojo_gps_android_bridge.py` existe
  como módulo aparte, sin ningún botón ni pantalla en la app de Windows
  que lo llame. Es el paso siguiente, una vez que esto ya funcione solo.
- Buscador de direcciones, mapa y Recorrido en la app de Android — hoy
  solo hay campos de lat/lon a mano. Se agrega después de validar que el
  mecanismo de fondo (el proveedor de ubicación de prueba) funciona en un
  Android real.
- Ícono propio de la app (hoy usa el ícono por defecto de Android Studio).
