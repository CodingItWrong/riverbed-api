# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

Field.create!(name: "Title", data_type: :text, show_in_summary: true)
Field.create!(name: "Publisher", data_type: :text, show_in_summary: false)
Field.create!(name: "Released At", data_type: :datetime, show_in_summary: false)

Card.create!(field_values: {
  "Title" => "Final Fantasy 7",
  "Publisher" => "Square Enix",
  "Released At" => "1997-01-31".in_time_zone
})

Card.create!(field_values: {
  "Title" => "Castlevania: Symphony of the Night",
  "Publisher" => "Konami",
  "Released At" => "1997-03-20".in_time_zone
})

20.times do |i|
  Card.create!(field_values: {
    "Title" => "Game #{i + 1}",
    "Publisher" => "EA",
    "Released At" => Time.zone.now + 1.year
  })
end
