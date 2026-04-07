uts "⚠️  RESET COMPLETO DE LA BASE DE DATOS"
puts "="*55

tablas = %w[
  plant_activities
  plants
  lote_eventos
  registros_ambientales
  costo_lotes
  dispensaciones
  socio_notas
  indicacion_medicas
  socios
  movimientos_contables
  tareas
  documentos
  document_templates
  patient_documents
  user_sedes
  sala_cultivadores
  lotes
  salas
  sedes
  geneticas
  jwt_denylists
  users
  clubs
]

ActiveRecord::Base.connection.execute("TRUNCATE #{tablas.join(', ')} RESTART IDENTITY CASCADE")
puts "✅ Base de datos limpia (TRUNCATE CASCADE)."
puts "   Ahora corré: bundle exec rails runner db/scripts/seed_staging.rb"
