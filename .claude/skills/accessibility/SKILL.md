---
name: accessibility
description: Accessibility rules for every screen of this iOS app (VoiceOver, touch targets, contrast, Dynamic Type, Reduce Motion, Accessibility Inspector audit). Use whenever creating or changing a SwiftUI view, a screen, an icon, an image or a colour, and before a pull request that touches the UI. Trigger whenever accessibility, a11y, VoiceOver, accessibilityLabel, traits, Dynamic Type or screen reader is mentioned.
---

# Accessibility

Accessibility is mandatory: principle VII of `.specify/memory/constitution.md` makes it a
delivery condition, not a final pass.

1. Read `docs/accessibility.md` before writing or changing a view. Apply every rule of its table to
   what you write.
2. Run the Accessibility Inspector's audit on every screen the change touches, in light and dark
   appearance (there are no UI tests to run it automatically, see `docs/accessibility.md`).
3. Every accessibility label, hint and value is a String Catalog entry, translated in every
   supported language like any other text.
4. Before a pull request that changes the UI, launch the `accessibility-reviewer` agent on the
   change and fix what it confirms.
5. Do the manual checks of `docs/accessibility.md` on a simulator or a device (VoiceOver, largest
   text size, dark mode). When you cannot run them, say so explicitly; never claim a check you did
   not do.
