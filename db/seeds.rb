# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

title = Field.create!(name: "Title", data_type: :text, show_in_summary: true)
publisher = Field.create!(name: "Publisher", data_type: :text, show_in_summary: false)
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
  title.id.to_s => "Final Fantasy 7",
  publisher.id.to_s => "Square Enix",
  released_at.id.to_s => "1997-01-31"
})

Card.create!(field_values: {
  title.id.to_s => "Castlevania: Symphony of the Night",
  publisher.id.to_s => "Konami",
  released_at.id.to_s => "1997-03-20"
})

20.times do |i|
  Card.create!(field_values: {
    title.id.to_s => "Game #{i + 1}",
    publisher.id.to_s => "EA",
    released_at.id.to_s => "2025-01-01"
  })
end
