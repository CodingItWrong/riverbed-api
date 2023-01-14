# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

Field.create!(name: "Title", data_type: :text, show_in_summary: true)
Field.create!(name: "Publisher", data_type: :text, show_in_summary: false)
released_at = Field.create!(name: "Released At", data_type: :date, show_in_summary: true)

Column.create!(name: "Released", filter: {
  function: "IS_EMPTY",
  field: released_at.id.to_s
})
Column.create!(name: "Unreleased", filter: {
  function: "IS_NOT_EMPTY",
  field: released_at.id.to_s
})

Card.create!(field_values: {
  "Title" => "Final Fantasy 7",
  "Publisher" => "Square Enix",
  "Released At" => "1997-01-31"
})

Card.create!(field_values: {
  "Title" => "Castlevania: Symphony of the Night",
  "Publisher" => "Konami",
  "Released At" => "1997-03-20"
})

20.times do |i|
  Card.create!(field_values: {
    "Title" => "Game #{i + 1}",
    "Publisher" => "EA",
    "Released At" => "2025-01-01"
  })
end
