Feature: Compare a local time or range across timezones
  As someone coordinating across regions
  I want one synchronized timeline shown in several timezones
  So that I can understand the corresponding local clock times and dates

  Scenario: Open with the machine's current time
    Given the menu-bar app is closed
    When I open it at 14:02 in the machine timezone
    Then the fixed first row shows 14:00 in 24-hour format
    And its end time is empty
    And the first row timezone cannot be changed or removed

  Scenario: Select a comparison timezone
    Given the fixed row represents 15 January 2026 at 12:00 UTC
    And an unconfigured comparison row is disabled
    When I select ET in that row
    Then it becomes editable
    And it shows 07:00 for the same instant

  Scenario: Create and clear a time range
    Given the fixed row has only a start time of 09:00
    When I add an end time
    Then every configured row shows a one-hour range
    When I clear the end time from any row
    Then every row returns to single-time mode

  Scenario: A range can cross midnight
    Given a row starts at 23:00
    When I set its end to 01:00
    Then the range ends on the following local day
    And the slider highlights 23:00 to midnight and midnight to 01:00

  Scenario: Dragging either pin uses five-minute increments
    Given a row has a start and end pin
    When I drag either pin along the 24-hour slider
    Then its time snaps to a five-minute increment
    And every configured row updates to the same absolute instant

  Scenario: Equal pins remain independently draggable
    Given the start and end represent the same instant
    When I grab the visibly offset start or end pin
    Then the pin I grabbed moves independently in five-minute increments

  Scenario: A disabled slider is not exposed as adjustable
    Given a comparison row has no timezone selected
    Then its timeline is visually disabled
    And assistive technology does not expose adjustable pin actions for it

  Scenario: Time changes never reflow the interface
    Given several timezone rows and an active range
    When I drag either pin across hour and day boundaries
    Then every endpoint column keeps the same width and position
    And changing day labels and range summaries stays inside reserved space
    And no row height, neighboring control, or scroll position moves

  Scenario: Keep range inputs vertically balanced
    Given a row has both a start and an end time
    Then the Start and End labels share one vertical anchor
    And both time fields and both date labels share matching vertical positions
    And showing the clear-end action does not move the End column downward

  Scenario: Show the live device time independently on every timeline
    Given the selected time differs from the device's current time
    Then every configured row shows a durable current-time strip
    And each strip is positioned at the device time projected into that row's timezone
    When I change the selected start or end time
    Then the current-time strips do not move with the selection
    When the device clock or system timezone changes
    Then the strips update to the new projected current time
    And a strip never blocks dragging a selected-time pin

  Scenario: Reveal the live time on hover
    Given a configured row shows a current-time strip
    When I hover the strip
    Then a compact overlay shows the strip time in that row's timezone
    And the overlay does not resize or move the row
    When I move the pointer away
    Then the overlay disappears
    And the selected-time pin remains draggable through the strip

  Scenario: Keep the local row pinned above exactly two comparison rows
    Given more than two comparison timezone rows exist
    When I scroll the comparison rows
    Then the complete local row remains fixed and fully visible
    And the comparison viewport fits exactly two complete rows with no partial third row
    And scrolling does not move or resize the local row

  Scenario: Name comparison rows without changing viewport capacity
    Given a comparison row is visible
    When I name it "West Coast team"
    Then that name is visible at the top of the row
    And the row keeps its fixed height
    And the comparison viewport still fits exactly two complete rows
    When I change that row's timezone and reopen the app
    Then the name "West Coast team" is restored with the row

  Scenario: Restore rows saved before names were supported
    Given a configured comparison row was saved by an earlier version
    And its stored data has no row name
    When I open the updated app
    Then the timezone selection is preserved
    And the row exposes an empty editable name without a persistence error

  Scenario: Edit from a comparison row
    Given UTC shows 12:00 and ET shows 07:00
    When I change ET to 08:00
    Then UTC shows 13:00
    And every other row updates from that same instant

  Scenario: Compare several timezones
    Given comparison rows exist for ET and UTC+09:00
    When I add GMT
    Then all three comparison rows project the fixed row's time range
    And any comparison row can drive a synchronized edit

  Scenario: Persist row composition without persisting stale clock values
    Given I selected ET and UTC+09:00
    When I close and reopen the app at a later time
    Then those timezone rows are restored in the same order
    And the start is reset to the nearest five-minute current time
    And an active range retains its duration relative to the new start

  Scenario: Handle daylight-saving gaps consistently
    Given PT advances from 01:59 to 03:00
    When I enter a nonexistent time inside the skipped hour
    Then the selection advances to the next valid wall time while preserving smaller components
    And every row still represents one absolute instant

  Scenario: Handle repeated daylight-saving times consistently
    Given PT repeats the hour from 01:00 to 01:59
    When I enter a repeated time
    Then the first occurrence is selected consistently

  Scenario: End edits from the second repeated hour never create negative ranges
    Given the start is the second occurrence of 01:30 during a fall-back transition
    When I set the end to 01:30 or 01:45 on that row
    Then the end is the equal or later occurrence
    And the canonical duration is never negative

  Scenario: Offer a compact generic timezone catalog
    When I open a timezone dropdown
    Then UTC/GMT, PT, MT, CT, and ET are available first
    And neutral UTC offset options follow in numeric order
    And no country or city names appear in the picker

  Scenario: Merge equivalent timezone choices
    Given several timezone names currently have the same UTC offset
    When I open a timezone dropdown
    Then those names are represented by one option for that exact clock time
    And the option remains searchable by every merged alias
    And every neutral fixed offset shows paired values such as "UTC+05:30 • GMT+05:30"
    But a seasonal PT, MT, CT, or ET rule remains distinct from a neutral fixed offset

  Scenario: Keep fixed and seasonal rows coherent across seasonal changes
    Given configured rows exist for a neutral fixed offset and a seasonal US timezone
    When the catalog reference time crosses that offset change
    Then the fixed-offset row keeps its invariant UTC/GMT value
    And the seasonal row updates its UTC offset without becoming blank

  Scenario: Search timezones by words or numbers
    When I type "pacific" or "PT" in the timezone field
    Then the Pacific Time option is offered
    When I type "-8", "UTC-08", "5:30", or "530"
    Then matching UTC offset options are offered without input lag

  Scenario: Search generic timezone options by hidden city names
    Given country and territory capitals and IANA exemplar cities are indexed invisibly
    When I search for "Ottawa", "Brasilia", "Abuja", "Canberra", or "New Delhi"
    Then the generic timezone option representing that city's clock is offered
    And no city or country name appears in the option label
    When I search with Latin diacritic, underscore, space, or legacy spelling variants
    Then the same generic option is offered without duplicate results

  Scenario: Route hidden city names to seasonal rules when they truly match
    Given seasonal PT, MT, CT, and ET options remain distinct from fixed offsets
    When I search for a city whose timezone follows the same transition rules
    Then the matching seasonal option is offered instead of its current fixed offset
    But a city with a different or fixed transition schedule stays on the neutral offset option
    And city aliases move to the correct neutral offset when their own timezone changes season

  Scenario: Launch automatically after login
    Given Timezoner is installed as a signed application
    When it launches for the first time
    Then it requests registration as a macOS login item
    And the app reports when approval is still required in System Settings
    And the menu reports the enforced login-item state without a temporary opt-out
