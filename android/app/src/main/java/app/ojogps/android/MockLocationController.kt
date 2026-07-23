package app.ojogps.android

import android.content.Context
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.SystemClock

/**
 * Registra Ojo GPS como proveedor de ubicación de prueba de Android
 * (LocationManager.addTestProvider), la misma API que usa cualquier app
 * de ubicación falsa. Requiere que la persona haya elegido "Ojo GPS" en
 * Ajustes > Opciones de desarrollador > Seleccionar app de ubicación de
 * simulación; si no, las llamadas de acá tiran SecurityException.
 */
@Suppress("DEPRECATION")
object MockLocationController {
    private const val PROVIDER = LocationManager.GPS_PROVIDER

    fun start(context: Context) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (locationManager.allProviders.contains(PROVIDER)) {
            try {
                locationManager.removeTestProvider(PROVIDER)
            } catch (_: IllegalArgumentException) {
                // No había un test provider previo con este nombre.
            }
        }
        locationManager.addTestProvider(
            PROVIDER,
            false, false, false, false,
            true, true, true,
            Criteria.POWER_LOW,
            Criteria.ACCURACY_FINE,
        )
        locationManager.setTestProviderEnabled(PROVIDER, true)
    }

    fun setLocation(context: Context, latitude: Double, longitude: Double) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val location = Location(PROVIDER).apply {
            this.latitude = latitude
            this.longitude = longitude
            altitude = 0.0
            accuracy = 5f
            time = System.currentTimeMillis()
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
        }
        locationManager.setTestProviderLocation(PROVIDER, location)
    }

    fun stop(context: Context) {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (locationManager.allProviders.contains(PROVIDER)) {
            locationManager.setTestProviderEnabled(PROVIDER, false)
            locationManager.removeTestProvider(PROVIDER)
        }
    }
}
