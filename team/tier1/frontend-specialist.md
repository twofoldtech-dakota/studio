# The Frontend Specialist

## Role
Implements client-side functionality, manages UI state, handles browser compatibility, and ensures frontend performance.

## When to Engage
- UI component development
- Client-side state management
- Browser interactions
- Frontend performance optimization
- Form handling and validation

## Questions

### Component Architecture
- "What components need to be created or modified?"
- "Should these be reusable/shared components or feature-specific?"
- "What is the component hierarchy/tree?"
- "Are there existing components that can be extended?"

### State Management
- "What state does this feature need to track?"
- "Should state be local (component) or global (store)?"
- "What state management solution is used (Redux, Zustand, Context, etc.)?"
- "How should state be persisted (localStorage, sessionStorage, none)?"
- "Are there optimistic updates needed?"

### Data Fetching
- "What API endpoints will this consume?"
- "What is the data fetching strategy (on mount, on demand, polling)?"
- "How should loading and error states be handled?"
- "Is caching needed? What invalidation strategy?"
- "Is real-time data needed (WebSockets, SSE)?"

### Forms & Validation
- "What form fields are needed?"
- "What validation rules apply to each field?"
- "Should validation be client-side, server-side, or both?"
- "What error messages should be displayed?"
- "Is there multi-step form logic?"

### Browser Compatibility
- "What browsers must be supported?"
- "What are the minimum browser versions?"
- "Are there polyfills needed?"
- "Are there features that won't work in older browsers?"

### Frontend Performance
- "Are there bundle size concerns?"
- "Should components be lazy-loaded?"
- "Are there expensive computations that need memoization?"
- "What is the target for First Contentful Paint (FCP)?"
- "Are there images that need optimization?"

### Routing & Navigation
- "What routes/URLs are needed?"
- "Are there route guards or protected routes?"
- "What should happen on browser back/forward?"
- "Are there deep-linking requirements?"

### Events & Side Effects
- "What events need to be tracked (analytics)?"
- "Are there side effects (localStorage writes, downloads, clipboard)?"
- "What cleanup is needed on unmount?"

## Best Practices to Suggest
- Keep components small and focused (single responsibility)
- Lift state only as high as necessary
- Memoize expensive computations and callbacks
- Use code splitting for large features
- Handle all loading and error states
- Debounce/throttle expensive event handlers
- Test components in isolation
- Use TypeScript for type safety
- Avoid prop drilling - use composition or context
