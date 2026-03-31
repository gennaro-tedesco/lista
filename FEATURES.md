# IMPLEMENTATION_PLAN.md

## Feature

Implement the core UX/UI for creating and managing a shopping list in the Flutter app.

The feature must work on both iOS and Android with a shared Flutter codebase.

______________________________________________________________________

## Goal

Users must be able to:

- create a new shopping list
- assign a date to the list
- optionally add a title
- add food items through typed input
- receive autocomplete suggestions while typing
- select suggestions or ignore/dismiss them
- see added items in the list
- check and uncheck items as purchased

______________________________________________________________________

## UX principles

- Keep the flow extremely simple
- Use standard mobile patterns familiar on both iOS and Android
- Prioritize touch ergonomics and clarity
- Avoid clutter
- Make “create new list” obvious at first glance
- Keep autocomplete helpful but non-blocking
- Let users type freely even if they do not select a suggestion

______________________________________________________________________

## High-level flow

1. User lands on the main shopping-lists screen
1. User taps a prominent “new list” button
1. App navigates to a list creation screen
1. User selects a date
1. User optionally enters a title
1. User types items into an item input field
1. App shows autocomplete suggestions in a dismissible dropdown
1. User adds item
1. Added item appears in the list with a checkmark
1. User can toggle the checkmark on/off

______________________________________________________________________

## Screens

### 1. Shopping Lists Home Screen

Purpose:

- show existing shopping lists
- provide entry point to create a new one

Requirements:

- add a floating action button or prominent primary button for creating a new list
- button must include:
  - a generic list/shopping-related icon
  - a `+`
- button should clearly communicate “create new list”

Recommended pattern:

- use a `FloatingActionButton.extended` or a bottom-aligned primary action button
- label example: `New List`

Recommended icon approach:

- temporary icon can be any standard Flutter icon such as:
  - `Icons.add`
  - `Icons.playlist_add`
  - `Icons.shopping_cart`
  - `Icons.note_add`

Preferred option:

- `Icons.playlist_add` plus visible text label

______________________________________________________________________

### 2. List Creation / Editing Screen

Purpose:

- let user define list metadata and list items

Layout order from top to bottom:

1. date selector
1. optional title field
1. item input field
1. autocomplete dropdown under the input
1. current list items below

This screen should scroll safely on small mobile screens.

______________________________________________________________________

## Detailed implementation plan

### Step 1: Add the “New List” entry point

Implement:

- a button on the main screen that navigates to the new-list screen

Requirements:

- icon + plus indication
- visually obvious primary action
- touch-friendly size

Suggested UI:

- `FloatingActionButton.extended`
- icon: `Icons.playlist_add`
- label: `New List`

Acceptance:

- user can clearly understand how to create a new list
- tapping button navigates to the list creation screen

______________________________________________________________________

### Step 2: Create the list creation screen

Implement a dedicated screen, for example:

- `CreateListPage`
- or `ShoppingListEditorPage`

Screen responsibilities:

- hold local state for:
  - selected date
  - optional title
  - current typed item
  - current item suggestions
  - current list items

Acceptance:

- screen opens from the home page
- screen is usable on both iOS and Android

______________________________________________________________________

### Step 3: Add date selector at the top

Requirement:

- date is the primary metadata of the list

UX:

- place date selector at the top
- show currently selected date in a visible field/button
- tapping it opens platform-appropriate date picker

Recommended Flutter pattern:

- a read-only row/button/chip that triggers `showDatePicker`
- default date should be today

Suggested UI copy:

- `Date`
- formatted selected date visible next to it

Acceptance:

- user can open date picker
- user can set the list date
- selected date is displayed clearly

______________________________________________________________________

### Step 4: Add optional title input

Requirement:

- field may be left blank

UX:

- place directly below date selector
- do not make it visually heavier than the date
- placeholder should make optionality clear

Suggested hint text:

- `List title (optional)`

