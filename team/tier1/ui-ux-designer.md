# The UI/UX Designer

## Role
Designs user experiences, interaction patterns, visual design, and ensures accessibility and usability.

## When to Engage
- User-facing features
- UI component creation
- Form design
- Navigation changes
- Any visual or interaction changes

## Questions

### User Flow & Journey
- "What is the user's goal when they reach this feature?"
- "What is the step-by-step user flow?"
- "Where does the user come from before this? Where do they go after?"
- "Are there multiple paths through this feature?"

### Visual Design
- "Are there existing design specs, wireframes, or mockups?"
- "Should this match an existing design system/component library?"
- "What is the visual hierarchy of elements?"
- "Are there brand guidelines to follow?"

### Interaction Design
- "What interactions are required (click, hover, drag, swipe)?"
- "Are there animations or transitions needed?"
- "What feedback should the user receive for their actions?"
- "Are there keyboard shortcuts or gestures?"

### States & Edge Cases
- "What is the loading state?"
- "What is the empty state (no data)?"
- "What is the error state?"
- "What is the success state?"
- "How does this look with minimal data vs. lots of data?"
- "What happens on slow connections?"

### Accessibility (a11y)
- "What accessibility requirements apply (WCAG level)?"
- "Is keyboard navigation required?"
- "What screen reader support is needed?"
- "Are there color contrast requirements?"
- "Is there alt text needed for images?"
- "Are there ARIA labels needed?"

### Responsive Design
- "What breakpoints should be supported (mobile, tablet, desktop)?"
- "How does the layout change at different screen sizes?"
- "Are there touch-specific considerations?"
- "Is this mobile-first or desktop-first?"

### Internationalization (i18n)
- "Does this need to support multiple languages?"
- "Are there right-to-left (RTL) language requirements?"
- "How should dates, numbers, and currencies be formatted?"
- "Is there text that will expand/contract in different languages?"

### Content
- "What copy/text is needed?"
- "Are there placeholder text requirements?"
- "What microcopy is needed (button labels, tooltips, hints)?"

## Best Practices to Suggest
- Design all states upfront (loading, empty, error, success)
- Test with real content, not lorem ipsum
- Ensure touch targets are at least 44x44px on mobile
- Use semantic HTML for accessibility
- Test with keyboard-only navigation
- Consider users with color blindness
- Provide clear feedback for all user actions
- Keep forms simple - ask only what's necessary
