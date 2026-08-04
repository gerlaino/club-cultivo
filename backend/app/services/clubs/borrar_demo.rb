module Clubs
  # Borra un club DEMO de verdad, para poder regenerarlo.
  #
  # `destroy` no alcanza: varios modelos usan paranoia (soft-delete), así que sus filas quedan y la
  # FK bloquea el borrado del padre —el caso concreto es `costo_lotes`, que ni siquiera se crea a
  # mano: lo genera el callback de cada movimiento contable—. Por eso se usa `delete_all`, que va
  # directo al SQL, en orden inverso al de las dependencias.
  #
  # Solo funciona sobre clubes marcados `demo`: un club real no se borra así ni por accidente.
  class BorrarDemo
    def self.call(club:) = new(club: club).call

    def initialize(club:)
      @club = club
    end

    # Borra por club_id SOLO si el modelo existe y tiene esa columna. Sin esto había que adivinar el
    # esquema de cada tabla —`indicacion_medicas` cuelga del paciente, no del club— y el purgado se
    # caía tabla por tabla.
    def borrar_por_club(nombre_modelo)
      modelo = nombre_modelo.safe_constantize
      return unless modelo&.table_exists? && modelo.column_names.include?('club_id')
      modelo.unscoped.where(club_id: @club.id).delete_all
    end

    def call
      raise ArgumentError, "El club ##{@club.id} no está marcado como demo" unless @club.demo?

      ActsAsTenant.without_tenant do
        ActiveRecord::Base.transaction do
          lote_ids  = Lote.unscoped.where(club_id: @club.id).ids
          plant_ids = Plant.unscoped.where(lote_id: lote_ids).ids
          disp_ids  = Dispensacion.unscoped.joins(:paciente)
                                  .where(pacientes: { club_id: @club.id }).ids

          # De las hojas hacia la raíz.
          DispensacionItem.unscoped.where(dispensacion_id: disp_ids).delete_all
          Cobro.unscoped.where(dispensacion_id: disp_ids).delete_all if defined?(Cobro)
          Dispensacion.unscoped.where(id: disp_ids).delete_all
          cc_ids = CuentaCorriente.unscoped.where(club_id: @club.id).ids
          CuentaCorrienteMovimiento.unscoped.where(cuenta_corriente_id: cc_ids).delete_all
          CuentaCorriente.unscoped.where(id: cc_ids).delete_all
          StockMovimiento.unscoped.where(stock_id: Stock.unscoped.where(club_id: @club.id).ids).delete_all
          Stock.unscoped.where(club_id: @club.id).delete_all
          PlantActivity.unscoped.where(plant_id: plant_ids).delete_all
          Nota.unscoped.where(noteable_type: 'Plant', noteable_id: plant_ids).delete_all
          Plant.unscoped.where(id: plant_ids).delete_all
          CostoLote.unscoped.where(lote_id: lote_ids).delete_all
          MovimientoContable.unscoped.where(club_id: @club.id).delete_all
          LoteEvento.unscoped.where(lote_id: lote_ids).delete_all
          RegistroAmbiental.unscoped.where(lote_id: lote_ids).delete_all
          LecturaAmbiental.unscoped.where(club_id: @club.id).delete_all
          Pesada.unscoped.where(lote_id: lote_ids).delete_all
          PesajeManicura.unscoped.where(lote_id: lote_ids).delete_all
          AlertaInterna.unscoped.where(club_id: @club.id).delete_all
          borrar_por_club('Auditoria')
          borrar_por_club('Tarea')
          Lote.unscoped.where(id: lote_ids).delete_all
          # Antes que los pacientes: cuelgan de ellos por FK.
          Turno.unscoped.where(club_id: @club.id).delete_all
          # Estas cuelgan del PACIENTE, no del club: se borran por sus ids.
          paciente_ids = Paciente.unscoped.where(club_id: @club.id).ids
          %w[IndicacionMedica CheckIn Evento MailEnviado Reserva Turno].each do |nombre|
            modelo = nombre.safe_constantize
            next unless modelo&.table_exists?
            if modelo.column_names.include?('paciente_id')
              modelo.unscoped.where(paciente_id: paciente_ids).delete_all
            elsif modelo.column_names.include?('club_id')
              modelo.unscoped.where(club_id: @club.id).delete_all
            end
          end
          Paciente.unscoped.where(id: paciente_ids).delete_all
          Genetica.unscoped.where(club_id: @club.id).delete_all
          Sala.unscoped.where(club_id: @club.id).delete_all
          # El salón: ventas → items → productos → barra, y los insumos del depósito.
          bar_ids = Barra.unscoped.where(club_id: @club.id).ids
          borrar_por_club('BarVentaItem')
          borrar_por_club('BarVenta')
          borrar_por_club('BarProducto')
          Barra.unscoped.where(id: bar_ids).delete_all
          borrar_por_club('Insumo')
          borrar_por_club('CategoriaProducto')
          borrar_por_club('CategoriaContable')
          borrar_por_club('Deposito')
          borrar_por_club('UnidadNegocio')
          Sede.unscoped.where(club_id: @club.id).delete_all
          User.unscoped.where(club_id: @club.id).delete_all
          Club.unscoped.where(id: @club.id).delete_all
        end
      end
    end
  end
end
