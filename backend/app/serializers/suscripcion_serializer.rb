# Lo que la pantalla ve de una suscripción de Mercado Pago (super admin y la propia cuenta).
module SuscripcionSerializer
  def self.call(s, con_cobros: false)
    return nil unless s

    h = { id: s.id, estado: s.estado, estado_label: s.estado_label, origen: s.origen,
          monto_ars: s.monto_ars.to_f, payer_email: s.payer_email, link: s.link,
          ultimo_cobro_at: s.ultimo_cobro_at, created_at: s.created_at }
    if con_cobros
      h[:cobros] = s.cobros.limit(24).map do |c|
        { id: c.id, estado: c.estado, monto_ars: c.monto_ars&.to_f, cobrado_at: c.cobrado_at, extiende_hasta: c.extiende_hasta }
      end
    end
    h
  end
end
