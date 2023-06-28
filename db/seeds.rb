DEV_API_KEY = "KAhbB18D0QZBFXBCJKE4xJZYyaWkUTK25LWrqNMIXI2-FSqT5NgJpA-ermcllZG3s8mqioWkfZWNlUVwcOIGrw"

user = User.create!(email: "example@example.com", password: "password")
user.api_keys.create!(key: DEV_API_KEY)

def format_date(date) = date.strftime("%Y-%m-%d")

# standard:disable Lint/UselessAssignment
def create_life_log!(user)
  board = user.boards.create!(
    name: "Life Log",
    icon: "map-marker",
    color_theme: "blue"
  )

  location = user.elements.create!(board:,
    display_order: 1,
    element_type: :field,
    data_type: :geolocation,
    name: "Location").id.to_s
  name = user.elements.create!(board:,
    display_order: 2,
    element_type: :field,
    data_type: :text,
    name: "Location Name",
    show_in_summary: true).id.to_s
  user.elements.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :text,
    name: "Event",
    show_in_summary: true)
  check_in_time = user.elements.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :datetime,
    name: "Check-In Time",
    initial_value: "now",
    show_in_summary: true,
    read_only: true,
    element_options: {"show-label-when-read-only": true}).id.to_s

  user.columns.create!(board:,
    name: "This Month",
    card_inclusion_conditions: [{"field" => check_in_time, "query" => "IS_CURRENT_MONTH"}],
    sort_order: {"field" => check_in_time, "direction" => "DESCENDING"})
  user.columns.create!(board:,
    name: "Past Months",
    card_inclusion_conditions: [{"field" => check_in_time, "query" => "IS_NOT_CURRENT_MONTH"}],
    sort_order: {"field" => check_in_time, "direction" => "DESCENDING"})

  user.cards.create!(board:, field_values: {
    name => "Starbucks",
    location => {"lat" => "33.857327", "lng" => "-84.019913"},
    check_in_time => 1.day.ago.iso8601
  })
  user.cards.create!(board:, field_values: {
    name => "Maneul's Tavern",
    location => {"lat" => "33.770800", "lng" => "-84.352730"},
    check_in_time => 1.week.ago.iso8601
  })
  user.cards.create!(board:, field_values: {
    name => "Sheffield, England",
    location => {"lat" => "53.383331", "lng" => "-1.466667"},
    check_in_time => "2022-10-20T00:00:00Z"
  })
  user.cards.create!(board:, field_values: {
    name => "Wrocław, Poland",
    location => {"lat" => "51.107883", "lng" => "17.038538"},
    check_in_time => "2022-09-01T00:00:00Z"
  })
end

