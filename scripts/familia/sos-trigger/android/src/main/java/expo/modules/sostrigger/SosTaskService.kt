package expo.modules.sostrigger

import android.content.Intent
import com.facebook.react.HeadlessJsTaskService
import com.facebook.react.bridge.Arguments
import com.facebook.react.jstasks.HeadlessJsTaskConfig

// Nombre de la tarea JS registrada en src/sosTask.ts con AppRegistry.registerHeadlessTask: tiene que coincidir
// exactamente.
private const val TASK_NAME = "OjoGuardSosTask"

class SosTaskService : HeadlessJsTaskService() {
  override fun getTaskConfig(intent: Intent?): HeadlessJsTaskConfig? {
    val data = Arguments.createMap()
    data.putString("reason", intent?.getStringExtra("reason") ?: "volumen")
    return HeadlessJsTaskConfig(
      TASK_NAME,
      data,
      // Ubicacion (hasta 6 s), direccion (hasta 2,5 s) y el pedido al servidor, con un par de reintentos si no hay red.
      40000L,
      true,
    )
  }
}
