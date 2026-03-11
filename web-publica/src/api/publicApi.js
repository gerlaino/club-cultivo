import axios from 'axios'

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001'

const api = axios.create({
    baseURL: `${BASE_URL}/public`,
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
})

export default {
    // Club
    async getClub() {
        const { data } = await api.get('/club')
        return data
    },

    // Genéticas
    async getGeneticas() {
        const { data } = await api.get('/geneticas')
        return data.data
    },

    async getGenetica(id) {
        const { data } = await api.get(`/geneticas/${id}`)
        return data.data
    },

    // Noticias
    async getNoticias() {
        const { data } = await api.get('/noticias')
        return data.data
    },

    async getNoticia(id) {
        const { data } = await api.get(`/noticias/${id}`)
        return data.data
    },

    // Eventos
    async getEventos(pasados = false) {
        const url = pasados ? '/eventos?pasados=true' : '/eventos'
        const { data } = await api.get(url)
        return data.data
    },

    async getEvento(id) {
        const { data } = await api.get(`/eventos/${id}`)
        return data.data
    },

    // Galería
    async getGaleria() {
        const { data } = await api.get('/galeria')
        return data.data
    }
}