namespace :storage do
  desc "Verifica acceso al object storage (servicio :amazon): sube, lee y borra un objeto de prueba sin tocar la app"
  task check: :environment do
    require "active_storage/service"

    raw = YAML.load(ERB.new(File.read(Rails.root.join("config/storage.yml"))).result, aliases: true)
    cfg = raw["amazon"].symbolize_keys

    puts "── Storage check (servicio :amazon) ──────────────────────"
    puts "  Bucket:   #{cfg[:bucket].inspect}"
    puts "  Region:   #{cfg[:region].inspect}"
    puts "  Endpoint: #{cfg[:endpoint] || '(AWS por defecto)'}"
    puts "  Key:      #{cfg[:access_key_id].to_s[0, 6]}…#{cfg[:access_key_id].to_s[-2, 2]}"
    puts ""

    abort "✗ Falta el bucket (AWS_BUCKET / S3_BUCKET)"          if cfg[:bucket].blank?
    abort "✗ Falta access key (AWS_ACCESS_KEY_ID)"               if cfg[:access_key_id].blank?
    abort "✗ Falta secret (AWS_SECRET_ACCESS_KEY)"               if cfg[:secret_access_key].blank?

    service = ActiveStorage::Service::Configurator.build(:amazon, { amazon: cfg })
    key       = "healthcheck/#{SecureRandom.hex(8)}.txt"
    contenido = "cultivo-espacial-storage-check #{Time.now}"

    begin
      print "→ Subiendo objeto de prueba... "
      service.upload(key, StringIO.new(contenido), checksum: Digest::MD5.base64digest(contenido))
      puts "OK"

      print "→ Leyendo de vuelta...         "
      leido = service.download(key)
      raise "el contenido leído no coincide con el subido" unless leido == contenido
      puts "OK"

      print "→ Borrando el de prueba...     "
      service.delete(key)
      puts "OK"

      puts "\n✅ TODO OK — el bucket funciona y las credenciales son válidas."
      puts "   Ya podés setear ACTIVE_STORAGE_SERVICE=amazon en Render con confianza."
    rescue => e
      puts "FALLÓ"
      puts "\n✗ ERROR: #{e.class}: #{e.message}"
      puts "\nPistas según el error:"
      puts "  • AccessDenied            → el token no tiene permiso de escritura sobre el bucket"
      puts "  • NoSuchBucket            → el nombre del bucket está mal o no existe en esa región"
      puts "  • InvalidAccessKeyId      → la access key es incorrecta o fue revocada"
      puts "  • SignatureDoesNotMatch   → la secret key es incorrecta"
      puts "  • cuenta suspendida/billing → la cuenta AWS no está activa: resolver el pago primero"
      exit 1
    end
  end
end
