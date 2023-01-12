# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

Field.create!(name: "title", show_in_summary: true)
Field.create!(name: "publisher", show_in_summary: false)

Card.create!(field_values: {
  "title" => "Final Fantasy 7",
  "publisher" => "Square Enix"
})

Card.create!(field_values: {
  "title" => "Castlevania: Symphony of the Night",
  "publisher" => "Konami"
})

20.times do |i|
  Card.create!(field_values: {
    "title" => "Movie #{i + 1}",
    "publisher" => "Disney"
  })
end
