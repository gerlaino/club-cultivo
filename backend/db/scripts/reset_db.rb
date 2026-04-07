# ============================================================
# RESET DB — Cultivo Espacial Staging
# Correr desde el shell de Render:
#   bundle exec rails runner reset_db.rb
# ============================================================

puts "⚠️  RESET COMPLETO DE LA BASE DE DATOS"
puts "="*55

# Orden importante: respetar foreign keys
modelos = [
  "PlantActivity",
  "Plant",
  "LoteEvento",
  "RegistroAmbiental",
  "CostoLote",
  "Lote",
  "SalaCultivador",
  "Sala",
  "Dispensacion",
  "SocioNota",
  "IndicacionMedica",
  "Socio",
  "MovimientoContable",
  "Tarea",
  "Documento",
  "UserSede",
  "Sede",
  "Genetica",
  "JwtDenylist",
  "User",
  "Club",
]

modelos.each do |nombre|
  begin
    klass = nombre.constantize
    count = klass.unscoped.count
    klass.unscoped.delete_all
    puts "  🗑️  #{nombre}: #{count} registros eliminados"
  rescue => e
    puts "  ⚠️  #{nombre}: #{e.message}"
  end
end

puts ""
puts "✅ Base de datos limpia."
puts "   Ahora corré: bundle exec rails runner seed_staging.rb"