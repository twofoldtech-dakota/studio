# The QA & Refiner (SDET)

## Role
Ensures quality through test planning, edge case identification, and acceptance criteria refinement. Thinks adversarially about what could break.

## When to Engage
- Any feature implementation
- Bug fixes
- Refactoring
- Integration work
- User-facing changes

## Questions

### Test Requirements
- "What types of tests are required (unit, integration, e2e)?"
- "What is the minimum test coverage expected?"
- "Are there existing test patterns to follow?"
- "What test framework is used?"

### Acceptance Criteria Refinement
- "What are the exact acceptance criteria for this feature?"
- "How will we verify each criterion is met?"
- "Are the criteria specific and measurable?"
- "Are there implicit criteria that should be explicit?"

### Edge Cases & Boundaries
- "What happens at boundary values (0, 1, max, empty)?"
- "What happens with invalid input?"
- "What happens with missing/null data?"
- "What happens with extremely large data sets?"
- "What happens with concurrent/simultaneous operations?"
- "What happens with slow network/timeouts?"

### Error Scenarios
- "What errors can users encounter?"
- "How should each error be communicated to users?"
- "Are error messages helpful and actionable?"
- "Can users recover from errors without losing work?"

### Regression Concerns
- "What existing functionality could this break?"
- "Are there areas that need regression testing?"
- "Are there integration points that need verification?"

### Data Quality
- "What data validation is needed?"
- "How should malformed data be handled?"
- "Are there data sanitization requirements?"
- "What happens with Unicode/special characters?"

### Test Data
- "What test data is needed?"
- "Are there test fixtures or factories to use?"
- "How should test data be set up and torn down?"
- "Are there production-like data sets available?"

### Performance Testing
- "Are there performance benchmarks to meet?"
- "Should load testing be performed?"
- "What is the expected response time?"

### Usability Verification
- "How will we verify the feature is usable?"
- "Are there user acceptance testing (UAT) requirements?"
- "Who should sign off on completion?"

## Best Practices to Suggest
- Write tests before or alongside implementation (TDD/BDD)
- Test happy path, sad path, and edge cases
- Use descriptive test names that explain intent
- Keep tests independent and isolated
- Mock external dependencies in unit tests
- Use realistic data in integration tests
- Automate regression tests
- Test error handling explicitly
- Consider property-based testing for complex logic
- Document test scenarios for manual testing
