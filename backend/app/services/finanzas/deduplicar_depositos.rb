module Finanzas
  # Retira los depósitos de sistema DUPLICADOS (mismo club + sede + clave_sistema).
  #
  # Por qué existen: la siembra corre desde un before_action (`depositos#asegurar_depositos`), y
  # dos requests simultáneos del mismo club entraban los dos, veían los dos que faltaba sembrar y
  # creaban los dos. La unicidad era solo validación de modelo (`validates :clave_sistema,
  # uniqueness:`), que no protege de una race: sin índice en la tabla, las dos inserciones pasan.
  # Se ve en los timestamps de los duplicados de prod: 1-2 ms de diferencia.
  #
  # Criterio: se queda el id MÁS BAJO (el que referencian los datos más viejos), le mueve los
  # insumos y los productos del bar, y retira el resto (soft-delete: recuperable). Idempotente:
  # correrla sin duplicados no hace nada.
  #
  #   Finanzas::DeduplicarDepositos.new(club).call
  #   # => { retirados: [9, 11], insumos: 3, productos: 0 }
  class DeduplicarDepositos
    def initialize(club)
      @club = club
    end

    def call
      resultado = { retirados: [], insumos: 0, productos: 0 }

      # Sin tenant: es mantenimiento, se opera por club_id explícito (y corre desde rake/migración,
      # donde no hay current_user que fije el tenant).
      ActsAsTenant.without_tenant do
        duplicados.each do |_clave, deps|
          keeper, *dups = deps.sort_by(&:id)
          dups.each do |dup|
            # unscoped: mueve TAMBIÉN lo soft-deleted, para que al restaurarlo no quede apuntando
            # a un depósito retirado.
            resultado[:insumos]   += Insumo.unscoped.where(deposito_id: dup.id).update_all(deposito_id: keeper.id)
            resultado[:productos] += BarProducto.unscoped.where(deposito_id: dup.id).update_all(deposito_id: keeper.id)
            dup.destroy! # soft-delete (acts_as_paranoid)
            resultado[:retirados] << dup.id
          end
        end
      end

      resultado
    end

    private

    # Grupos (clave, sede) con más de un depósito vivo. unscoped + deleted_at explícito: los ya
    # retirados no participan (si no, un duplicado retirado volvería a "elegir keeper").
    def duplicados
      Deposito.unscoped
              .where(club_id: @club.id, deleted_at: nil).where.not(clave_sistema: nil)
              .group_by { |d| [d.clave_sistema, d.sede_id] }
              .select { |_k, deps| deps.size > 1 }
    end
  end
end
