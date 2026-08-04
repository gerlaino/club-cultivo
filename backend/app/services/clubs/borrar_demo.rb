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
          Auditoria.unscoped.where(club_id: @club.id).delete_all if defined?(Auditoria)
          Tarea.unscoped.where(club_id: @club.id).delete_all if defined?(Tarea)
          Lote.unscoped.where(id: lote_ids).delete_all
          Paciente.unscoped.where(club_id: @club.id).delete_all
          Genetica.unscoped.where(club_id: @club.id).delete_all
          Sala.unscoped.where(club_id: @club.id).delete_all
          Deposito.unscoped.where(club_id: @club.id).delete_all if defined?(Deposito)
          Sede.unscoped.where(club_id: @club.id).delete_all
          User.unscoped.where(club_id: @club.id).delete_all
          Club.unscoped.where(id: @club.id).delete_all
        end
      end
    end
  end
end
