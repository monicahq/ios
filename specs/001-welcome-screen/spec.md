# Feature Specification: Welcome Screen

**Feature Branch**: `2026-11-25-welcome-screen`

**Created**: 2026-11-25

**Status**: Draft

**Input**: User description: "Do the same as the Android app so far: the first screen of the app, the welcome screen. For now nothing works, it is display only. Design: `Welcome Android.dc.html` in the Monica design project, adapted to iOS conventions. Support several languages: English by default, French as well, other languages later, aiming at parity with the web app."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the welcome screen when opening the app (Priority: P1)

A person who has just installed Monica opens the app for the first time. They land on a calm
welcome screen that tells them what Monica is and shows the two ways in: signing up or logging
in. They also see which Monica instance (server) the app will connect to.

**Why this priority**: It is the first thing every person sees, and it is the entry point every
later feature (sign up, log in, choosing an instance) will hang off.

**Independent Test**: Install the app, open it, and check that every element of the design is
present, in the right order, readable, in light and in dark mode.

**Acceptance Scenarios**:

1. **Given** the app is installed, **When** the person opens it, **Then** the welcome screen is
   shown with, from top to bottom: an instance settings button at the top right, the Monica logo
   and name, the welcoming panda illustration, the title "Welcome to Monica", a sentence saying
   what Monica helps with, a filled "Sign up" button, an outlined "Log in" button, and a line
   showing the current instance ("Instance: app.monicahq.com").
2. **Given** the device uses a dark theme, **When** the person opens the app, **Then** the screen
   uses the dark palette of the Monica design system and stays fully readable.
3. **Given** the welcome screen is shown, **When** the person taps "Sign up", "Log in", the
   instance settings button or the instance line, **Then** nothing happens and the screen stays
   as it is (these actions come in later features).

---

### User Story 2 - Read the screen in my language (Priority: P2)

A French-speaking person whose phone is set to French sees the whole welcome screen in French. A
person whose phone uses any language the app does not support yet sees it in English.

**Why this priority**: Monica's web app is available in many languages; the mobile app must be
built multilingual from its first screen so that adding a language never means rewriting a
screen.

