class UserSede < ApplicationRecord
  include Restorable
  self.table_name = 'user_sedes'
  belongs_to :user
  belongs_to :sede
  validates :sede_id, uniqueness: { scope: :user_id }
  # Cada rol sólo se asigna a las sedes donde tiene algo que hacer (`Sede::TIPOS_POR_ROL`).
  validate :sede_del_tipo_del_rol

  private

  def sede_del_tipo_del_rol
    return if user.nil? || sede.nil?
    return if Sede.tipos_para_rol(user.role).include?(sede.tipo)

    rol  = Club::ROLES_META.dig(user.role, :label) || user.role
    tipo = { 'social' => 'de dispensario', 'produccion' => 'de producción', 'mixta' => 'mixta' }[sede.tipo] || sede.tipo
    errors.add(:base, "Un #{rol.downcase} no se asigna a una sede #{tipo}: no tiene nada que hacer ahí.")
  end
end
