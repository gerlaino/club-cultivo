module Finanzas
  # Siembra los depósitos de sistema del club POR SEDE (General en todas; Cultivo en producción;
  # Salón/Dispensario en social/mixta con bar) y sede-ifica lo legacy: reasigna los insumos de los
  # depósitos club-wide (sede_id nil) a su depósito por-sede y retira los viejos. Idempotente:
  # correrla de nuevo no duplica, no pisa nombres editados, ni re-migra.
  #
  #   Finanzas::SembrarDepositos.new(club).call
  class SembrarDepositos
    def initialize(club)
      @club = club
    end

    def call
      ActsAsTenant.with_tenant(@club) do
        Finanzas::SembrarCatalogo.new(@club).call # asegura las áreas (unidades de negocio)
        return true if @club.sedes.empty?         # sin sedes no hay dónde ubicar depósitos

        sembrar_por_sede
        sedeificar_legacy # reasigna insumos de los club-wide y los retira
        backfill_insumos  # cualquier insumo sin depósito → el de su sede
        linkear_bar_productos # los productos del bar cuelgan del depósito Salón de su sede
      end
      true
    end

    private

    # Sede "principal" para lo que no tiene sede (insumos pool): la más antigua.
    def principal
      @principal ||= @club.sedes.order(:id).first
    end

    # Sedes que EXISTEN hoy (Sede es soft-delete): son las únicas que tienen depósitos sembrados.
    def sedes_vigentes
      @sedes_vigentes ||= @club.sedes.pluck(:id).to_set
    end

    # Un insumo puede apuntar a una sede borrada (o de otro club, en data vieja). En ese caso no hay
    # depósito destino y el legacy quedaba sin migrar PARA SIEMPRE: los insumos nunca se movían, el
    # depósito club-wide no se podía retirar y el club veía "General" y "Cultivo" duplicados.
    # Ante una sede que ya no existe, cae en la principal.
    def sede_destino(sede_id)
      return principal&.id if sede_id.nil? || !sedes_vigentes.include?(sede_id)

      sede_id
    end

    # Qué depósitos del sistema le tocan a cada sede según su tipo.
    def claves_de(sede)
      claves = ['general']                                # todas las sedes
      claves << 'cultivo'      if sede.es_produccion?     # producción / mixta
      claves << 'dispensacion' if sede.es_social?         # social / mixta
      claves << 'salon'        if sede.es_social? && @club.feature?(:bar)
      claves
    end

    def sembrar_por_sede
      areas = @club.unidades_negocio.index_by(&:tipo)
      @club.sedes.order(:id).each do |sede|
        claves_de(sede).each_with_index do |clave, i|
          dep = @club.depositos.with_deleted.find_or_initialize_by(clave_sistema: clave, sede_id: sede.id)
          dep.restore if dep.persisted? && dep.deleted?
          dep.nombre        = Deposito::CLAVES_SISTEMA[clave] if dep.nombre.blank?
          dep.es_sistema    = true
          dep.activo        = true
          dep.orden         = i if dep.orden.to_i.zero?
          dep.unidad_negocio ||= areas[Deposito::AREA_TIPO_POR_CLAVE[clave]]
          dep.save!
        end
      end
    end

    # Migra los depósitos legacy (sede_id nil): reasigna sus insumos al depósito por-sede que
    # corresponde (por la sede del insumo, o la principal si es pool) y retira el viejo (soft-delete).
    def sedeificar_legacy
      @club.depositos.where(sede_id: nil).where.not(clave_sistema: nil).find_each do |old|
        clave = old.clave_sistema
        old.insumos.find_each do |ins|
          sede_id = sede_destino(ins.sede_id)
          dep = deposito_de(clave, sede_id) || deposito_de('general', sede_id)
          ins.update_columns(deposito_id: dep.id, sede_id: sede_id) if dep
        end
        old.reload
        old.destroy if old.insumos.count.zero? # restrict_with_error protege si quedó algún insumo
      end
    end

    # Insumos sin depósito (nuevos o pre-siembra) → el de su tipo + su sede (o la principal).
    def backfill_insumos
      @club.insumos.where(deposito_id: nil).find_each do |i|
        sede_id = sede_destino(i.sede_id)
        clave   = i.tipo == 'general' ? 'general' : 'cultivo'
        dep = deposito_de(clave, sede_id) || deposito_de('general', sede_id)
        i.update_columns(deposito_id: dep.id, sede_id: sede_id) if dep
      end
    end

    def deposito_de(clave, sede_id)
      return nil if sede_id.nil?

      @club.depositos.find_by(clave_sistema: clave, sede_id: sede_id)
    end

    # Cuelga los productos del bar del depósito Salón de la sede de su bar (multi-sede). Solo los
    # que no tienen depósito (no pisa). Idempotente.
    def linkear_bar_productos
      return unless @club.feature?(:bar) && defined?(BarProducto)

      @club.bares.find_each do |bar|
        dep = deposito_de('salon', bar.sede_id)
        next unless dep

        bar.bar_productos.where(deposito_id: nil).update_all(deposito_id: dep.id)
      end
    end
  end
end
