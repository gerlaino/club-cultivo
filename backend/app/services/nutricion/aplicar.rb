# «Aplicar receta». Dos puertas, una sola regla:
#
# - **Al regar** (`registros:`): el/los registros de riego recién creados (uno por lote: la sala
#   reparte). La base de la receta son los litros.
# - **Al suelo de una cama** (`cama_registro:`): top dress, té al suelo, mezcla de armado,
#   cobertura, mulch, inoculación (suelo vivo, ver `CamaRegistro`). La base es la que corresponda
#   al uso de la receta: m² (top dress), litros de suelo (mezcla) o litros (té). El costo va a los
#   lotes en cultivo de la cama en ese ciclo, repartido por sus m²; sin lotes, queda en la cama.
#
# En los dos casos: descuenta cada producto del depósito, imputa el costo y deja en el registro una
# COPIA de lo aplicado (`nutricion`), para que editar la receta después no cambie el historial.
#
# NO BLOQUEA POR STOCK (Germán, 20-sep-2026): el riego ya pasó, y capaz el envase está en la
# mesada sin haberse cargado la compra. Si falta, por producto: `descontar_disponible` (baja lo
# que hay y queda en 0) o `no_descontar`. Lo que faltó queda anotado en la copia.
module Nutricion
  class Aplicar
    Resultado = Struct.new(:nutricion, :faltantes, keyword_init: true)

    MODOS_FALTANTE = %w[descontar_disponible no_descontar].freeze

    # items: [{ insumo_id:, cantidad:, modo_faltante: }] — cantidad ya en la unidad del insumo
    #        (ml o g). Si no viene, se calcula de la receta con la base.
    # base:  la cantidad contra la que se multiplica la dosis. Sin ella, los litros.
    def initialize(club:, usuario:, registros: [], litros: nil, receta: nil, items: nil, sala: nil,
                   cama_registro: nil, base: nil)
      @club, @usuario, @registros = club, usuario, Array(registros)
      @litros  = litros.to_d
      @base    = (base.presence || litros).to_d
      @receta  = receta
      @items   = items
      @sala    = sala
      @cama_registro = cama_registro
    end

    def call
      lista = lineas
      return Resultado.new(nutricion: nil, faltantes: []) if lista.empty?

      lotes = lotes_que_pagan
      pesos = pesos_de(lotes)
      aplicados = []
      faltantes = []

      ActiveRecord::Base.transaction do
        lista.each do |l|
          insumo = @club.insumos.find(l[:insumo_id])
          pedido = l[:cantidad].to_d
          disponible = insumo.stock_actual.to_d
          descontar = pedido
          if pedido > disponible
            faltantes << { insumo_id: insumo.id, nombre: insumo.nombre, faltante: (pedido - disponible).round(2).to_f, unidad: insumo.unidad_medida }
            descontar = l[:modo_faltante] == 'no_descontar' ? 0.to_d : disponible
          end
          costo = 0.to_d
          if descontar > 0
            consumos = insumo.registrar_consumo_repartido!(
              cantidad: descontar, created_by: @usuario, lotes: lotes, sala: @sala || @cama_registro&.cama&.sala,
              fecha: fecha, notas: notas,
              registro_ambiental: @registros.first,
              cama: @cama_registro&.cama, cama_registro: @cama_registro, pesos: pesos
            )
            costo = consumos.sum { |c| c.costo_imputado_ars.to_d }
          end
          aplicados << { 'insumo_id' => insumo.id, 'nombre' => insumo.nombre, 'unidad' => insumo.unidad_medida,
                         'dosis' => l[:dosis]&.to_f, 'dosis_unidad' => l[:unidad],
                         'cantidad' => pedido.to_f, 'descontado' => descontar.to_f,
                         'faltante' => [(pedido - descontar), 0].max.to_f, 'costo_ars' => costo.to_f }
        end

        copia = {
          'receta_id' => @receta&.id, 'receta_nombre' => @receta&.nombre, 'uso' => @receta&.uso,
          'ph_objetivo' => @receta&.ph_objetivo&.to_f, 'ec_objetivo' => @receta&.ec_objetivo&.to_f,
          'litros' => @litros.to_f, 'base' => @base.to_f, 'base_unidad' => base_unidad,
          'items' => aplicados,
          'costo_ars' => aplicados.sum { |a| a['costo_ars'] }.round(2),
          # A quién se le cargó la plata (lote → pesos), para que la ficha lo diga.
          'lotes' => lotes.map { |lo| { 'id' => lo.id, 'codigo' => lo.codigo } },
        }
        if @cama_registro
          @cama_registro.update_columns(receta_id: @receta&.id, nutricion: copia)
        else
          @registros.each { |r| r.update_columns(receta_id: @receta&.id, litros: @litros, nutricion: copia) }
        end
        Resultado.new(nutricion: copia, faltantes: faltantes)
      end
    end

    # Al borrar un registro (de riego o de la cama), lo descontado vuelve al depósito y el costo
    # sale del lote.
    def self.revertir!(registro)
      columna = registro.is_a?(CamaRegistro) ? :cama_registro_id : :registro_ambiental_id
      consumos = InsumoConsumo.where(columna => registro.id).includes(:insumo, :lote).to_a
      return if consumos.empty?
      ActiveRecord::Base.transaction do
        consumos.each do |c|
          c.insumo.reponer_stock!(cantidad: c.cantidad)
          lote = c.lote
          # El consumo es paranoico (queda la fila): se desata del registro antes, o la FK
          # frena el borrado del registro.
          c.update_columns(columna => nil)
          c.destroy!
          CostoDesdeLibroService.new(lote: lote, actualizado_por: registro.user).call if lote
        end
      end
    end

    private

    # Riego: los lotes de los registros. Cama: los del ciclo en el que cayó el registro (los que
    # estaban en la cama ese día); sin ciclo —cama vacía, armado, descanso—, nadie: queda en la cama.
    def lotes_que_pagan
      return @registros.map(&:lote).compact.uniq unless @cama_registro
      ciclo = @cama_registro.cama_ciclo
      return [] if ciclo.nil?
      ciclo.lotes.where(estado: Lote::CULTIVO_ESTADOS).to_a.presence || ciclo.lotes.to_a
    end

    def pesos_de(lotes)
      return nil unless @cama_registro
      lotes.to_h { |l| [l.id, l.m2_ocupados.to_d] }
    end

    def fecha = (@cama_registro || @registros.first).registrado_en.to_date

    def notas
      que = @cama_registro ? CamaRegistro::TIPO_LABELS[@cama_registro.tipo] : 'Receta'
      "#{que}#{@receta ? " «#{@receta.nombre}»" : ''}#{@cama_registro ? " · #{@cama_registro.cama.nombre}" : ''}"
    end

    def base_unidad
      return 'L' unless @receta
      Receta::BASE_UNIDAD[@receta.uso]
    end

    def lineas
      base = @receta ? @receta.calcular(@base) : []
      return base.map { |b| b.merge(modo_faltante: 'descontar_disponible') } if @items.blank?

      @items.map do |it|
        ref = base.find { |b| b[:insumo_id] == it[:insumo_id].to_i } || {}
        { insumo_id: it[:insumo_id].to_i, cantidad: it[:cantidad].presence || ref[:cantidad],
          dosis: ref[:dosis], unidad: ref[:unidad],
          modo_faltante: MODOS_FALTANTE.include?(it[:modo_faltante].to_s) ? it[:modo_faltante].to_s : 'descontar_disponible' }
      end.select { |l| l[:cantidad].to_d > 0 }
    end
  end
end
