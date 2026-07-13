module Public
  # Pasaporte público de una dispensa, gateado por DNI del paciente.
  # El token (no adivinable) identifica la dispensa; el DNI valida que sea el paciente.
  class DispensasController < BaseController
    self.public_tenant_mode = :token # el token de la dispensa es global → lookup cross-club

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
      # Consejos del club = info ACTUAL de la genética (guardado/recomendaciones), no
      # un valor congelado en el snapshot → se lee de la genética viva.
      gen_live = stock&.genetica || stock&.lote&.genetica

      {
        codigo:    disp.token,
        fecha:     disp.fecha_dispensacion,
        multi:     items_pasaporte(disp, snap).size > 1,
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
          consejos_club:         gen_live&.consejos_club,
          registrada_inase:      gen['registrada_inase'],
          numero_registro_inase: gen['numero_registro_inase'],
        },
        items:        items_pasaporte(disp, snap),
        socio_numero: pac&.id,
        club: club ? {
          nombre: club.name,
          logo:   club.logo.attached? ? url_for(club.logo) : nil,
        } : nil,
      }
    end

    # Líneas del paquete para el pasaporte. Preferimos el snapshot (inmutable); si una
    # dispensa multi-stock no lo tuviera, caemos a las líneas vivas. Single-stock → 1 línea.
    def items_pasaporte(disp, snap)
      fuente = if snap['items'].present?
        snap['items'].map do |it|
          g = it['genetica'] || {}
          { forma: it['forma_producto'], cantidad: it['cantidad']&.to_f, unidad: it['unidad'],
            lote: it['lote_codigo'], genetica: g }
        end
      else
        disp.items.map do |it|
          st = it.stock
          g  = st&.genetica || st&.lote&.genetica
          { forma: st&.forma_producto, cantidad: it.cantidad&.to_f, unidad: st&.unidad,
            lote: it.lote_codigo || st&.lote&.codigo,
            genetica: g && { 'nombre' => g.nombre, 'tipo' => g.tipo, 'thc_pct' => g.thc&.to_f,
                             'cbd_pct' => g.cbd&.to_f, 'terpenos' => g.terpenos } }
        end
      end

      fuente.map do |it|
        g = it[:genetica] || {}
        {
          forma:    it[:forma],
          cantidad: it[:cantidad],
          unidad:   it[:unidad] || 'g',
          lote:     it[:lote],
          genetica: {
            nombre:   g['nombre'],
            tipo:     g['tipo'],
            thc_pct:  g['thc_pct'],
            cbd_pct:  g['cbd_pct'],
            terpenos: g['terpenos'],
            registrada_inase:      g['registrada_inase'],
            numero_registro_inase: g['numero_registro_inase'],
          },
        }
      end
    end
  end
end