**Independent Test**: Switch the device (or the app's language in system settings) between
English, French and an unsupported language such as German, and check every text on the screen.

**Acceptance Scenarios**:

1. **Given** the device language is French, **When** the person opens the app, **Then** every
   text is in French: "Bienvenue dans Monica", the description sentence, "Inscription",
   "Connexion", "Instance : app.monicahq.com", and the spoken labels of the settings button and
   the illustration.
2. **Given** the device language is English, **When** the person opens the app, **Then** every
   text is in English.
3. **Given** the device language is not supported yet (for example German), **When** the person
   opens the app, **Then** every text is in English.
4. **Given** the app's page in the Settings app, **When** the person opens its Language setting,
   **Then** English and French are offered and choosing one changes the language of the app
   without changing the device language.

---

### User Story 3 - Use the screen with accessibility settings (Priority: P3)

A person using a screen reader, a large font size or a small phone can still read and reach
everything on the welcome screen.

**Why this priority**: Accessibility is a delivery condition of the Monica design system, not an
afterthought, but the screen is already useful without the checks of this story.

**Independent Test**: Use VoiceOver, then the largest text size, then a small screen in
portrait and landscape, and check that every element can be read and reached.

**Acceptance Scenarios**:

1. **Given** VoiceOver is on, **When** the person moves through the screen, **Then** it
   announces the instance settings button by its name, the illustration by its description, the
   title as a heading, the description, both buttons by their labels, and the instance line;
   the decorative logo is skipped.
2. **Given** the largest text size (accessibility sizes included), **When** the person opens the app, **Then** no text is
   cut off or overlapping, and the content scrolls if it does not fit.
3. **Given** a small phone or landscape orientation, **When** the person opens the app, **Then**
   every element stays reachable by scrolling and both buttons stay fully visible once scrolled
   to.

---

### Edge Cases

- Very long translations (a future language): text wraps onto several lines and buttons grow in
  height rather than truncating the label.
- Device language changes while the app is open: the screen shows the new language when the
  person comes back to it.
- Device is offline: the screen shows exactly the same, since it needs no network.
- Tall screens: the buttons and the instance line sit at the bottom of the screen and the space
  between the description and the buttons absorbs the extra height, as in the design.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST show the welcome screen when it is opened.
- **FR-002**: The welcome screen MUST reproduce the `Welcome Android.dc.html` design: layout,
  order of elements, spacing, corner shapes and colours of the Monica design system. Where the
  platforms differ, iOS conventions win: system text styles and SF Symbols, so that text and
  icons follow the person's text size.
- **FR-003**: The screen MUST support the light and dark palettes of the Monica design system and
  follow the device theme.
- **FR-004**: The instance line MUST show the default instance address without its scheme
  (`app.monicahq.com` for `https://app.monicahq.com`).
- **FR-005**: "Sign up", "Log in", the instance settings button and the instance line MUST look
  and behave as touchable controls (touch feedback, focusable, announced as buttons) but MUST NOT
  trigger any action in this feature.
- **FR-006**: Every text on the screen, including spoken accessibility labels, MUST come from the
  app's translations, never be written directly into the screen.
- **FR-007**: The app MUST be available in English and French. English MUST be the default and the
  fallback for any language without a translation.
- **FR-008**: The wording MUST reuse the Monica web app's wording and translations wherever the web
  app already has the same text ("Sign up" / "Inscription", "Log in" / "Connexion",
  "Instance settings" / "Paramètres de l'instance").
- **FR-009**: The app MUST declare its supported languages to the system so that the app's
  Language setting in the Settings app offers English and French.
- **FR-010**: The illustration MUST have a spoken description; the logo, being next to the written
  name, MUST be ignored by screen readers. The title MUST be announced as a heading.
- **FR-011**: Every touchable control MUST have a touch target of at least 44 by 44 pt.
- **FR-012**: The content MUST scroll when it does not fit the screen (small screen, landscape,
  large font) without cutting or overlapping any text.

### Key Entities

- **Instance**: the Monica server the app will talk to, identified by its address. Only its
  default value (`https://app.monicahq.com`) is shown in this feature; changing it comes later.
- **Translation**: the text of each label of the screen in a given language. English and French
  are provided now; the list of languages grows toward the languages of the web app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a cold start, the welcome screen is fully displayed in under 1 second on a
  mid-range phone.
- **SC-002**: 100% of the texts on the screen are shown in French when the device is in French,
  and in English when the device is in English or in an unsupported language.
- **SC-003**: Side by side with the design, every element is in the same order and place, with
  the same colours, in both light and dark mode, on an iPhone 17 (402 × 874 pt).
- **SC-004**: With a screen reader, a person can reach and identify every control and the
  illustration in a single pass from top to bottom.
- **SC-005**: At the largest text size and on the narrowest supported iPhone (375 pt wide), no
  text is truncated or overlapping.

## Assumptions

- "Nothing works for now" means the controls are shown but do nothing. The instance settings
  sheet drawn in the design (instance URL field, Reset to default, Cancel, Save) is out of scope
  and will be its own feature, as will signing up and logging in.
- The default instance is `https://app.monicahq.com`, as in the design.
- The design draws the French version; the English texts are: "Welcome to Monica", "Monica helps
  you remember and organise your relationships and life context.", "Sign up", "Log in",
  "Instance: app.monicahq.com", "Instance settings", and the illustration description "A panda
  sitting in the grass, waving". The design's "Login" button becomes "Log in" (the verb, in
  sentence case, as in the web app).
- English follows the web app's British-leaning spelling ("organise", "colour").
- The illustration (`assets/panda-welcome.png`) and the logo (`assets/logo.svg`) are taken from the
  design project as they are, through the Android app's copies. The settings and instance glyphs
  are the closest SF Symbols (`gearshape`, `server.rack`).
- The Android app's welcome screen (`../android/specs/001-welcome-screen`) is the reference for
  behaviour, texts and translations; both apps share the string keys.
- Only portrait phones are designed; landscape and tablets only need to stay usable (scrolling),
  not to have a dedicated layout.
- The language follows the device language or the app's language chosen in the Settings app; an
  in-app language picker is out of scope.
