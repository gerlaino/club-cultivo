require 'rails_helper'

# AC (Germán, 13-oct-2026): «registré por voz vege… no me tomó el vege del depósito, no hizo el
# cálculo para descontar lo usado… un pulso a cada planta, tenés que poder calcular». Y: «al crear
# el registro por voz, para no pedir cantidades, ya sabemos que toma las recomendadas por el
# nutriente». Y: «decir aplique receta xxx y que se use la receta guardada que matchea».
RSpec.describe Nutricion::DesdeDictado do
  let(:club)  { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: Date.new(2026, 9, 1)) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  before { 3.times { create(:plant, lote: lote, state: 'vegetativo') } }

  def nutriente(nombre, **attrs)
    club.insumos.create!(nombre: nombre, unidad_medida: 'mililitro', sede: sede, tipo: 'cultivo', **attrs)
  end

  def proponer(datos, lotes: [lote]) = described_class.call(club: club, lotes: lotes, sala: sala, datos: datos)

  it 'nada de nutrientes ni receta: no hay propuesta' do
    expect(proponer({ 'tareas_realizadas' => ['riego'] })).to be_nil
  end

  it '«un pulso a cada planta»: calcula con la medida casera y las plantas en cultivo' do
    vege = nutriente('Vege', medida_casera: 'pulso', medida_casera_cantidad: 2)
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'vege', 'cantidad' => 1, 'medida' => 'medida', 'por' => 'planta' }] })

    item = p['items'].first
    expect(item).to include('insumo_id' => vege.id, 'cantidad' => 6.0, 'detalle' => '1 pulso × 3 plantas', 'origen' => 'dicho')
    expect(p['avisos']).to be_empty
  end

  it 'sin cantidad dicha usa la dosis de la ETIQUETA para la fase de las plantas' do
    vege = nutriente('Vege', dosis_unidad: 'ml_litro', dosis_vegetativo: 2, dosis_floracion: 4)
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Vege' }], 'volumen_l' => 3 })

    expect(p['items'].first).to include('insumo_id' => vege.id, 'cantidad' => 6.0, 'origen' => 'etiqueta')
  end

  it 'sin cantidad ni etiqueta, la línea va vacía y dice que no se descuenta (no la pide: el riego se guarda igual)' do
    nutriente('Vege')
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Vege' }] })

    expect(p['items'].first['cantidad']).to be_nil
    expect(p['avisos'].first).to include('Vege no se descuenta', 'no tiene cargada la dosis de la etiqueta')
  end

  # AC (Germán, 14-oct-2026): «pongo que regué con vege y me pide ingresar a mano todo eso».
  it '«un pulso» de un nutriente sin la medida casera cargada: no adivina los ml y lo dice con la palabra dicha' do
    nutriente('Vege')
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Vege', 'cantidad' => 1, 'medida' => 'medida', 'medida_nombre' => 'pulso', 'por' => 'planta' }] })

    expect(p['items'].first['cantidad']).to be_nil
    expect(p['avisos']).to eq(['Vege no se descuenta: falta cargar cuánto es 1 pulso (en Nutrientes).'])
  end

  it 'el texto de lo dicho, para el registro' do
    datos = { 'nutrientes' => [{ 'nombre' => 'Vege', 'cantidad' => 1, 'medida' => 'medida', 'medida_nombre' => 'pulso', 'por' => 'planta' },
                               { 'nombre' => 'Base A', 'cantidad' => 2.5, 'medida' => 'ml', 'por' => 'litro' },
                               { 'nombre' => 'Enzimas' }] }
    expect(described_class.texto_dicho(datos)).to eq('Vege: 1 pulso por planta · Base A: 2,5 ml por litro · Enzimas')
  end

  it 'por litro sin litros dichos no adivina: lo dice' do
    nutriente('Vege', dosis_unidad: 'ml_litro', dosis_vegetativo: 2)
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Vege' }] })
    expect(p['avisos'].first).to include('no dijiste cuántos litros')
  end

  it '«la receta Floración» usa la receta guardada que coincide' do
    vege = nutriente('Vege')
    receta = club.recetas.create!(nombre: 'Floración', uso: 'riego',
                                  receta_items_attributes: [{ insumo_id: vege.id, dosis: 2, unidad: 'ml_l' }])
    p = proponer({ 'receta_nombre' => 'floracion', 'volumen_l' => 5 })
    expect(p).to include('modo' => 'receta', 'receta_id' => receta.id, 'base' => 5.0)
  end

  it 'un nombre que no existe o que puede ser dos, no se adivina' do
    nutriente('Base A'); nutriente('Base B')
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Kawsay', 'cantidad' => 1, 'medida' => 'ml' }, { 'nombre' => 'Base', 'cantidad' => 1, 'medida' => 'ml' }] })
    expect(p['items']).to be_empty
    expect(p['avisos'].join).to include('No encontré «Kawsay»')
    expect(p['avisos'].join).to include('Base A o Base B')
  end

  it 'no toma nutrientes de otra organización' do
    otra = create(:club)
    ActsAsTenant.with_tenant(otra) { otra.insumos.create!(nombre: 'Vege', unidad_medida: 'mililitro', tipo: 'cultivo') }
    p = proponer({ 'nutrientes' => [{ 'nombre' => 'Vege', 'cantidad' => 1, 'medida' => 'ml' }] })
    expect(p['items']).to be_empty
  end

  describe '.para_aplicar (lo confirmado)' do
    it 'con receta, abre la receta entera y pisa sólo lo que se cambió' do
      a = nutriente('Base A'); b = nutriente('Base B')
      receta = club.recetas.create!(nombre: 'Vege', uso: 'riego', receta_items_attributes: [
        { insumo_id: a.id, dosis: 2, unidad: 'ml_l' }, { insumo_id: b.id, dosis: 1, unidad: 'ml_l' }])
      plan = described_class.para_aplicar(club: club, sala: sala, nutricion: {
        'modo' => 'receta', 'receta_id' => receta.id, 'base' => 4, 'items' => [{ 'insumo_id' => b.id, 'cantidad' => 10 }] })

      expect(plan[:items].map { |i| [i[:insumo_id], i[:cantidad].to_f] }).to contain_exactly([a.id, 8.0], [b.id, 10.0])
    end

    it 'descarta insumos de otra organización y líneas sin cantidad' do
      vege = nutriente('Vege')
      otra = create(:club)
      ajeno = ActsAsTenant.with_tenant(otra) { otra.insumos.create!(nombre: 'X', unidad_medida: 'mililitro', tipo: 'cultivo') }
      plan = ActsAsTenant.without_tenant do
        described_class.para_aplicar(club: club, sala: sala, nutricion: { 'modo' => 'sueltos', 'items' => [
          { 'insumo_id' => vege.id, 'cantidad' => 5 }, { 'insumo_id' => ajeno.id, 'cantidad' => 5 }, { 'insumo_id' => vege.id, 'cantidad' => nil }] })
      end
      expect(plan[:items].map { |i| i[:insumo_id] }).to eq([vege.id])
    end

    it '«nada del depósito» no aplica nada' do
      expect(described_class.para_aplicar(club: club, nutricion: { 'modo' => 'ninguno' })).to be_nil
    end
  end
end
