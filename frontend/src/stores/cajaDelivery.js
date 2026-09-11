import { defineStore } from 'pinia'
import { getMiCajaDelivery } from '../lib/api.js'
import { logger } from '../utils/logger.js'

// LO QUE EL REPARTIDOR LLEVA ENCIMA, en un solo lugar.
//
// Lo leen dos pantallas: la solapa Caja (el número, el desglose, rendir) y la BARRA DE ABAJO, que
// le pone un punto a la solapa cuando tiene efectivo sin rendir. Ese punto es lo único que le
// queda recordándoselo: la plata salió del inicio a propósito —esa pantalla es a dónde va ahora—
// pero si nada se lo dice, se va a su casa con la recaudación.
//
// En el store y no en cada vista porque si no, el número de la barra y el de la pantalla saldrían
// de dos consultas distintas y un día dirían cosas distintas de la misma plata.
export const useCajaDeliveryStore = defineStore('cajaDelivery', {
  state: () => ({
    caja:     null,
    cargando: false,
    error:    false,
  }),

  getters: {
    // Sin dato todavía no se pinta nada: un punto que aparece por defecto no significa nada.
    llevaEfectivo: (s) => Number(s.caja?.efectivo_ars || 0) > 0,
  },

  actions: {
    async cargar () {
      this.cargando = true
      this.error    = false
      try {
        const { data } = await getMiCajaDelivery()
        this.caja = data
      } catch (e) {
        // "Vacío" y "no se pudo cargar" no son lo mismo: decirle tranquilamente que no lleva nada
        // a alguien que tiene plata encima es lo peor que le podemos contestar.
        this.error = true
        logger.error('CajaDelivery.cargar', e)
      } finally {
        this.cargando = false
      }
    },
  },
})
