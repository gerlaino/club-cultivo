module Public
  # Pasaporte público de una dispensa, gateado por DNI del paciente.
  # El token (no adivinable) identifica la dispensa; el DNI valida que sea el paciente.
  class DispensasController < BaseController
    # GET /d/:token  → datos mínimos para pintar el gate (club). No expone nada sensible.
    def preview
      disp = Dispensacion.find_by(token: params[:token])
      return render json: { error: 'No encontrado' }, status: :not_found unless disp

      club = disp.paciente&.club
      render json: {
        club: club ? { nombre: club.name, logo: (club.logo.attached? ? url_for(club.logo) : nil) } : nil,
        fecha: disp.fecha_dispensacion,
      }
    end

    # POST /d/:token/ver  { dni }  → pasaporte completo si el DNI coincide.
    def ver
      disp = Dispensacion.find_by(token: params[:token])
      return render json: { error: 'No encontrado' }, status: :not_found unless disp

      dni_in = params[:dni].to_s.gsub(/\D/, '')
      if dni_in.blank? || disp.paciente&.dni_normalizado != dni_in
        return render json: { error: 'DNI incorrecto' }, status: :unauthorized
      end

      render json: serialize(disp)
    end

    private

    def serialize(disp)
      snap   = disp.producto_snapshot || {}
      gen    = snap['genetica'] || {}
      pac    = disp.paciente
      club   = pac&.club
      stock  = disp.stock

      {
        codigo:    disp.token,
        fecha:     disp.fecha_dispensacion,
        cantidad:  (snap['cantidad'] || disp.cantidad)&.to_f,
        unidad:    snap['unidad'] || stock&.unidad || 'g',
        forma:     snap['forma_producto'] || stock&.forma_producto,
        lote:      snap['lote_codigo'] || disp.lote_codigo,
        vencimiento: stock&.fecha_vencimiento_est,
        genetica: {
          nombre:   gen['nombre'] || disp.genetica_nombre,
          tipo:     gen['tipo'],
          thc_pct:  gen['thc_pct'],
          cbd_pct:  gen['cbd_pct'],
          terpenos: gen['terpenos'],
          registrada_inase:      gen['registrada_inase'],
          numero_registro_inase: gen['numero_registro_inase'],
        },
        socio_numero: pac&.id,
        club: club ? {
          nombre: club.name,
          logo:   club.logo.attached? ? url_for(club.logo) : nil,
        } : nil,
      }
    end
  end
end
