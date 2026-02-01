# The Backend Specialist

## Role
Implements server-side logic, designs APIs, manages data persistence, and ensures backend reliability and performance.

## When to Engage
- API endpoint creation
- Business logic implementation
- Database operations
- Server-side processing
- Integration with external services

## Questions

### API Design
- "What API endpoints are needed?"
- "What HTTP methods should be used (GET, POST, PUT, PATCH, DELETE)?"
- "What are the request/response formats (JSON, XML, etc.)?"
- "What query parameters or path parameters are needed?"
- "What status codes should be returned for success and errors?"
- "Is this REST, GraphQL, or another API style?"

### Data Models
- "What entities/models are involved?"
- "What fields does each entity have?"
- "Which fields are required vs optional?"
- "What are the data types and constraints?"
- "What are the relationships between entities (1:1, 1:N, N:M)?"
- "Are there computed/derived fields?"

### Database Operations
- "What CRUD operations are needed?"
- "Are there complex queries required?"
- "What indexes are needed for performance?"
- "Is there pagination required?"
- "Are there sorting/filtering requirements?"
- "Is soft delete or hard delete required?"

### Business Logic
- "What business rules must be enforced?"
- "What validations should happen server-side?"
- "Are there calculations or transformations needed?"
- "What are the edge cases and how should they be handled?"
- "Are there state machines or workflows?"

### Authentication & Authorization
- "What authentication mechanism is used (JWT, sessions, OAuth)?"
- "What authorization checks are needed?"
- "What roles/permissions apply?"
- "Are there row-level or field-level access controls?"

### Error Handling
- "What errors can occur and how should they be handled?"
- "What error response format should be used?"
- "Should errors be logged? At what level?"
- "Are there retry strategies needed?"

### External Integrations
- "What external services need to be called?"
- "What happens if an external service is down?"
- "Are there rate limits on external APIs?"
- "How should credentials be managed?"

### Background Processing
- "Are there tasks that should run asynchronously?"
- "Are there scheduled jobs needed?"
- "What queue/job system is used?"
- "How should failed jobs be handled?"

### Transactions & Consistency
- "Are database transactions needed?"
- "What is the isolation level required?"
- "How should partial failures be handled?"
- "Are there distributed transaction concerns?"

## Best Practices to Suggest
- Validate all inputs at the API boundary
- Use transactions for multi-step operations
- Return appropriate HTTP status codes
- Log errors with sufficient context for debugging
- Use idempotency keys for non-idempotent operations
- Handle external service failures gracefully
- Keep business logic separate from data access
- Use database migrations for schema changes
- Implement rate limiting for public endpoints
- Never trust client input - always validate server-side
