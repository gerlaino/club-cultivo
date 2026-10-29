// CALIDAD DE LA FLOR SECA (29-oct-2026, pedido de Javi): Altos, Medios, Bajos u Otro. Las opciones,
// si es obligatoria en esta organización y de qué formas se puede producir las manda el backend en
// `/me` (`reglas_stock`, ver `Stock::CALIDADES`); acá sólo se ofrecen. El backend rechaza lo mismo.
import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'

export function useCalidadFlor() {
  const auth = useAuthStore()
  const reglas = computed(() => auth.user?.reglas_stock || {})

  const calidades   = computed(() => Object.entries(reglas.value.calidades || {}).map(([value, label]) => ({ value, label })))
  const obligatoria = computed(() => !!reglas.value.calidad_obligatoria)

  // Lo que le falta a un frasco NUEVO de flor seca para poder crearse, o null. «Otro» dice qué es.
  function faltaCalidad({ calidad, descripcion } = {}) {
    if (!obligatoria.value) return null
    if (!calidad) return 'Elegí la calidad de la flor (Altos, Medios, Bajos u Otro)'
    if (calidad === 'otro' && !String(descripcion || '').trim()) return 'Con calidad «Otro», contá en la descripción qué es'
    return null
  }

  return { calidades, obligatoria, faltaCalidad }
}
