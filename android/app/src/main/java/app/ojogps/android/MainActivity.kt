package app.ojogps.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

/** Modo solo-celular: buscar/aplicar una ubicación a mano, sin PC. */
class MainActivity : ComponentActivity() {

    private val requestLocationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (!granted) {
                Toast.makeText(
                    this,
                    "Ojo GPS necesita el permiso de ubicación para simular el GPS.",
                    Toast.LENGTH_LONG,
                ).show()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val inputLat = findViewById<EditText>(R.id.input_lat)
        val inputLon = findViewById<EditText>(R.id.input_lon)
        val status = findViewById<TextView>(R.id.status)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestLocationPermission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        findViewById<Button>(R.id.button_apply).setOnClickListener {
            val lat = inputLat.text.toString().toDoubleOrNull()
            val lon = inputLon.text.toString().toDoubleOrNull()
            if (lat == null || lon == null) {
                Toast.makeText(this, "Ingresá latitud y longitud válidas.", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            try {
                MockLocationController.start(this)
                MockLocationController.setLocation(this, lat, lon)
                status.text = "Ubicación simulada activa:\n$lat, $lon"
            } catch (e: SecurityException) {
                status.text = notSelectedMessage()
            }
        }

        findViewById<Button>(R.id.button_stop).setOnClickListener {
            try {
                MockLocationController.stop(this)
                status.text = "Detenido. GPS real restaurado."
            } catch (e: SecurityException) {
                status.text = notSelectedMessage()
            }
        }
    }

    private fun notSelectedMessage(): String =
        "Ojo GPS no está elegida como app de ubicación de simulación.\n" +
            "Ajustes > Opciones de desarrollador > Seleccionar app de ubicación de simulación > Ojo GPS."
}
