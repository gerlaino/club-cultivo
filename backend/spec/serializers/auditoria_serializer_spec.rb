require 'rails_helper'

# Cómo se LEE una fila del rastro. Nace de tres cosas que la pantalla mostraba mal y que eran la
# misma causa: la fila describía la operación de la base en vez del hecho.
RSpec.describe AuditoriaSerializer do
  let(:club) { create(:club) }

  def auditoria(cambios, accion: 'actualizar', tipo: 'Dispensacion')
    ActsAsTenant.with_tenant(club) do
      Auditoria.create!(auditable_type: tipo, auditable_id: 580, club: club,
                        accion: accion, cambios: cambios)
    end
  end

  def serializar(...) = described_class.serialize(auditoria(...))

  describe 'nombra el hecho, no la operación de la base' do
    it 'marcar entregado se dice "Entregó", no "Editó"' do
      r = serializar({ 'estado_envio' => %w[en_viaje entregado],
                       'entregado_at' => [nil, '2026-09-09T15:49:50.752-03:00'] })

      expect(r[:accion_label]).to eq('Entregó')
      expect(r[:accion_tono]).to eq('ok')
    end

    it 'reportar un fallo se dice "No pudo entregar"' do
      r = serializar({ 'estado_envio' => %w[en_viaje fallido], 'motivo_fallo' => [nil, 'no habia nadie'] })

      expect(r[:accion_label]).to eq('No pudo entregar')
      expect(r[:accion_tono]).to eq('alerta')
    end

    it 'una edición sin regla que aplique sigue siendo "Editó"' do
      expect(serializar({ 'observaciones' => [nil, 'algo'] })[:accion_label]).to eq('Editó')
    end

    it 'un alta se dice "Creó" y no muestra antes→después' do
      r = serializar({ 'cantidad' => '10.0' }, accion: 'crear')

      expect(r[:accion_label]).to eq('Creó')
      expect(r[:cambios]).to be_empty
    end
  end

  describe 'los campos que COMPONEN la acción no se repiten en el detalle' do
    it 'una entrega no vuelve a decir estado_envio ni entregado_at' do
      r = serializar({ 'estado_envio' => %w[en_viaje entregado],
                       'entregado_at' => [nil, '2026-09-09T15:49:50.752-03:00'] })

      expect(r[:cambios]).to be_empty
    end

    it 'pero el motivo del fallo SÍ se muestra: es el dato, no la acción' do
      r = serializar({ 'estado_envio' => %w[en_viaje fallido],
                       'fallido_at'   => [nil, '2026-08-08T00:05:49.340-03:00'],
                       'motivo_fallo' => [nil, 'no habia nadie'] })

      expect(r[:cambios].map { |c| c[:campo] }).to eq(['motivo del fallo'])
      expect(r[:cambios].first[:a]).to eq('no habia nadie')
    end
  end

  describe 'no muestra ruido' do
    it 'un jsonb nunca sale como [object Object]' do
      r = serializar({ 'historial_envio' => [[{ 'evento' => 'en_viaje' }],
                                             [{ 'evento' => 'en_viaje' }, { 'evento' => 'entregado' }]] })

      expect(r[:cambios]).to be_empty
      expect(r.to_json).not_to include('object Object')
    end

    it 'nil → "" no es un cambio para nadie que lo lea' do
      expect(serializar({ 'notas_entrega' => [nil, ''] })[:cambios]).to be_empty
    end

    it 'los internos (id, timestamps, club) no se muestran' do
      r = serializar({ 'id' => [nil, 5], 'club_id' => [nil, 1], 'updated_at' => [nil, '2026-09-09'],
                       'observaciones' => [nil, 'visible'] })

      expect(r[:cambios].map { |c| c[:campo] }).to eq(['observaciones'])
    end
  end

  describe 'la firma es un HECHO, no un antes→después' do
    it 'se anuncia como nota y su base64 no aparece por ningún lado' do
      base64 = "data:image/png;base64,#{'iVBORw0KGgo' * 400}"
      r = serializar({ 'estado_envio' => %w[en_viaje entregado], 'firma_entrega_data' => [nil, base64] })

      expect(r[:notas]).to eq(['Firma capturada'])
      expect(r[:cambios]).to be_empty
      expect(r.to_json).not_to include('iVBORw0KGgo')
    end

    it 'sin firma no inventa la nota' do
      expect(serializar({ 'observaciones' => [nil, 'x'] })[:notas]).to be_empty
    end
  end

  describe 'valores legibles' do
    it 'los decimales del jsonb (que viajan como string) se leen como números' do
      r = serializar({ 'aporte_socio_ars' => ['150000.0', '212500.0'], 'cantidad' => ['10.0', '12.5'] })
      por_campo = r[:cambios].to_h { |c| [c[:campo], [c[:de], c[:a]]] }

      expect(por_campo['aporte']).to eq(['$150.000', '$212.500'])
      expect(por_campo['cantidad']).to eq(%w[10 12,5])
    end

    it 'una fecha ISO no se muestra cruda' do
      r = serializar({ 'fecha_dispensacion' => %w[2026-09-01 2026-09-02] })

      expect(r[:cambios].first[:a]).to eq('2 sep 2026')
    end

    it 'los enums y los booleanos se dicen en castellano' do
      r = serializar({ 'medio_pago' => %w[efectivo cuenta_corriente], 'es_regalo' => [false, true] })
      por_campo = r[:cambios].to_h { |c| [c[:campo], [c[:de], c[:a]]] }

      expect(por_campo['medio de pago']).to eq(['efectivo', 'cuenta corriente'])
      expect(por_campo['regalo']).to eq(%w[No Sí])
    end
  end
end
