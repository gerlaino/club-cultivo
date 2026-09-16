# Cuándo entró alguien por última vez. Es la métrica número uno de churn —¿cuándo entró alguien
# de esta organización por última vez?— y no existía: «en silencio» se medía por la última
# dispensa y el último lote, y una organización sólo-Cultivo aparecía en silencio trabajando a
# diario. No es `devise :trackable`: con JWT cada request autentica, y el hook de Devise
# escribiría en la base en cada uno. Esto se toca como mucho una vez por hora
# (`ApplicationController#marcar_visto!`).
class AddVistoAtAUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :visto_at, :datetime
    add_index  :users, [:club_id, :visto_at]
  end
end
