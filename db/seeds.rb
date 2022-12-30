# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

Field.create!(name: "title")
Field.create!(name: "publisher")

Card.create!(field_values: {
  "title" => "Final Fantasy 7",
  "publisher" => "Square Enix"
})

Card.create!(field_values: {
  "title" => "Castlevania: Symphony of the Night",
  "publisher" => "Konami"
})
