require 'rails_helper'

# La cáscara de la app se pregunta siempre; los assets con hash se guardan un año. Sin esto el
# navegador guardaba `/` por su cuenta y se veía la versión anterior después de un deploy.
RSpec.describe CacheDeLaApp do
  def respuesta(path, status: 200, headers: {})
    app = ->(_env) { [status, Rack::Headers.new.merge!(headers), ['ok']] }
    _, h, = described_class.new(app).call(Rack::MockRequest.env_for(path))
    h
  end

  it 'está en el stack, antes del servidor de archivos estáticos' do
    stack = Rails.application.middleware.map(&:klass)
    expect(stack.index(described_class)).to be < stack.index(ActionDispatch::Static)
  end

  %w[/ /index.html /sw.js /manifest.webmanifest].each do |path|
    it "#{path} se revalida siempre (no-cache)" do
      expect(respuesta(path)['cache-control']).to eq('no-cache')
    end
  end

  it 'los assets con hash se guardan un año' do
    expect(respuesta('/assets/index-BOy4VnMc.js')['cache-control']).to eq('public, max-age=31536000, immutable')
  end

  it 'un asset que no existe (404) no se marca para guardar un año' do
    expect(respuesta('/assets/no-esta.js', status: 404)['cache-control']).to be_nil
  end

  it 'no pisa lo que ya decidió la respuesta (spa_fallback manda no-store)' do
    expect(respuesta('/', headers: { 'cache-control' => 'no-store' })['cache-control']).to eq('no-store')
  end

  it 'la API no se toca' do
    expect(respuesta('/api/me')['cache-control']).to be_nil
  end
end
