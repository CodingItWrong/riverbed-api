# frozen_string_literal: true

User.create!(email: "example@example.com", password: "password")

title = Element.create!(
  name: "Title",
  element_type: :field,
  data_type: :text,
  show_in_summary: true
)
publisher = Element.create!(
  name: "Publisher",
  element_type: :field,
  data_type: :text,
  show_in_summary: false
)
released_at = Element.create!(
  name: "Released At",
  element_type: :field,
  data_type: :date,
  show_in_summary: true,
  read_only: true
)
Element.create!(
  name: "Release",
  element_type: :button,
  show_in_summary: false,
  action: {
    command: "SET_VALUE",
    field: released_at.id.to_s,
    value: "NOW"
  },
  show_condition: {
    query: "IS_EMPTY",
    field: released_at.id.to_s
  }
)
Element.create!(
  name: "Unrelease",
  element_type: :button,
  show_in_summary: false,
  action: {
    command: "SET_VALUE",
    field: released_at.id.to_s,
    value: "EMPTY"
  },
  show_condition: {
    query: "IS_NOT_EMPTY",
    field: released_at.id.to_s
  }
)

Column.create!(name: "Released", card_inclusion_condition: {
  query: "IS_NOT_EMPTY",
  field: released_at.id.to_s
})
Column.create!(name: "Unreleased", card_inclusion_condition: {
  query: "IS_EMPTY",
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
    publisher.id.to_s => "EA"
  })
end
