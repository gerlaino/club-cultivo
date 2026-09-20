# «Aplicar receta» al regar. Recibe el/los registros de riego recién creados (uno por lote: la
# sala reparte), la receta o los productos sueltos, los litros y —si la persona los tocó— las
# cantidades finales. Descuenta cada producto del depósito, imputa el costo a los lotes y deja
# en cada registro una COPIA de lo aplicado (`nutricion`), para que editar la receta después no
# cambie el historial.
#
# NO BLOQUEA POR STOCK (Germán, 20-sep-2026): el riego ya pasó, y capaz el envase está en la
# mesada sin haberse cargado la compra. Si falta, por producto: `descontar_disponible` (baja lo
# que hay y queda en 0) o `no_descontar`. Lo que faltó queda anotado en la copia.
module Nutricion
  class Aplicar
    Resultado = Struct.new(:nutricion, :faltantes, keyword_init: true)

    MODOS_FALTANTE = %w[descontar_disponible no_descontar].freeze

    # items: [{ insumo_id:, cantidad:, modo_faltante: }] — cantidad ya en la unidad del insumo
    #        (ml o g). Si no viene, se calcula de la receta con los litros.
    def initialize(club:, usuario:, registros:, litros:, receta: nil, items: nil, sala: nil)
      @club, @usuario, @registros = club, usuario, Array(registros)
      @litros  = litros.to_d
      @receta  = receta
      @items   = items
      @sala    = sala
    end

    def call
      lista = lineas
      return Resultado.new(nutricion: nil, faltantes: []) if lista.empty?

      lotes = @registros.map(&:lote).compact.uniq
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
              cantidad: descontar, created_by: @usuario, lotes: lotes, sala: @sala,
              fecha: @registros.first.registrado_en.to_date, notas: "Receta#{@receta ? " «#{@receta.nombre}»" : ''}",
              registro_ambiental: @registros.first
            )
            costo = consumos.sum { |c| c.costo_imputado_ars.to_d }
          end
          aplicados << { 'insumo_id' => insumo.id, 'nombre' => insumo.nombre, 'unidad' => insumo.unidad_medida,
                         'dosis' => l[:dosis]&.to_f, 'dosis_unidad' => l[:unidad],
                         'cantidad' => pedido.to_f, 'descontado' => descontar.to_f,
                         'faltante' => [(pedido - descontar), 0].max.to_f, 'costo_ars' => costo.to_f }
        end

        copia = {
          'receta_id' => @receta&.id, 'receta_nombre' => @receta&.nombre,
          'ph_objetivo' => @receta&.ph_objetivo&.to_f, 'ec_objetivo' => @receta&.ec_objetivo&.to_f,
          'litros' => @litros.to_f, 'items' => aplicados,
          'costo_ars' => aplicados.sum { |a| a['costo_ars'] }.round(2),
        }
        @registros.each { |r| r.update_columns(receta_id: @receta&.id, litros: @litros, nutricion: copia) }
        Resultado.new(nutricion: copia, faltantes: faltantes)
      end
    end

    # Al borrar un registro de riego, lo descontado vuelve al depósito y el costo sale del lote.
    def self.revertir!(registro)
      consumos = InsumoConsumo.where(registro_ambiental_id: registro.id).includes(:insumo, :lote).to_a
      return if consumos.empty?
      ActiveRecord::Base.transaction do
        consumos.each do |c|
          c.insumo.reponer_stock!(cantidad: c.cantidad)
          lote = c.lote
          # El consumo es paranoico (queda la fila): se desata del registro antes, o la FK
          # frena el borrado del registro.
          c.update_columns(registro_ambiental_id: nil)
          c.destroy!
          CostoDesdeLibroService.new(lote: lote, actualizado_por: registro.user).call if lote
        end
      end
    end

    private

    def lineas
      base = @receta ? @receta.calcular(@litros) : []
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
