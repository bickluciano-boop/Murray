package expo.modules.sostrigger

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.Settings
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

// Lo que necesita la app para ofrecer el gesto de volumen: saber si el servicio de accesibilidad esta activado y abrir
// las pantallas del sistema donde el dueño lo activa (no se puede activar por programa: lo decide el dueño).
class SosTriggerModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("SosTrigger")

    // ¿Esta activado "Ojo Guard SOS" en Ajustes > Accesibilidad?
    Function("isEnabled") {
      val context = appContext.reactContext ?: return@Function false
      val activados = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        ?: return@Function false
      val mio = ComponentName(context, SosAccessibilityService::class.java)
      val largo = mio.flattenToString()
      val corto = mio.flattenToShortString()
      activados.split(':').any { it.equals(largo, ignoreCase = true) || it.equals(corto, ignoreCase = true) }
    }

    // ¿El servicio esta realmente conectado y recibiendo los botones? (distinto de "esta prendido el interruptor")
    Function("isRunning") {
      SosAccessibilityService.conectado
    }

    // Nombre del audio Bluetooth (auriculares, parlante, audifono) conectado ahora, "" si no hay ninguno, null si no se puede saber.
    // Con uno conectado, Android puede mandar los sonidos de los avisos ahi y no al telefono: la sirena del SOS no se oiria. No pide
    // permiso de Bluetooth. Tipos de AudioDeviceInfo: 7 BLUETOOTH_SCO, 8 BLUETOOTH_A2DP, 23 HEARING_AID, 26 BLE_HEADSET, 27 BLE_SPEAKER.
    Function("bluetoothAudio") {
      val context = appContext.reactContext ?: return@Function null
      try {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return@Function null
        val tipos = setOf(7, 8, 23, 26, 27)
        val conectado = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.type in tipos }
        if (conectado == null) {
          ""
        } else {
          val nombre = conectado.productName?.toString()?.trim().orEmpty()
          if (nombre.isEmpty()) "Bluetooth" else nombre
        }
      } catch (error: Exception) {
        null
      }
    }

    // Devuelve "ok" o "error:<Excepcion>:<mensaje>", como requestDeviceAdmin en theft-detection.
    Function("openAccessibilitySettings") {
      val context = appContext.reactContext ?: return@Function "no_context"
      try {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        context.startActivity(intent)
        "ok"
      } catch (error: Exception) {
        "error:${error.javaClass.simpleName}:${error.message}"
      }
    }

    // Abre la pantalla del canal "SOS de la familia": ahi se ve la sirena y se activa "Anular No interrumpir".
    Function("openSosChannelSettings") {
      val context = appContext.reactContext ?: return@Function "no_context"
      try {
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
          putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
          putExtra(Settings.EXTRA_CHANNEL_ID, "ojo-sos")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        "ok"
      } catch (error: Exception) {
        "error:${error.javaClass.simpleName}:${error.message}"
      }
    }

    // En Android 13+ una app instalada fuera de Play Store tiene los servicios de accesibilidad bloqueados hasta que el
    // dueño toque "Permitir configuracion restringida" en la informacion de la app.
    Function("openAppInfo") {
      val context = appContext.reactContext ?: return@Function "no_context"
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")).apply {
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        "ok"
      } catch (error: Exception) {
        "error:${error.javaClass.simpleName}:${error.message}"
      }
    }
  }
}
