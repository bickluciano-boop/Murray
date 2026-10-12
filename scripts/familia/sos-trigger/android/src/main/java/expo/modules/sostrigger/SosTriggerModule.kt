package expo.modules.sostrigger

import android.content.ComponentName
import android.content.Intent
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
