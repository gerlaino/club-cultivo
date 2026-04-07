import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api/publicApi.js'

export const useClubStore = defineStore('club', () => {
    const club = ref(null)
    const loading = ref(false)
    const loaded = ref(false)

    async function fetchClub() {
        if (loaded.value) return
        loading.value = true
        try {
            club.value = await api.getClub()
            loaded.value = true
        } catch (e) {
            console.error('Error cargando club:', e)
        } finally {
            loading.value = false
        }
    }

    return { club, loading, fetchClub }
})