class AddSuperAdminRole < ActiveRecord::Migration[7.2]
  def change
    # super_admin al enum de roles
    # Rails string enum no necesita migración de columna,
    # pero sí hacer club_id opcional para super_admin
    change_column_null :users, :club_id, true

    # Agregar slug a clubs para generar emails automáticos
    add_column :clubs, :slug, :string
    add_index  :clubs, :slug, unique: true

    # Poblar slugs existentes
    Club.find_each do |club|
      slug = club.name.downcase
                 .gsub(/[áàäâ]/, 'a').gsub(/[éèëê]/, 'e')
                 .gsub(/[íìïî]/, 'i').gsub(/[óòöô]/, 'o')
                 .gsub(/[úùüû]/, 'u').gsub(/ñ/, 'n')
                 .gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
                 .strip
      # Garantizar unicidad
      base = slug
      counter = 1
      while Club.where(slug: slug).where.not(id: club.id).exists?
        slug = "#{base}_#{counter}"
        counter += 1
      end
      club.update_column(:slug, slug)
    end

    change_column_null :clubs, :slug, false
  end
end