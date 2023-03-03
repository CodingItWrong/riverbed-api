DEV_API_KEY = "KAhbB18D0QZBFXBCJKE4xJZYyaWkUTK25LWrqNMIXI2-FSqT5NgJpA-ermcllZG3s8mqioWkfZWNlUVwcOIGrw"

user = User.create!(email: "example@example.com", password: "password")
user.api_keys.create!(key: DEV_API_KEY)

def format_date(date) = date.strftime("%Y-%m-%d")

# standard:disable Lint/UselessAssignment
def create_life_log!
  board = Board.create!(name: "Life Log")

  location = Element.create!(board:,
    display_order: 1,
    element_type: :field,
    data_type: :geolocation,
    name: "Location").id.to_s
  name = Element.create!(board:,
    display_order: 2,
    element_type: :field,
    data_type: :text,
    name: "Location Name",
    show_in_summary: true).id.to_s
  Element.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :text,
    name: "Event",
    show_in_summary: true)
  check_in_time = Element.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :datetime,
    name: "Check-In Time",
    initial_value: "now",
    show_in_summary: true,
    read_only: true,
    element_options: {"show-label-when-read-only": true}).id.to_s

  Column.create!(board:,
    name: "This Month",
    card_inclusion_conditions: [{"field" => check_in_time, "query" => "IS_CURRENT_MONTH"}],
    sort_order: {"field" => check_in_time, "direction" => "DESCENDING"})
  Column.create!(board:,
    name: "Past Months",
    card_inclusion_conditions: [{"field" => check_in_time, "query" => "IS_NOT_CURRENT_MONTH"}],
    sort_order: {"field" => check_in_time, "direction" => "DESCENDING"})

  Card.create!(board:, field_values: {
    name => "Starbucks",
    location => {"lat" => "33.826020", "lng" => "-84.032250"},
    check_in_time => 1.day.ago.iso8601
  })
  Card.create!(board:, field_values: {
    name => "Maneul's Tavern",
    location => {"lat" => "33.770800", "lng" => "-84.352730"},
    check_in_time => 1.week.ago.iso8601
  })
  Card.create!(board:, field_values: {
    name => "Sheffield, England",
    location => {"lat" => "53.383331", "lng" => "-1.466667"},
    check_in_time => "2022-10-20T00:00:00Z"
  })
  Card.create!(board:, field_values: {
    name => "Wrocław, Poland",
    location => {"lat" => "51.107883", "lng" => "17.038538"},
    check_in_time => "2022-09-01T00:00:00Z"
  })
end

