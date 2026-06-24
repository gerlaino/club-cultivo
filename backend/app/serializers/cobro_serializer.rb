class CobroSerializer
  def self.serialize(c)
    {
      id:            c.id,
      medio:         c.medio,
      monto_ars:     c.monto_ars.to_f,
      pagado:        c.pagado,
      contexto:      c.contexto,
      created_at:    c.created_at,
      registrado_por: c.created_by ? (c.created_by.first_name || c.created_by.email) : nil,
      comprobante_url: (c.comprobante.attached? ? Rails.application.routes.url_helpers.rails_blob_path(c.comprobante, only_path: true) : nil),
    }
  end
end
