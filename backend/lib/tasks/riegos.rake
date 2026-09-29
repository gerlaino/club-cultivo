namespace :riegos do
  # El volumen de agua de los riegos viejos, del texto al número (`volumen_l`, 29-sep-2026).
  # Ver `Riegos::VolumenDesdeTexto`: lee sólo el texto que la app escribía («Riego: 20L», «… L en
  # toda la cama»); un riego de sala es el TOTAL y se reparte entre sus lotes.
  #
  #   rake riegos:volumen_desde_texto              # cuenta qué cambiaría, NO escribe
  #   rake riegos:volumen_desde_texto CONFIRMAR=1  # escribe
  #   CLUB_ID=3 rake riegos:volumen_desde_texto    # un solo club
  #
  # Idempotente: no toca un registro que ya tiene volumen.
  desc 'Pasa el volumen de riego del texto a volumen_l (los riegos de sala se reparten)'
  task volumen_desde_texto: :environment do
    confirmar = ENV['CONFIRMAR'].present?
    ActsAsTenant.without_tenant do
      scope = RegistroAmbiental.all
      scope = scope.where(club_id: ENV['CLUB_ID']) if ENV['CLUB_ID'].present?
      res = Riegos::VolumenDesdeTexto.new(scope: scope, confirmar: confirmar).call
      puts "#{res.riegos} riegos con volumen en el texto (#{res.compartidos} de sala o cama, repartidos), #{res.registros} registros."
      puts confirmar ? '✓ Escrito.' : 'No se escribió nada: correlo con CONFIRMAR=1.'
    end
  end
end
