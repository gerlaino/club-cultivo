import { defineStore } from 'pinia'
import { ref } from 'vue'
import { getPortalClub } from '@/lib/portalApi'

// La ficha de la organización tal como la ve su miembro: nombre, logo, contacto, color.
// Es OTRA cosa que `stores/club.js`, que es la configuración interna que edita el admin.
export const usePortalClubStore = defineStore('portal-club', () => {
  const club = ref(null)
  const loading = ref(false)
  const loaded = ref(false)

  async function fetchClub() {
    if (loaded.value) return
    loading.value = true
    try {
      club.value = await getPortalClub()
      loaded.value = true
    } catch (e) {
      console.error('Error cargando la organización:', e)
    } finally {
      loading.value = false
    }
  }

  return { club, loading, fetchClub }
})