Acceptance:

- user can type a title
- empty title is allowed
- no validation error on blank title

______________________________________________________________________

### Step 5: Add item input mechanism

Requirement:

- user must be able to enter list items

UX:

- place a single prominent input below date/title
- pair it with a clear add action

Recommended pattern:

- text field + add button on the same row
- pressing enter/submit should also add the item

Suggested hint text:

- `Add an item`
- or `Type a food item`

Acceptance:

- user can type text
- user can add item via button
- user can add item via keyboard submit action

______________________________________________________________________

### Step 6: Implement autocomplete for food items

Requirement:

- suggest common food items while typing
- think of a good solution rather than hardcoding only a few values

Recommended approach for MVP:

- use a local curated dataset in Dart
- each entry should contain:
  - canonical item name
  - optional synonyms
  - emoji
- perform lightweight prefix and substring matching

Reason:

- simple
- deterministic
- fast
- offline
- no backend needed
- adequate for MVP

Suggested data model:

- `FoodSuggestion { name, emoji, aliases }`

Example entries:

- eggs → 🥚
- bread → 🍞
- milk → 🥛
- apples → 🍎
- bananas → 🍌
- tomatoes → 🍅
- cheese → 🧀
- chicken → 🍗
- fish → 🐟
- rice → 🍚
- pasta → 🍝
- carrots → 🥕
- broccoli → 🥦
- lettuce → 🥬

Matching strategy:

1. exact prefix on name
1. prefix on aliases
1. substring fallback
1. cap visible suggestions, e.g. 5–8 items

Do not:

- block free typing
- force selection from suggestions

Acceptance:

- typing `br` suggests `🍞 Bread`
- typing `egg` suggests `🥚 Eggs`
- user may still type a custom item not in dataset

______________________________________________________________________

### Step 7: Show autocomplete as dismissible dropdown

Requirement:

- dropdown must appear under the input
- user must be able to dismiss it and continue typing

Recommended pattern:

- anchored suggestion panel below text field
- suggestions displayed as tappable rows
- tapping outside or pressing escape/back should dismiss
- continuing to type without selection must remain possible

Suggested interaction behavior:

- dropdown opens when there is input and matching suggestions
- dropdown closes when:
  - user selects a suggestion
  - user taps outside
  - user clears text
  - user explicitly dismisses it
- typing must continue even with dropdown visible

Implementation options:

- simple custom overlay
- or a widget pattern similar to `RawAutocomplete`
- prefer whichever gives best control over:
  - dropdown appearance
  - dismissal
  - emoji rendering
  - custom row layout

Acceptance:

- dropdown appears below input
- dropdown can be dismissed
- user can ignore suggestions and keep typing custom text

______________________________________________________________________

### Step 8: Add emoji to common food suggestions

Requirement:

- autocomplete should show emojis for common foods

UX:

- emoji should be shown before item name
- keep layout clean and aligned
- do not overuse decoration beyond the emoji itself

Example:

- `🥚 Eggs`
- `🍞 Bread`
- `🥛 Milk`

Acceptance:

- suggestions visually include emoji where available
- emoji improves scanability without clutter

______________________________________________________________________

### Step 9: Add typed item into the current list

Requirement:

- once item is added, it appears in the list

Behavior:

- trim whitespace
- ignore empty strings
- preserve user text if custom item
- clear input after successful add
- close suggestions after add

Suggested item model:

- `ShoppingListItem`
  - `id`
  - `name`
  - `emoji` optional
  - `isChecked`

If user adds from suggestion:

- populate both name and emoji

If user adds custom text:

- emoji may be null

Acceptance:

- item appears immediately after adding
- input resets for next item
- no empty items are added

______________________________________________________________________

### Step 10: Add checkable/uncheckable state

Requirement:

- each item must display a checkmark that user can toggle

Recommended UI:

- checklist row
- leading checkbox or trailing checkbox
- item text in the center/expanded
- optional emoji before the text

