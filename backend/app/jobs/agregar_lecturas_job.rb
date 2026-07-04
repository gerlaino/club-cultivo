class AgregarLecturasJob < ApplicationJob
  queue_as :ambiente

  def perform(sala_id, tipo, lecturas_attrs)
    sala = Sala.find(sala_id)
    ActsAsTenant.with_tenant(sala.club) do
      lecturas_attrs.each do |attrs|
        LecturaAmbiental.find_or_initialize_by(
          sala_id:   sala.id,
          tipo:      attrs['tipo'] || tipo,
          medido_at: Time.zone.parse(attrs['medido_at'].to_s)
        ).tap do |l|
          l.assign_attributes(
            club_id: sala.club_id,
            valor:   attrs['valor'],
            unidad:  AmbienteTipos::TIPOS_CANONICOS[attrs['tipo'] || tipo],
            fuente:  attrs['fuente'] || 'manual'
          )
          l.save!
        end
      end
      EvaluarReglasJob.perform_later(sala_id)
    end
  end
end
