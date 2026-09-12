module Lotes
  # LA TRAZABILIDAD DE UN LOTE: la misma cadena que la de un frasco, cortada antes —origen,
  # cultivo, aplicaciones, análisis— más LOS FRASCOS que salieron de él, cada uno con su cuenta
  # resumida y su link. Existe porque la pregunta puede empezar por la planta («este lote, ¿qué
  # recibió y en qué terminó?»), y un lote en floración todavía no tiene frasco (Germán, sep-2026).
  class Trazabilidad
    def initialize(lote:)
      @lote = lote
    end

    def call
      l = @lote
      plantas = l.plants.order(:nombre).to_a
      vivas, descartadas = plantas.partition { |p| p.state != 'descartada' }
      frascos = l.stocks.order(:created_at).to_a

      {
        lote: {
          id: l.id, codigo: l.codigo, estado: l.estado, sede: l.sede&.nombre, sala: l.sala&.nombre,
          start_date: l.start_date, dias_en_estado: l.dias_en_estado,
          genetica: l.genetica && {
            id: l.genetica.id, nombre: l.genetica.nombre_declarado, nombre_propio: l.genetica.nombre,
            declarada: l.genetica.declarada_como.present?, numero_registro_inase: l.genetica.numero_inase_declarado,
            tipo: l.genetica.tipo, thc: l.genetica.thc, cbd: l.genetica.cbd,
          },
        },
        aplicaciones:         Lotes::ResumenAplicaciones.new(l).call,
        analisis_laboratorio: l.analisis_laboratorio.order(fecha_analisis: :desc).map { |a|
          { fecha: a.fecha_analisis, laboratorio: a.laboratorio, thc_pct: a.thc_pct&.to_f,
            cbd_pct: a.cbd_pct&.to_f, cbg_pct: a.cbg_pct&.to_f, terpenos: a.terpenos_principales }
        },
        cronologia:           Lotes::Cronologia.new(l).call,
        plantas:              vivas.map { |p| { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, origen: p.origen,
                                                 estado: p.state, peso_g: p.peso_seco&.to_f } },
        plantas_descartadas:  descartadas.map { |p| { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, motivo_descarte: p.motivo_descarte } },
        frascos: frascos.map { |s|
          { id: s.id, numero: s.numero_lote_producto, forma: s.forma_producto, unidad: s.unidad,
            origen: s.origen, sede: s.sede&.nombre, cantidad_inicial: s.cantidad_inicial.to_f,
            cantidad: s.cantidad.to_f, fecha_elaboracion: s.fecha_elaboracion }
        },
      }
    end
  end
end
