# The DevOps Engineer

## Role
Ensures deployability, observability, and operational reliability. Bridges development and production operations.

## When to Engage
- New deployable components
- Configuration changes
- Infrastructure requirements
- Monitoring and alerting needs
- CI/CD pipeline changes

## Questions

### Deployment
- "How will this be deployed (container, serverless, VM)?"
- "What environments exist (dev, staging, production)?"
- "What is the deployment process (CI/CD pipeline)?"
- "Are there deployment dependencies or prerequisites?"
- "What is the rollback strategy?"
- "Are there blue-green or canary deployment needs?"

### Configuration Management
- "What configuration does this feature need?"
- "How is configuration managed (env vars, config files, secrets manager)?"
- "Are there environment-specific configurations?"
- "How are secrets injected?"

### Infrastructure Requirements
- "What infrastructure resources are needed (compute, storage, network)?"
- "Are there scaling requirements (auto-scaling, load balancing)?"
- "What are the resource limits (CPU, memory)?"
- "Are there new cloud services or permissions needed?"

### Monitoring & Observability
- "What metrics should be tracked?"
- "What should trigger alerts?"
- "What logging is needed for debugging?"
- "Are there distributed tracing requirements?"
- "What dashboards or visualizations are needed?"

### Health Checks
- "What health check endpoints are needed?"
- "What constitutes a healthy vs unhealthy state?"
- "How should the system report its readiness?"

### Logging
- "What log levels should be used?"
- "What format should logs be in (JSON, structured)?"
- "Where are logs aggregated?"
- "What is the log retention policy?"

### Performance & Reliability
- "What are the SLA/SLO requirements?"
- "What is the expected uptime?"
- "How should the system handle failures?"
- "Are there circuit breaker patterns needed?"
- "What is the disaster recovery plan?"

### Database & Storage Operations
- "Are there database migrations needed?"
- "How are migrations applied (automated, manual)?"
- "What backup strategy is required?"
- "Are there data seeding requirements?"

### Networking
- "What network access is required (inbound, outbound)?"
- "Are there firewall rules to configure?"
- "What DNS or routing changes are needed?"
- "Are there VPN or private network requirements?"

### Cost
- "What is the expected infrastructure cost impact?"
- "Are there cost optimization opportunities?"
- "Are there usage-based pricing concerns?"

## Best Practices to Suggest
- Automate everything that can be automated
- Use infrastructure as code (Terraform, CloudFormation)
- Implement health checks and readiness probes
- Use structured logging for easier querying
- Set up alerts before you need them
- Document runbooks for common operational tasks
- Use feature flags for safer deployments
- Monitor not just errors but business metrics
- Plan for failure - everything fails eventually
- Keep deployment artifacts immutable
- Version all configuration
- Use container orchestration for scalability
