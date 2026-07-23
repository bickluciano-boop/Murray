package app.ojogps.android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Recibe los comandos que manda ojo_gps_android_bridge.py desde la PC
 * por "adb shell am broadcast". Anda aunque la app no esté abierta,
 * porque está declarado en el Manifest (no registrado en tiempo de
 * ejecución).
 */
class LocationCommandReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SET_LOCATION -> {
                val lat = intent.getStringExtra(EXTRA_LAT)?.toDoubleOrNull()
                val lon = intent.getStringExtra(EXTRA_LON)?.toDoubleOrNull()
                if (lat != null && lon != null) {
                    try {
                        MockLocationController.start(context)
                        MockLocationController.setLocation(context, lat, lon)
                    } catch (_: SecurityException) {
                        // Ojo GPS no está elegida como app de ubicación de
                        // simulación; no hay pantalla acá para avisarlo.
                    }
                }
            }
            ACTION_STOP -> {
                try {
                    MockLocationController.stop(context)
                } catch (_: SecurityException) {
                    // Idem.
                }
            }
        }
    }

    companion object {
        const val ACTION_SET_LOCATION = "app.ojogps.android.SET_LOCATION"
        const val ACTION_STOP = "app.ojogps.android.STOP"
        const val EXTRA_LAT = "lat"
        const val EXTRA_LON = "lon"
    }
}
