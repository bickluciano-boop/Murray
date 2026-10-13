package expo.modules.sostrigger

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

// Gesto de SOS sin abrir la app: mantener apretados los DOS botones de volumen (subir y bajar) durante 3 segundos.
// Se necesitan los dos a la vez para que no salga por apretar uno solo al subir o bajar el volumen. Los eventos de
// teclado NO se consumen (devuelve false): el volumen sigue funcionando igual. Funciona con la pantalla apagada.
// Solo mira los botones de volumen; no lee la pantalla ni nada de lo que se escribe (ver ojo_sos_accessibility.xml).
class SosAccessibilityService : AccessibilityService() {
  private val handler = Handler(Looper.getMainLooper())
  private var subirApretado = false
  private var bajarApretado = false
  private var contando = false
  // Ya salio el SOS con esta apretada: hasta que no se suelte alguno de los dos no se vuelve a armar.
  private var yaSalio = false

  private val disparar = Runnable {
    contando = false
    yaSalio = true
    SosTrigger.start(applicationContext, "volumen")
  }

  // Android deja "prendido" el interruptor aunque el servicio se haya caido o no se haya vuelto a enganchar (por ejemplo
  // despues de actualizar la app). `conectado` dice si de verdad esta recibiendo los botones: la app lo muestra en
  // "Revisar mi protección".
  override fun onServiceConnected() {
    super.onServiceConnected()
    conectado = true
  }

  override fun onDestroy() {
    conectado = false
    super.onDestroy()
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    // No se usa: el servicio solo existe para recibir los botones de volumen.
  }

  override fun onInterrupt() {
    cancelar()
  }

  override fun onKeyEvent(event: KeyEvent): Boolean {
    val tecla = event.keyCode
    if (tecla != KeyEvent.KEYCODE_VOLUME_UP && tecla != KeyEvent.KEYCODE_VOLUME_DOWN) return false
    val apretada = when (event.action) {
      KeyEvent.ACTION_DOWN -> true
      KeyEvent.ACTION_UP -> false
      else -> return false
    }
    if (tecla == KeyEvent.KEYCODE_VOLUME_UP) subirApretado = apretada else bajarApretado = apretada
    if (subirApretado && bajarApretado) {
      if (!contando && !yaSalio) {
        contando = true
        handler.postDelayed(disparar, MANTENER_MS)
      }
    } else {
      cancelar()
      yaSalio = false
    }
    return false
  }

  override fun onUnbind(intent: android.content.Intent?): Boolean {
    cancelar()
    conectado = false
    return super.onUnbind(intent)
  }

  private fun cancelar() {
    if (contando) {
      handler.removeCallbacks(disparar)
      contando = false
    }
  }

  companion object {
    const val MANTENER_MS = 3000L

    @Volatile
    var conectado: Boolean = false
  }
}
