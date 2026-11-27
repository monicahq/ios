# Accessibility

Accessibility is **mandatory** (constitution, principle VII). A screen that does not pass this page
is not done, whatever its tests say. The target is WCAG 2.2 AA applied to mobile.

## What every screen must do

| Rule | How in SwiftUI |
| --- | --- |
| Every control has a label, a trait and a state | Use standard controls (`Button`, `Toggle`, `Picker`, `NavigationLink`...), which bring the right traits and state. A custom tappable view is a `Button` with a custom `ButtonStyle`, never an `onTapGesture`. |
| Icon-only controls are named | `Label("key", systemImage: "gearshape").labelStyle(.iconOnly)` inside the `Button`: VoiceOver reads the title. |
| Decorative images are hidden | `.accessibilityHidden(true)`, or `Image(decorative:)` (an image next to text that already says the same thing is decorative). |
| Meaningful images are described | `.accessibilityLabel(Text("key"))`, describing what the image shows, not that it is an image. |
| Headings are headings | `.accessibilityAddTraits(.isHeader)` on screen titles and section titles. |
| Grouped content reads as one item | `.accessibilityElement(children: .combine)` on a row whose parts only make sense together. A `Button` already combines its label. |
| Reading order follows the visual order | Lay out in visual order; use `.accessibilitySortPriority` only when the layout cannot. |
| Touch targets of 44 × 44 pt | `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(Rectangle())` on small controls. |
| Contrast 4.5:1 for text, 3:1 for controls | Use only the colour tokens of the asset catalog (`Color.ink`, `Color.muted`...), never a raw colour. Check both light and dark. |
| Never colour alone | A state or an error also has text or an icon with a label. |
| Dynamic Type | Text styles (`.font(.body)`, `.title`...) or `@ScaledMetric` for custom sizes, never a fixed font size. No fixed heights on text containers (`minHeight` instead), `ScrollView` when content can outgrow the screen. Never shrink text with `minimumScaleFactor` or cut it with `lineLimit`. |
| Reduce Motion | No animation is the only way to convey information; check `@Environment(\.accessibilityReduceMotion)` before a large or decorative animation. |
| Gesture alternatives | Swipe, long press and drag actions are also offered as a visible control or as `.accessibilityAction`. |
| Language | Text comes from the String Catalog so VoiceOver reads it with the right voice. |

## Automated checks

There are no UI tests (constitution, principle IV), so the automated checks are:

- the `accessibility-reviewer` agent, run on every change that touches `Monica/`, which reviews the
  code against this page;
- the **Accessibility Inspector**'s audit (Xcode > Open Developer Tool > Accessibility Inspector,
  pointed at the simulator, Audit tab) on every screen the change touches, in light and dark
  appearance and at the largest text size: element descriptions, contrast, hit regions, Dynamic
  Type, clipped text, traits. Screen previews show the states that are hard to reach by hand.

## Manual checks before a pull request

Automated checks catch about a third of problems. For every screen a change touches:

1. **VoiceOver** (Settings > Accessibility > VoiceOver, or the Accessibility Inspector on the
   simulator): swipe through the whole screen. Every element is announced with a sensible label,
   trait and state, in visual order, nothing decorative is announced, headings are announced as
   headings, and every action can be performed.
2. **Largest text size** (Settings > Accessibility > Display & Text Size > Larger Text, accessibility
   sizes on): nothing is cut, overlapping or unreachable.
3. **Dark mode**: everything stays readable.
4. **Reduce Motion** (Settings > Accessibility > Motion): nothing important is lost.
5. **Full Keyboard Access or Switch Control** for screens with complex interactions: every action
   is reachable and the focus is visible.

The pull request says, in a bullet, which of these were done.
