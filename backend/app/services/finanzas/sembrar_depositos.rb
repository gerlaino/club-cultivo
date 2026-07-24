module Finanzas
  # Siembra los depósitos de sistema del club (Cultivo, General, Salón si tiene bar, Dispensación)
  # y backfillea los insumos existentes a su depósito según el viejo `tipo`. Idempotente:
  # correrla de nuevo no duplica ni pisa nombres editados por el admin.
  #
  #   Finanzas::SembrarDepositos.new(club).call
  class SembrarDepositos
    def initialize(club)
      @club = club
    end

    def call
      ActsAsTenant.with_tenant(@club) do
        Finanzas::SembrarCatalogo.new(@club).call # asegura las áreas (unidades de negocio)
        sembrar
        backfill_insumos
      end
      true
    end

    private

    def sembrar
      areas = @club.unidades_negocio.index_by(&:tipo)
      orden = 0
      Deposito::CLAVES_SISTEMA.each do |clave, nombre|
        next if clave == 'salon' && !@club.feature?(:bar)

        orden += 1
        dep = @club.depositos.with_deleted.find_or_initialize_by(clave_sistema: clave)
        dep.restore if dep.persisted? && dep.deleted?
        dep.nombre     = nombre if dep.nombre.blank?
        dep.es_sistema = true
        dep.activo     = true
        dep.orden      = orden if dep.orden.to_i.zero?
        # Vincula el depósito de sistema a su área (no pisa si ya tiene una asignada).
        dep.unidad_negocio ||= areas[Deposito::AREA_TIPO_POR_CLAVE[clave]]
        dep.save!
      end
    end

    # Cada insumo cae en su depósito según el tipo legacy. No pisa los que ya tengan depósito.
    def backfill_insumos
      cultivo = @club.depositos.find_by(clave_sistema: 'cultivo')
      general = @club.depositos.find_by(clave_sistema: 'general')
      @club.insumos.where(deposito_id: nil).find_each do |i|
        i.update_column(:deposito_id, i.tipo == 'general' ? general&.id : cultivo&.id)
      end
    end
  end
end
