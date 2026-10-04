# La bandeja de lo que llegó por el formulario de /bienvenida (`SolicitudContacto`). Pendientes
# primero; «atendida» la saca de la cola (y se puede deshacer).
module SuperAdmin
  class ConsultasController < BaseController
    def index
      consultas = SolicitudContacto.order(Arel.sql('atendida_at IS NOT NULL'), created_at: :desc).limit(200)
      render json: {
        pendientes: SolicitudContacto.pendientes.count,
        consultas: consultas.map { |s| serializar(s) },
      }
    end

    def update
      s = SolicitudContacto.find(params[:id])
      atendida = ActiveModel::Type::Boolean.new.cast(params[:atendida])
      s.update!(atendida_at: atendida ? Time.current : nil, atendida_por: atendida ? current_user : nil)
      render json: serializar(s)
    end

    private

    def serializar(s)
      s.as_json(only: %i[id tipo nombre email telefono organizacion mensaje atendida_at created_at])
       .merge('tipo_label' => s.tipo_label, 'codigo' => s.codigo, 'atendida_por' => s.atendida_por&.nombre_completo)
    end
  end
end