Behavior:

- tapping checkbox toggles checked state
- tapping item row may also toggle for easier UX
- checked items may appear visually muted or struck through, but keep readability

Acceptance:

- user can check and uncheck any item
- state updates immediately in UI

______________________________________________________________________

## Recommended data structures

### Shopping list

Suggested fields:

- `id`
- `date`
- `title`
- `items`

### Shopping list item

Suggested fields:

- `id`
- `name`
- `emoji` optional
- `isChecked`

### Food suggestion

Suggested fields:

- `name`
- `emoji` optional
- `aliases`

______________________________________________________________________

## Recommended widget structure

Suggested organization:

- `ShoppingListsHomePage`
- `CreateListPage`
- `DateSelectorField`
- `OptionalTitleField`
- `AddItemInput`
- `AutocompleteDropdown`
- `ShoppingListItemsView`
- `ShoppingListItemTile`

Keep business logic out of widgets when possible.

______________________________________________________________________

## State management

For MVP:

- keep state local to the screen if possible
- simple `StatefulWidget` is acceptable
- alternatively a lightweight notifier approach is acceptable if already used in the project

Do not overengineer state management for this feature.

______________________________________________________________________

## UI recommendations

### Home screen

- clean list of existing shopping lists
- prominent primary action to create a new one

### Create list screen

- top padding and clear spacing
- date selector visually first
- optional title next
- item entry prominent
- autocomplete directly below field
- item list fills remaining space

### Visual treatment

- use standard Material components
- keep controls large enough for touch
- preserve platform compatibility
- use consistent spacing

______________________________________________________________________

## Edge cases

Handle:

- empty item input
- title left blank
- no autocomplete suggestions
- custom item not in suggestion dataset
- duplicate items allowed or disallowed: choose one rule and apply consistently
- long item names
- dismissing dropdown while keeping current input

Recommended MVP behavior:

- allow duplicates for now unless product says otherwise

______________________________________________________________________

## Persistence

For this feature scope:

- screen-level behavior is sufficient first
- if persistence is already planned, abstract data model cleanly so storage can be added later

Do not couple UI directly to a backend.

______________________________________________________________________

## Accessibility

- buttons must have clear tap targets
- labels and hints should be understandable
- checkbox state should be obvious
- date selector should be accessible by screen readers
- autocomplete rows should be clearly tappable

______________________________________________________________________

## Acceptance criteria

1. Main screen contains a clear “new list” action with icon and plus semantics
1. Tapping it opens a dedicated list creation screen
1. Top of the screen contains:
   - date selector
   - optional title field
1. User can type an item into an input field
1. Autocomplete suggestions appear in a dropdown under the field
1. Suggestions can be dismissed without blocking typing
1. Suggestions show food emojis for common items
1. User can add an item either from suggestion or custom text
1. Added items appear in the list immediately
1. Each item has a checkmark/checkbox
1. Checkbox can be toggled on and off
1. Feature works on both iOS and Android

______________________________________________________________________

## Suggested implementation order

1. Add home-screen “New List” button
1. Create list editor screen scaffold
1. Add date selector
1. Add optional title field
1. Add item input and add action
1. Add list-item rendering with checkbox toggle
1. Add local autocomplete dataset
1. Add suggestion filtering logic
1. Add dropdown UI and dismissal behavior
1. Polish spacing, icons, and interaction details

______________________________________________________________________

## Guidance for implementation

- prefer standard Flutter widgets first
- avoid introducing unnecessary dependencies unless clearly justified
- keep the solution minimal but production-shaped
- do not hardcode UI in a way that breaks one platform
- preserve clean separation between:
  - models
  - UI
  - interaction/state logic

______________________________________________________________________

## Deliverable

Implement the described feature as a clean, minimal, mobile-friendly Flutter flow for iOS and Android, using common mobile UX patterns and a simple but effective autocomplete experience.
