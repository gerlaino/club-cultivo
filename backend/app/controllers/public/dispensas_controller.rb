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

    # POST /api/d/:token/resena  { dni, genetica_id, estrellas, puntaje_sabor, puntaje_aroma,
    #                             puntaje_efecto, comentario }
    # El paciente deja/edita su reseña del producto. Autorizado por token de dispensa + DNI
    # (misma barrera que el gate). Feedback interno del club, no público. Una por
    # (dispensacion, genetica), editable.
    def resena
      disp = Dispensacion.find_by(token: params[:token])
      return render json: { error: 'No encontrado' }, status: :not_found unless disp

      pac    = disp.paciente
      dni_in = params[:dni].to_s.gsub(/\D/, '')
      if dni_in.blank? || pac&.dni_normalizado != dni_in
        return render json: { error: 'DNI incorrecto' }, status: :unauthorized
      end

      # Corre en without_tenant (público) → Genetica.find_by es cross-club; verificamos que
      # la genética sea del MISMO club del paciente para no reseñar productos de otro club.
      genetica = Genetica.find_by(id: params[:genetica_id])
      unless genetica && genetica.club_id == pac.club_id
        return render json: { error: 'Producto no válido' }, status: :unprocessable_entity
      end

      r = ResenaProducto.find_or_initialize_by(dispensacion_id: disp.id, genetica_id: genetica.id)
      r.assign_attributes(
        club_id:        pac.club_id, # sin tenant fijado, lo seteamos a mano
        paciente_id:    pac.id,
        estrellas:      params[:estrellas],
        puntaje_sabor:  params[:puntaje_sabor].presence,
        puntaje_aroma:  params[:puntaje_aroma].presence,
        puntaje_efecto: params[:puntaje_efecto].presence,
        comentario:     params[:comentario].to_s.strip.presence,
      )
      if r.save
        render json: { ok: true, mi_resena: resena_json(disp, genetica.id) }
      else
        render json: { errors: r.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def serialize(disp)
      snap   = disp.producto_snapshot || {}
      gen    = snap['genetica'] || {}
      pac    = disp.paciente
      club   = pac&.club
      stock  = disp.stock
      # La info ampliada (fotos, descripción, consejos) sale de la genética VIVA, no del
      # snapshot congelado. El snapshot se usa para los valores del momento de la dispensa.
      gen_live = stock&.genetica || stock&.lote&.genetica

      gen_payload = genetica_payload(gen, gen_live)
      gen_payload[:nombre] ||= disp.genetica_nombre # fallback histórico

      {
        codigo:       disp.token,
        socio_numero: pac&.id, # nº de socio del paciente (su propio pasaporte, gateado por DNI)
        fecha:     disp.fecha_dispensacion,
        multi:     items_pasaporte(disp, snap).size > 1,
        cantidad:  (snap['cantidad'] || disp.cantidad)&.to_f,
        unidad:    snap['unidad'] || stock&.unidad || 'g',
        forma:     snap['forma_producto'] || stock&.forma_producto,
        lote:      snap['lote_codigo'] || disp.lote_codigo,
        vencimiento: stock&.fecha_vencimiento_est,
        genetica:    gen_payload,
        genetica_id: gen_live&.id,
        mi_resena:   resena_json(disp, gen_live&.id),
        items:       items_pasaporte(disp, snap),
        club: club ? {
          nombre: club.name,
          logo:   club.logo.attached? ? url_for(club.logo) : nil,
        } : nil,
      }
    end

    # Ficha de la genética: valores del snapshot (inmutables) + enriquecimiento con la
    # genética viva (fotos, descripción, origen, criador, floración, consejos).
    def genetica_payload(snap_gen, gen_live)
      snap_gen ||= {}
      {
        nombre:   snap_gen['nombre'] || gen_live&.nombre,
        tipo:     snap_gen['tipo']   || gen_live&.tipo,
        thc_pct:  snap_gen['thc_pct'] || gen_live&.thc&.to_f,
        cbd_pct:  snap_gen['cbd_pct'] || gen_live&.cbd&.to_f,
        terpenos: snap_gen['terpenos'] || gen_live&.terpenos,
        descripcion:      gen_live&.descripcion,
        origen:           gen_live&.origen,
        criador:          gen_live&.criador,
        tiempo_floracion: gen_live&.tiempo_floracion,
        dificultad:       gen_live&.dificultad,
        consejos_club:    gen_live&.consejos_club,
        registrada_inase:      snap_gen['registrada_inase'] || gen_live&.registrada_inase,
        numero_registro_inase: snap_gen['numero_registro_inase'] || gen_live&.numero_registro_inase,
        fotos:            fotos_urls(gen_live),
      }
    end

    def fotos_urls(gen_live)
      return [] unless gen_live&.fotos&.attached?
      gen_live.fotos.first(4).map { |f| url_for(f) }
    rescue StandardError
      []
    end

    # La reseña propia del paciente para (esta dispensa, esta genética), o nil.
    def resena_json(disp, genetica_id)
      return nil unless genetica_id
      r = ResenaProducto.find_by(dispensacion_id: disp.id, genetica_id: genetica_id)
      return nil unless r
      {
        estrellas:      r.estrellas,
        puntaje_sabor:  r.puntaje_sabor,
        puntaje_aroma:  r.puntaje_aroma,
        puntaje_efecto: r.puntaje_efecto,
        comentario:     r.comentario,
      }
    end

    # Líneas del paquete para el pasaporte. Display desde el snapshot (inmutable); la
    # genética viva (por índice de las líneas reales) aporta id/fotos/consejos y la reseña.
    def items_pasaporte(disp, snap)
      live_items = disp.items.to_a
      fuente = if snap['items'].present?
        snap['items'].each_with_index.map do |it, i|
          { forma: it['forma_producto'], cantidad: it['cantidad']&.to_f, unidad: it['unidad'],
            lote: it['lote_codigo'], snap_gen: it['genetica'] || {}, live: live_items[i] }
        end
      else
        live_items.map do |it|
          st = it.stock
          { forma: st&.forma_producto, cantidad: it.cantidad&.to_f, unidad: st&.unidad,
            lote: it.lote_codigo || st&.lote&.codigo, snap_gen: {}, live: it }
        end
      end

      fuente.map do |it|
        live     = it[:live]
        gen_live = live&.stock&.genetica || live&.stock&.lote&.genetica
        {
          forma:       it[:forma],
          cantidad:    it[:cantidad],
          unidad:      it[:unidad] || 'g',
          lote:        it[:lote],
          genetica:    genetica_payload(it[:snap_gen], gen_live),
          genetica_id: gen_live&.id,
          mi_resena:   resena_json(disp, gen_live&.id),
        }
      end
    end
  end
end
