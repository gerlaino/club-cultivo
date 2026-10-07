# Saca a una persona del equipo. UNA sola forma, porque la piden dos puertas —el panel de
# plataforma y la pantalla de Equipo de la organización— y la del panel nunca anduvo:
#
# - `User` es paranoid (`Restorable`): `destroy` es una baja lógica y la historia («dispensó
#   Juan», sus cierres, su rastro) queda intacta. Pero sus dependencias (salas y sedes
#   asignadas, disponibilidad de médico) son modelos de organización, y el panel de
#   plataforma no tiene organización fijada: cada baja desde ahí reventaba con `NoTenantSet`
#   y la pantalla se tragaba el error. Por eso la baja corre con el tenant de la persona.
# - El índice único de `users.email` cuenta las filas dadas de baja: sin liberar el mail no
#   se podía volver a dar de alta a la misma persona (la validación pasaba y la base no).
#   Se le pega una marca, como hace `Club#soft_delete!` con los de una organización borrada.
#
# Devuelve el usuario; levanta `Acceso::DarDeBaja::Error` con un motivo para mostrar.
module Acceso
  class DarDeBaja
    class Error < StandardError; end

    MARCA = '_baja_'

    def self.call(user, por:) = new(user, por:).call

    def initialize(user, por:)
      @user = user
      @por  = por
    end

    def call
      raise Error, 'No se puede dar de baja a un super admin.' if @user.super_admin?
      raise Error, 'No podés darte de baja a vos mismo.'      if @user.id == @por&.id

      ActsAsTenant.with_tenant(@user.club) do
        User.transaction do
          @user.update_columns(email: "#{@user.email}#{MARCA}#{@user.id}", deleted_by_id: @por&.id)
          raise Error, @user.errors.full_messages.to_sentence.presence || 'No se pudo dar de baja.' unless @user.destroy
        end
      end
      @user
    end
  end
end
