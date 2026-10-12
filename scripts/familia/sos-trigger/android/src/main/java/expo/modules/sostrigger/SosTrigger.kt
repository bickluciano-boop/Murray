package expo.modules.sostrigger

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.facebook.react.HeadlessJsTaskService

// Punto unico que dispara el SOS desde lo nativo: vibra para que quien lo pidio sepa que se registro y arranca la
// tarea de JS (SosTaskService) que manda el pedido con la ubicacion. Mismo patron que TheftDetectionTrigger.
object SosTrigger {
  // Entre dos SOS seguidos tiene que pasar un rato: nadie necesita dos avisos iguales en 20 segundos.
  private const val ESPERA_MS = 20_000L
  private var ultimo = 0L

  fun start(context: Context, reason: String) {
    val ahora = System.currentTimeMillis()
    if (ahora - ultimo < ESPERA_MS) return
    ultimo = ahora
    vibrar(context)
    try {
      val intent = Intent(context, SosTaskService::class.java)
      intent.putExtra("reason", reason)
      context.startService(intent)
      HeadlessJsTaskService.acquireWakeLockNow(context)
    } catch (error: Exception) {
      // Si Android no deja arrancar el servicio en segundo plano (restriccion del fabricante) no hay nada mas que
      // hacer desde aca: la vibracion avisa que se registro, pero no va a llegar el aviso de "SOS enviado".
    }
  }

  @Suppress("DEPRECATION")
  private fun vibrar(context: Context) {
    try {
      val vibrador: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
      } else {
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
      }
      if (vibrador == null) return
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        vibrador.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 300, 120, 300), -1))
      } else {
        vibrador.vibrate(longArrayOf(0, 300, 120, 300), -1)
      }
    } catch (error: Exception) {
      // La vibracion es solo una confirmacion: si falla, el SOS sale igual.
    }
  }
}
