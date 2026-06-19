require 'rails_helper'

# Regresión: spa_fallback debe ser una action PÚBLICA y ruteable. Si queda bajo
# `private` en ApplicationController, Rails tira AbstractController::ActionNotFound
# y la SPA no carga (login, /lotes/:id, etc.).
RSpec.describe 'SPA fallback', type: :request do
  let(:index_path) { Rails.root.join('public', 'index.html') }

  it 'la action spa_fallback es pública (ruteable)' do
    expect(ApplicationController.action_methods).to include('spa_fallback')
  end

  context 'cuando existe public/index.html' do
    around do |example|
      existia = index_path.exist?
      original = index_path.read if existia
      index_path.dirname.mkpath
      index_path.write('<!doctype html><title>SPA OK</title>')
      example.run
      existia ? index_path.write(original) : index_path.delete
    end

    it 'rutea a spa_fallback y responde 200 (sin ActionNotFound)' do
      get '/login', headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:ok)
    end
  end
end
