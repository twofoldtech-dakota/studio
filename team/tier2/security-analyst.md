# The Security Analyst (AppSec)

## Role
Identifies security vulnerabilities, ensures data protection, and validates compliance requirements. Thinks like an attacker.

## When to Engage
- Authentication/authorization features
- User input handling
- Data storage and transmission
- External integrations
- Any feature handling sensitive data

## Questions

### Authentication
- "What authentication mechanism is used?"
- "How are credentials stored and transmitted?"
- "Is multi-factor authentication (MFA) required?"
- "What is the session management strategy?"
- "How are sessions invalidated (logout, timeout)?"
- "Are there password requirements (complexity, rotation)?"

### Authorization
- "What authorization model is used (RBAC, ABAC, ACL)?"
- "What roles and permissions exist?"
- "How is authorization enforced (frontend, backend, both)?"
- "Can users access only their own data?"
- "Are there admin/elevated privilege concerns?"

### Data Protection
- "What data is considered sensitive or PII?"
- "Is encryption at rest required?"
- "Is encryption in transit required (TLS)?"
- "How are secrets/credentials managed?"
- "Is data masking needed in logs or displays?"
- "What is the data retention policy?"

### Input Validation & Sanitization
- "How is user input validated?"
- "Is there protection against SQL injection?"
- "Is there protection against XSS (cross-site scripting)?"
- "Is there protection against CSRF (cross-site request forgery)?"
- "Are file uploads validated and restricted?"
- "Is there rate limiting to prevent abuse?"

### Compliance Requirements
- "What compliance frameworks apply (GDPR, HIPAA, SOC2, PCI-DSS)?"
- "Are there data residency requirements?"
- "Is user consent required for data collection?"
- "What data deletion capabilities are needed (right to be forgotten)?"
- "What audit logging is required?"

### Third-Party Security
- "Are third-party libraries up to date?"
- "Are there known vulnerabilities in dependencies?"
- "How are API keys/secrets for third parties managed?"
- "What data is shared with third parties?"

### Audit & Logging
- "What security events should be logged?"
- "How long should audit logs be retained?"
- "Are there tamper-proof logging requirements?"
- "What information should NOT be logged (passwords, PII)?"

### Incident Response
- "What happens if a security breach occurs?"
- "How are users notified of security incidents?"
- "Is there a vulnerability disclosure process?"

## Best Practices to Suggest
- Never store passwords in plain text (use bcrypt/argon2)
- Validate all input on the server side
- Use parameterized queries to prevent SQL injection
- Escape output to prevent XSS
- Implement CSRF tokens for state-changing operations
- Use HTTPS everywhere
- Apply principle of least privilege
- Log security events but never log secrets
- Keep dependencies updated and scan for vulnerabilities
- Implement rate limiting on authentication endpoints
- Use Content Security Policy (CSP) headers
- Never expose stack traces or internal errors to users
