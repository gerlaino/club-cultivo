module Bar
  # Siembra las categorías de producto default del salón (Bebidas, Cocina, Merch, Otros) y
  # backfillea los productos del bar: su categoría editable (desde el enum viejo) y su depósito
  # (el Salón). Idempotente: no duplica ni pisa nombres editados por el admin.
  #
  #   Bar::SembrarCategoriasProducto.new(club).call
  class SembrarCategoriasProducto
    def initialize(club)
      @club = club
    end

    def call
      ActsAsTenant.with_tenant(@club) do
        sembrar
        deposito_salon = @club.depositos.find_by(clave_sistema: 'salon')
        backfill(deposito_salon)
      end
      true
    end

    private

    def sembrar
      orden = 0
      CategoriaProducto::DEFAULTS.each do |clave, nombre|
        orden += 1
        c = @club.categorias_producto.with_deleted.find_or_initialize_by(clave_sistema: clave)
        c.restore if c.persisted? && c.deleted?
        c.nombre     = nombre if c.nombre.blank?
        c.es_sistema = true
        c.activo     = true
        c.orden      = orden if c.orden.to_i.zero?
        c.save!
      end
    end

    # Cada producto del bar cae en su categoría editable (según el enum) y en el depósito Salón.
    def backfill(deposito_salon)
      map = @club.categorias_producto.pluck(:clave_sistema, :id).to_h
      @club.bar_productos.find_each do |p|
        attrs = {}
        attrs[:categoria_producto_id] = map[p.categoria] || map['otro'] if p.categoria_producto_id.nil?
        attrs[:deposito_id]           = deposito_salon.id if p.deposito_id.nil? && deposito_salon
        p.update_columns(attrs) if attrs.any?
      end
    end
  end
end