def create_links!(user)
  board = user.boards.create!(
    name: "Links",
    icon: "link",
    color_theme: "red"
  )

  title = user.elements.create!(board:,
    display_order: 1,
    element_type: :field,
    data_type: :text,
    name: "Title",
    show_in_summary: true).id.to_s
  url = user.elements.create!(board:,
    display_order: 2,
    element_type: :field,
    data_type: :text,
    name: "URL",
    show_in_summary: true,
    element_options: {
      "link-urls" => true,
      "abbrevieate-urls" => true
    }).id.to_s
  source = user.elements.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :text,
    name: "Source").id.to_s
  notes = user.elements.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :text,
    name: "Notes",
    element_options: {"multiline" => true}).id.to_s
  saved_at = user.elements.create!(board:,
    display_order: 5,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Saved At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  read_at = user.elements.create!(board:,
    display_order: 6,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Read At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  read_status_changed_at = user.elements.create!(board:,
    display_order: 7,
    element_type: :field,
    data_type: :datetime,
    read_only: true,
    name: "Read Status Changed At",
    element_options: {"show-label-when-read-only": true}).id.to_s
  user.elements.create!(board:,
    display_order: 8,
    element_type: :button,
    name: "Mark Read",
    element_options: {"actions" => [
      {"command" => "SET_VALUE", "field" => read_at, "value" => "now"},
      {"command" => "SET_VALUE", "field" => read_status_changed_at, "value" => "now"}
    ]},
    show_conditions: [{"field" => read_at, "query" => "IS_EMPTY"}]).id.to_s
  user.elements.create!(board:,
    display_order: 8,
    element_type: :button,
    name: "Mark Unread",
    element_options: {"actions" => [
      {"command" => "SET_VALUE", "field" => read_at, "value" => "empty"},
      {"command" => "SET_VALUE", "field" => read_status_changed_at, "value" => "now"}
    ]},
    show_conditions: [{"field" => read_at, "query" => "IS_NOT_EMPTY"}]).id.to_s

  user.columns.create!(board:,
    name: "Unread",
    display_order: 1,
    card_inclusion_conditions: [{field: read_at, query: "IS_EMPTY"}],
    sort_order: {field: read_status_changed_at, direction: "DESCENDING"})
  user.columns.create!(board:,
    name: "Read",
    display_order: 2,
    card_inclusion_conditions: [{field: read_at, query: "IS_NOT_EMPTY"}],
    sort_order: {field: read_status_changed_at, direction: "DESCENDING"})

  user.cards.create!(board:, field_values: {
    title => "Apple",
    url => "https://apple.com",
    read_at => format_date(1.year.ago),
    read_status_changed_at => format_date(1.year.ago)
  })
  user.cards.create!(board:, field_values: {
    title => "Arc Browser",
    url => "https://arc.net",
    read_at => format_date(1.month.ago),
    read_status_changed_at => format_date(1.month.ago)
  })
  user.cards.create!(board:, field_values: {
    title => "Expo",
    url => "https://expo.dev",
    read_status_changed_at => format_date(1.day.ago)
  })
  user.cards.create!(board:, field_values: {
    title => "React Native",
    url => "https://reactnative.dev",
    read_status_changed_at => format_date(1.month.ago)
  })
  user.cards.create!(board:, field_values: {
    title => "React Native for Web",
    url => "https://necolas.github.io/react-native-web/",
    read_status_changed_at => format_date(1.week.ago)
  })

  board.update!(board_options: {
    "share" => {
      "url-field" => url,
      "title-field" => title
    }
  })

  board
end

def create_todos!(user)
  board = user.boards.create!(
    name: "To Dos",
    icon: "checkbox",
    color_theme: "green"
  )

  name = user.elements.create!(board:,
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
  time_of_day = user.elements.create!(board:,
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
  defer_until = user.elements.create!(board:,
    display_order: 3,
    element_type: :field,
    data_type: :date,
    name: "Defer Until",
    element_options: {"show-label-when-read-only" => true}).id.to_s
  notes = user.elements.create!(board:,
    display_order: 4,
    element_type: :field,
    data_type: :text,
    name: "Notes",
    element_options: {"multiline" => true}).id.to_s
  completed_at = user.elements.create!(board:,
    display_order: 5,
    element_type: :field,
    data_type: :datetime,
    name: "Completed At",
    read_only: true,
    element_options: {"show-label-when-read-only" => true}).id.to_s
  complete = user.elements.create!(board:,
    display_order: 6,
    element_type: :button,
    name: "Complete",
    element_options: {
      "actions" => [{"command" => "SET_VALUE", "field" => completed_at, "value" => "now"}]
    },
    show_conditions: [{"field" => completed_at, "query" => "IS_EMPTY"}]).id.to_s
  uncomplete = user.elements.create!(board:,
    display_order: 6,
    element_type: :button,
    name: "Uncomplete",
    element_options: {
      "actions" => [{"command" => "SET_VALUE", "field" => completed_at, "value" => "empty"}]
    },
    show_conditions: [{"field" => completed_at, "query" => "IS_NOT_EMPTY"}]).id.to_s
  defer = user.elements.create!(board:,
    display_order: 7,
    element_type: :button_menu,
    name: "Defer",
    element_options: {items: [
      {name: "1 Day", actions: [{
        "command" => "ADD_DAYS",
        "field" => defer_until,
        "specific-value" => "1"
      }]},
      {name: "2 Days", actions: [{
        "command" => "ADD_DAYS",
        "field" => defer_until,
        "specific-value" => "2"
      }]},
      {name: "3 Days", actions: [{
        "command" => "ADD_DAYS",
        "field" => defer_until,
        "specific-value" => "3"
      }]},
      {name: "1 Week", actions: [{
        "command" => "ADD_DAYS",
        "field" => defer_until,
        "specific-value" => "7"
      }]}
    ]},
    show_conditions: [{"field" => completed_at, "query" => "IS_EMPTY"}]).id.to_s

  user.columns.create!(board:,
    name: "Available",
    display_order: 1,
    card_inclusion_conditions: [
      {field: defer_until, query: "IS_NOT_FUTURE"},
      {field: completed_at, query: "IS_EMPTY"}
    ],
    card_grouping: {field: time_of_day, direction: "ASCENDING"},
    sort_order: {field: name, direction: "ASCENDING"},
    summary: {function: "COUNT"})
  user.columns.create!(board:,
    name: "Future",
    display_order: 2,
    card_inclusion_conditions: [
      {field: defer_until, query: "IS_FUTURE"},
      {field: completed_at, query: "IS_EMPTY"}
    ],
    card_grouping: {field: defer_until, direction: "ASCENDING"},
    sort_order: {field: name, direction: "ASCENDING"},
    summary: {function: "COUNT"})
  user.columns.create!(board:,
    name: "Complete",
    display_order: 3,
    card_inclusion_conditions: [{field: completed_at, query: "IS_NOT_EMPTY"}],
    sort_order: {field: name, direction: "ASCENDING"})

  user.cards.create!(board:, field_values: {
    name => "Take in recycling",
    time_of_day => time_day
  })
  user.cards.create!(board:, field_values: {
    name => "Clean office desk",
    time_of_day => time_day
  })
  user.cards.create!(board:, field_values: {
    name => "Put T-ball supplies in car",
    time_of_day => time_evening
  })
  user.cards.create!(board:, field_values: {
    name => "Submit timesheet",
    defer_until => format_date(2.days.from_now)
  })
  user.cards.create!(board:, field_values: {
    name => "Make a budget",
    defer_until => format_date(1.month.from_now)
  })
  user.cards.create!(board:, field_values: {
    name => "Exercise",
    defer_until => format_date(1.month.from_now)
  })
  user.cards.create!(board:, field_values: {
    name => "Build Lego castle",
    completed_at => format_date(1.week.ago)
  })
end
# standard:enable Lint/UselessAssignment

def create_field_samples!(user)
  board = user.boards.create!(name: "Field Samples")

  text_single_line = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text - Single Line",
    show_in_summary: true).id.to_s
  text_multi_line = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text - Multiline",
    show_in_summary: true,
    element_options: {"multiline" => true}).id.to_s
  number = user.elements.create!(board:,
    element_type: :field,
    data_type: :number,
    name: "Number",
    show_in_summary: true).id.to_s
  date = user.elements.create!(board:,
    element_type: :field,
    data_type: :date,
    name: "Date",
    show_in_summary: true).id.to_s
  datetime = user.elements.create!(board:,
    element_type: :field,
    data_type: :datetime,
    name: "Datetime",
    show_in_summary: true).id.to_s
  choice_a = "fake_uuid_11"
  choice = user.elements.create!(board:,
    element_type: :field,
    data_type: :choice,
    name: "Choice",
    show_in_summary: true,
    element_options: {"choices" => [
      {id: choice_a, label: "Choice A"},
      {id: "fake_uuid_12", label: "Choice B"},
      {id: "fake_uuid_13", label: "Choice C"}
    ]}).id.to_s
  geolocation = user.elements.create!(board:,
    element_type: :field,
    data_type: :geolocation,
    name: "Geolocation",
    show_in_summary: true).id.to_s
  user.elements.create!(board:,
    element_type: :button,
    name: "Button")
  user.elements.create!(board:,
    element_type: :button_menu,
    name: "Button Menu",
    element_options: {items: [
      {name: "Option 1", actions: []},
      {name: "Option 2", actions: []}
    ]})
  text_size_1 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 1",
    show_in_summary: true,
    element_options: {"text-size" => 1}).id.to_s
  text_size_2 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 2",
    show_in_summary: true,
    element_options: {"text-size" => 2}).id.to_s
  text_size_3 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 3",
    show_in_summary: true,
    element_options: {"text-size" => 3}).id.to_s
  text_size_4 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 4",
    show_in_summary: true,
    element_options: {"text-size" => 4}).id.to_s
  text_size_5 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 5",
    show_in_summary: true,
    element_options: {"text-size" => 5}).id.to_s
  text_size_6 = user.elements.create!(board:,
    element_type: :field,
    data_type: :text,
    name: "Text Size 6",
    show_in_summary: true,
    element_options: {"text-size" => 6}).id.to_s

  user.columns.create!(board:, name: "All")

  user.cards.create!(board:, field_values: {
    text_single_line => "Short Sample",
    text_multi_line => "This is a significantly longer sample that should wrap to multiple lines on any width",
    number => "39.99",
    date => "2023-01-01",
    datetime => "2023-01-01T12:34:56.000Z",
    choice => choice_a,
    geolocation => {"lat" => "33.857327", "lng" => "-84.019913"},
    text_size_1 => "Text Size 1",
    text_size_2 => "Text Size 2",
    text_size_3 => "Text Size 3",
    text_size_4 => "Text Size 4",
    text_size_5 => "Text Size 5",
    text_size_6 => "Text Size 6"
  })
end

create_life_log!(user)
link_board = create_links!(user)
create_todos!(user)
create_field_samples!(user)

user.update!(ios_share_board: link_board)
