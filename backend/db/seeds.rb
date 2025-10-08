club = Club.find_or_create_by!(name: "Club Demo")
users = [
  { email: "super@demo.com", role: "super_admin" },
  { email: "admin@demo.com", role: "admin" },
  { email: "medico@demo.com", role: "medico" },
  { email: "cultivador@demo.com", role: "cultivador" }
]
users.each do |u|
  User.find_or_create_by!(email: u[:email]) do |user|
    user.password = "123456"
    user.password_confirmation = "123456"
    user.role = u[:role]
    user.club = club
  end
end
puts "Seed OK"

sala = Sala.find_or_create_by!(name: "Sala Norte", club: Club.first) do |s|
  s.state = "activa"
  s.pots_count = 24
  s.notes = "MVP"
end

Lote.find_or_create_by!(code: "L-001", sala: sala, club: sala.club) do |l|
  l.start_date = Date.today
  l.stage = "vegetativo"
  l.plants_count = 20
  l.strain = "OG Kush"
  l.notes = "Primer lote"
end
