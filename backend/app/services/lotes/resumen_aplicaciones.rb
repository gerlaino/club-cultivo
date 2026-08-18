module Lotes
  # Qué se le HIZO a un lote, resumido.
  #
  # La trazabilidad contestaba de dónde salió el producto —qué plantas, con qué peso— pero no qué
  # se le aplicó. Los datos estaban todos en `registros_ambientales` y no los leía nadie.
  #
  # Es un RESUMEN y no un log a propósito. Sesenta riegos uno abajo del otro no los lee nadie: lo
  # que contesta la pregunta real ("¿qué le pusieron a esto?") es la lista de productos distintos
  # y cuántas veces se hizo cada cosa. El detalle queda disponible aparte para quien lo necesite.
  class ResumenAplicaciones
    def initialize(lote)
      @lote = lote
    end

    def call
      return vacio if lote.nil?

      registros = lote.registros_ambientales.order(:registrado_en)
      return vacio if registros.empty?

      {
        registros:     registros.size,
        desde:         registros.first.registrado_en,
        hasta:         registros.last.registrado_en,
        actividades:   actividades(registros),
        nutricion:     nutricion(registros),
        # Lo más sensible del informe para cannabis medicinal: qué se aplicó, contra qué, y
        # cuántos días de carencia. Va SEPARADO de la nutrición — mezclar un fungicida con el
        # bloom en una misma lista es exactamente lo que no puede pasar.
        fitosanitarios: fitosanitarios(registros),
        plagas:        plagas(registros),
        # El log completo, para el que lo pida. Va aparte del resumen y la pantalla lo muestra
        # plegado: un auditor puede necesitar ver registro por registro, pero abrirlo por defecto
        # convierte el informe en sesenta filas que nadie lee.
        detalle:       detalle(registros),
      }
    end

    private

    attr_reader :lote

    def vacio = { registros: 0, actividades: {}, nutricion: {}, fitosanitarios: [], plagas: [], detalle: [] }

    # Un registro por fila, con lo que efectivamente se anotó. Los campos vacíos NO viajan: una
    # tabla llena de guiones es más difícil de leer que una con menos columnas.
    def detalle(registros)
      registros.reverse.map do |r|
        {
          fecha:          r.registrado_en,
          actividades:    Array(r.tareas_realizadas),
          ph:             r.ph&.to_f,
          ec:             r.ec&.to_f,
          temperatura:    r.temperatura&.to_f,
          humedad:        r.humedad&.to_f,
          fertilizacion:  r.notas_fertilizacion.presence,
          fitosanitario:  r.fitosanitario.presence,
          plagas:         (r.plagas_observadas if r.plagas_observadas.present? && r.plagas_observadas != 'ninguna'),
          observaciones:  r.observaciones.presence,
          fuente:         r.fuente,
        }.compact
      end
    end

    # Cuántas veces se hizo cada cosa. Sale del array `tareas_realizadas` de cada registro.
    def actividades(registros)
      registros.flat_map { |r| Array(r.tareas_realizadas) }
               .tally
               .sort_by { |_t, n| -n }
               .to_h
    end

    def nutricion(registros)
      con_fert = registros.select(&:fertilizacion)
      {
        veces:     con_fert.size,
        # Los productos que se nombraron, sin repetir. Es lo que alguien quiere saber: no cuántas
        # veces se fertilizó sino CON QUÉ.
        productos: con_fert.filter_map { |r| r.notas_fertilizacion.presence&.strip }.uniq,
        enraizantes: registros.filter_map { |r| r.producto_enraizante.presence&.strip }.uniq,
      }
    end

    def fitosanitarios(registros)
      registros.select { |r| r.fitosanitario.present? }.map do |r|
        {
          fecha:         r.registrado_en,
          producto:      r.fitosanitario,
          motivo:        r.fitosanitario_motivo,
          carencia_dias: r.carencia_dias,
        }
      end
    end

    # Qué se observó, con cuándo se vio por primera y última vez: una plaga que aparece una vez no
    # es lo mismo que una que estuvo seis semanas.
    def plagas(registros)
      registros.select { |r| r.plagas_observadas.present? && r.plagas_observadas != 'ninguna' }
               .group_by(&:plagas_observadas)
               .map { |plaga, rs| { plaga: plaga, veces: rs.size, desde: rs.first.registrado_en, hasta: rs.last.registrado_en } }
    end
  end
end
