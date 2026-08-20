require 'rails_helper'

# AC: una tarea de rake que NO necesita la app no puede morir pidiendo las claves de la app.
#
# El backup diario de PRODUCCIÓN estuvo 13 días fallando por esto. `backup:create` está escrita a
# propósito sin depender de `:environment` —sólo necesita `pg_dump` y las credenciales de S3— pero
# el `Rakefile` hace `require_relative "config/application"`, y la verificación de las claves de
# cifrado estaba suelta en el cuerpo de la clase. O sea que se disparaba con CUALQUIER rake.
#
# Y que el backup no tenga las claves es lo correcto, no una concesión: produce un dump con los
# datos cifrados adentro. Darle además las claves sería guardar la caja fuerte y la llave juntas.
#
# La verificación ahora es un `initializer`: se registra al definir la clase, se ejecuta recién en
# `Rails.application.initialize!`. Un rake sin `:environment` nunca llega ahí.
RSpec.describe 'Las claves de cifrado y las tareas de rake' do
  NOMBRE = 'cultivo.verificar_claves_de_cifrado'.freeze

  def initializer_de_claves
    App::Application.initializers.find { |i| i.name.to_s == NOMBRE }
  end

  it 'la verificación es un initializer, no código suelto en el cuerpo de la clase' do
    expect(App::Application.initializers.map { |i| i.name.to_s }).to include(NOMBRE)
  end

  # Si alguna vez alguien la saca del initializer y la deja suelta otra vez, esto lo caza.
  it 'el cuerpo de la clase no verifica las claves al ser requerido' do
    fuente = File.read(Rails.root.join('config/application.rb'))
    cuerpo = fuente[/class Application < Rails::Application(.*?)initializer '#{Regexp.escape(NOMBRE)}'/m, 1].to_s

    expect(cuerpo).not_to include('raise "Falta')
  end

  # El candado sigue puesto donde importa: la app de verdad no arranca sin claves.
  it 'sigue verificando cuando la app arranca' do
    original = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY']
    begin
      ENV.delete('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY')
      expect { initializer_de_claves.run(App::Application) }
        .to raise_error(RuntimeError, /Falta ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY/)
    ensure
      ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] = original
    end
  end

  it 'no se queja cuando las tres están' do
    expect { initializer_de_claves.run(App::Application) }.not_to raise_error
  end
end