def create_links!
  board = Board.create!(name: "Links")

  title = Element.create!(board:,
    display_order: 1,
    element_type: :field,
    data_type: :text,
    name: "Title",
    show_in_summary: true).id.to_s
  url = Element.create!(board:,
    display_order: 2,
    element_type: :field,
    data_type: :text,
    name: "URL",
    show_in_summary: true).id.to_s
  source = Element.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :text,
    name: "Source").id.to_s
  notes = Element.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :text,
    name: "Notes",
    element_options: {"multiline" => true}).id.to_s
  saved_at = Element.create!(board:,
    display_order: 5,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Saved At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  read_at = Element.create!(board:,
    display_order: 6,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Read At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  read_status_changed_at = Element.create!(board:,
    display_order: 7,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Read Status Changed At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  Element.create!(board:,
    display_order: 8,
    element_type: :button,
    name: "Mark Read",
    element_options: {"actions" => [
      {"command" => "SET_VALUE", "field" => read_at, "value" => "now"},
      {"command" => "SET_VALUE", "field" => read_status_changed_at, "value" => "now"}
    ]},
    show_condition: {"field" => read_at, "query" => "IS_EMPTY"}).id.to_s
  Element.create!(board:,
    display_order: 8,
    element_type: :button,
    name: "Mark Unread",
    element_options: {"actions" => [
      {"command" => "SET_VALUE", "field" => read_at, "value" => "empty"},
      {"command" => "SET_VALUE", "field" => read_status_changed_at, "value" => "now"}
    ]},
    show_condition: {"field" => read_at, "query" => "IS_NOT_EMPTY"}).id.to_s

  Column.create!(board:,
    name: "Unread",
    display_order: 1,
    card_inclusion_conditions: [{field: read_at, query: "IS_EMPTY"}],
    sort_order: {field: read_status_changed_at, direction: "DESCENDING"})
  Column.create!(board:,
    name: "Read",
    display_order: 2,
    card_inclusion_conditions: [{field: read_at, query: "IS_NOT_EMPTY"}],
    sort_order: {field: read_status_changed_at, direction: "DESCENDING"})

  Card.create!(board:, field_values: {
    title => "Apple",
    url => "https://apple.com",
    read_at => format_date(1.year.ago),
    read_status_changed_at => format_date(1.year.ago)
  })
  Card.create!(board:, field_values: {
    title => "Arc Browser",
    url => "https://arc.net",
    read_at => format_date(1.month.ago),
    read_status_changed_at => format_date(1.month.ago)
  })
  Card.create!(board:, field_values: {
    title => "Expo",
    url => "https://expo.dev",
    read_status_changed_at => format_date(1.day.ago)
  })
  Card.create!(board:, field_values: {
    title => "React Native",
    url => "https://reactnative.dev",
    read_status_changed_at => format_date(1.month.ago)
  })
  Card.create!(board:, field_values: {
    title => "React Native for Web",
    url => "https://necolas.github.io/react-native-web/",
    read_status_changed_at => format_date(1.week.ago)
  })
end

def create_todos!
  board = Board.create!(name: "To Dos")

  name = Element.create!(board:,
    display_order: 1,
    element_type: :field,
    data_type: :text,
    name: "Name",
    show_in_summary: true,
    element_options: {"multiline" => true}).id.to_s
  time_morning = "fake_uuid_1"
  time_day = "fake_uuid_2"
  time_evening = "fake_uuid_3"
  time_after_kids_in_bed = "fake_uuid_4"
  time_of_day = Element.create!(board:,
    display_order: 2,
    element_type: :field,
    data_type: :choice,
    name: "Time of Day",
    element_options: {"choices" => [
      {id: time_morning, label: "Morning"},
      {id: time_day, label: "Day"},
      {id: time_evening, label: "Evening"},
      {id: time_after_kids_in_bed, label: "After Kids in Bed"}
    ]}).id.to_s
  defer_until = Element.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :date,
    name: "Defer Until",
    element_options: {"show-label-when-read-only" => true}).id.to_s
  notes = Element.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :text,
    name: "Notes",
    element_options: {"multiline" => true}).id.to_s
  completed_at = Element.create!(board:,
    display_order: 5,
    element_type: :field,
    data_type: :datetime,
    name: "Completed At",
    element_options: {"show-label-when-read-only" => true}).id.to_s
  complete = Element.create!(board:,
    display_order: 6,
    element_type: :button,
    name: "Uncomplete",
    element_options: {
      "actions" => [{"command" => "SET_VALUE", "field" => completed_at, "value" => "now"}]
    },
    show_condition: {"field" => completed_at, "query" => "IS_EMPTY"}).id.to_s
  uncomplete = Element.create!(board:,
    display_order: 6,
    element_type: :button,
    name: "Complete",
    element_options: {
      "actions" => [{"command" => "SET_VALUE", "field" => completed_at, "value" => "empty"}]
    },
    show_condition: {"field" => completed_at, "query" => "IS_NOT_EMPTY"}).id.to_s
  defer = Element.create!(board:,
    display_order: 7,
    element_type: :button_menu,
    name: "Defer",
    element_options: {items: [
      {name: "1 Day", action: {command: "ADD_DAYS", field: defer_until, value: "1"}},
      {name: "2 Days", action: {command: "ADD_DAYS", field: defer_until, value: "2"}},
      {name: "3 Days", action: {command: "ADD_DAYS", field: defer_until, value: "3"}},
      {name: "1 Week", action: {command: "ADD_DAYS", field: defer_until, value: "7"}}
    ]},
    show_condition: {"field" => completed_at, "query" => "IS_NOT_EMPTY"}).id.to_s

  Column.create!(board:,
    name: "Available",
    display_order: 1,
    card_inclusion_conditions: [
      {field: defer_until, query: "IS_NOT_FUTURE"},
      {field: completed_at, query: "IS_EMPTY"}
    ],
    card_grouping: {field: time_of_day, direction: "ASCENDING"},
    sort_order: {field: name, direction: "ASCENDING"},
    summary: {function: "COUNT"})
  Column.create!(board:,
    name: "Future",
    display_order: 2,
    card_inclusion_conditions: [
      {field: defer_until, query: "IS_FUTURE"},
      {field: completed_at, query: "IS_EMPTY"}
    ],
    card_grouping: {field: defer_until, direction: "ASCENDING"},
    sort_order: {field: name, direction: "ASCENDING"},
    summary: {function: "COUNT"})
  Column.create!(board:,
    name: "Complete",
    display_order: 3,
    card_inclusion_conditions: [{field: completed_at, query: "IS_NOT_EMPTY"}],
    sort_order: {field: name, direction: "ASCENDING"})

  Card.create!(board:, field_values: {
    name => "Take in recycling",
    time_of_day => time_day
  })
  Card.create!(board:, field_values: {
    name => "Clean office desk",
    time_of_day => time_day
  })
  Card.create!(board:, field_values: {
    name => "Put T-ball supplies in car",
    time_of_day => time_evening
  })
  Card.create!(board:, field_values: {
    name => "Submit timesheet",
    defer_until => format_date(2.days.from_now)
  })
  Card.create!(board:, field_values: {
    name => "Make a budget",
    defer_until => format_date(1.month.from_now)
  })
  Card.create!(board:, field_values: {
    name => "Exercise",
    defer_until => format_date(1.month.from_now)
  })
  Card.create!(board:, field_values: {
    name => "Build Lego castle",
    completed_at => format_date(1.week.ago)
  })
end
# standard:enable Lint/UselessAssignment

create_life_log!
create_links!
create_todos!
