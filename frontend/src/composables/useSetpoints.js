import { computed } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'

export function useSetpoints() {
  const store = useAmbienteStore()

  function getSetpoint(tipo, fase, geneticaId = null) {
    const all = store.setpoints
    const sp = all.find(s =>
      s.tipo_lectura === tipo &&
      s.fase === fase &&
      s.genetica_id === geneticaId
    )
    if (sp) return sp
    return all.find(s =>
      s.tipo_lectura === tipo &&
      s.fase === fase &&
      !s.genetica_id
    ) || null
  }

  function colorForValor(valor, setpoint) {
    if (!setpoint || valor == null) return 'gray'
    const { valor_min, valor_max, valor_ideal } = setpoint
    if (valor < valor_min || valor > valor_max) return 'red'
    const margen = (valor_max - valor_min) * 0.1
    if (valor < valor_min + margen || valor > valor_max - margen) return 'yellow'
    return 'green'
  }

  return {
    getSetpoint,
    colorForValor,
    setpoints: computed(() => store.setpoints),
  }
}
