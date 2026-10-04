# La bandeja de lo que llegó por el formulario de /bienvenida (`SolicitudContacto`). Pendientes
# primero; «atendida» la saca de la cola (y se puede deshacer).
module SuperAdmin
  class ConsultasController < BaseController
    def index
      consultas = SolicitudContacto.includes(respuestas: :autor).order(Arel.sql('atendida_at IS NOT NULL'), created_at: :desc).limit(200)
      render json: {
        pendientes: SolicitudContacto.pendientes.count,
        consultas: consultas.map { |s| serializar(s) },
      }
    end

    # POST /super_admin/consultas/:id/respuestas — contestarle a quien escribió. Sale por el correo de
    # la plataforma (en un job: se anota si salió o por qué no) y deja la consulta como atendida.
    def responder
      s = SolicitudContacto.find(params[:id])
      r = s.respuestas.new(autor: current_user, texto: params[:texto].to_s.strip)
      return render json: { error: 'Escribí la respuesta.' }, status: :unprocessable_entity unless r.save

      s.update!(atendida_at: Time.current, atendida_por: current_user) unless s.atendida_at
      EnviarRespuestaConsultaJob.perform_later(r.id)
      render json: serializar(s.reload), status: :created
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
       .merge('tipo_label' => s.tipo_label, 'codigo' => s.codigo, 'atendida_por' => s.atendida_por&.nombre_completo,
              'respuestas' => s.respuestas.map { |r|
                { 'id' => r.id, 'texto' => r.texto, 'autor' => r.autor&.nombre_completo, 'created_at' => r.created_at,
                  'enviada_at' => r.enviada_at, 'error' => r.error }
              })
    end
  end
end
