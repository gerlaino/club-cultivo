import { ref, computed } from 'vue'

// Environmental Sensing Service (standard BLE - 0x181A)
const ESS_SERVICE  = 0x181A
const TEMP_CHAR    = 0x2A6E  // Temperature (sint16, factor 0.01)
const HUMIDITY_CHAR = 0x2A6F // Humidity    (uint16, factor 0.01)

// Bluelab no documenta su GATT — intentamos ESS estándar y fallback manual.
// Si el dispositivo usa un service propietario, los valores quedan null y el
// cultivador los ingresa a mano desde la pantalla del sensor.

export function useBluelabBLE() {
  const dispositivo   = ref(null)
  const servidor      = ref(null)
  const conectando    = ref(false)
  const conectado     = ref(false)
  const error         = ref(null)

  const lecturas = ref({ ec: null, ph: null, temperatura: null })

  const soportado = computed(() => typeof navigator !== 'undefined' && 'bluetooth' in navigator)

  async function conectar() {
    if (!soportado.value) {
      error.value = 'Este navegador no soporta Web Bluetooth. Usá Chrome o Edge en Android/escritorio.'
      return
    }
    conectando.value = true
    error.value = null
    lecturas.value = { ec: null, ph: null, temperatura: null }

    try {
      // Mostramos el picker nativo — el cultivador elige el dispositivo físicamente
      dispositivo.value = await navigator.bluetooth.requestDevice({
        filters: [
          { namePrefix: 'BL' },
          { namePrefix: 'Bluelab' },
          { namePrefix: 'Pulse' },
          { namePrefix: 'PULSE' },
        ],
        optionalServices: [ESS_SERVICE],
      }).catch(() =>
        // Si ningún filtro matchea, dejamos que elija cualquier dispositivo
        navigator.bluetooth.requestDevice({
          acceptAllDevices: true,
          optionalServices: [ESS_SERVICE],
        })
      )

      servidor.value = await dispositivo.value.gatt.connect()
      conectado.value = true

      dispositivo.value.addEventListener('gattserverdisconnected', () => {
        conectado.value = false
        servidor.value  = null
      })

      await leerESS()
    } catch (e) {
      if (e.name === 'NotFoundError' || e.message?.includes('cancelled')) {
        // Usuario canceló el picker — no es error
        error.value = null
      } else {
        error.value = `Error al conectar: ${e.message}`
      }
      conectado.value = false
    } finally {
      conectando.value = false
    }
  }

  async function leerESS() {
    if (!servidor.value) return
    try {
      const service = await servidor.value.getPrimaryService(ESS_SERVICE)

      // Temperatura
      try {
        const char = await service.getCharacteristic(TEMP_CHAR)
        const val  = await char.readValue()
        const raw  = val.getInt16(0, true) // little-endian sint16
        lecturas.value.temperatura = parseFloat((raw / 100).toFixed(1))
      } catch { /* sensor no tiene este characteristic */ }

      // Humedad (no es lo que queremos guardar pero ayuda al VPD)
      try {
        const char = await service.getCharacteristic(HUMIDITY_CHAR)
        const val  = await char.readValue()
        const raw  = val.getUint16(0, true)
        lecturas.value.humedad = parseFloat((raw / 100).toFixed(1))
      } catch { /* ignorar */ }

      // EC y pH no tienen característicos estándar en BLE core spec.
      // Quedan null → ingreso manual desde la pantalla del sensor.
    } catch {
      // ESS service no disponible en este dispositivo — valores quedan null
    }
  }

  async function actualizar() {
    if (!conectado.value || !servidor.value) return
    await leerESS()
  }

  async function desconectar() {
    try { dispositivo.value?.gatt?.disconnect() } catch {}
    conectado.value = false
    servidor.value  = null
  }

  return {
    soportado,
    conectando,
    conectado,
    error,
    lecturas,
    dispositivo,
    conectar,
    actualizar,
    desconectar,
  }
}
