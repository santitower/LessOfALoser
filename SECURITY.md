# Security and privacy reports

Please do not open a public issue containing personal health information, Screen Time history, credentials, or reproducible data from a real person.

For the current prototype, report ordinary code issues through GitHub Issues using synthetic examples. Before the project handles production users, configure GitHub private vulnerability reporting and publish a dedicated security contact.

The optional Computer Coach gateway must remain bound to loopback and be exposed only with Tailscale Serve—not Funnel, router port forwarding, or a public reverse proxy. Do not place Tailscale auth keys, bearer tokens, Ollama transcripts, LaunchAgent plists containing secrets, or real wellness summaries in issues or commits.

Use a Tailscale ACL or grant to limit direct access to the Ollama host and port. The gateway's identity-header authorization is valid only behind Tailscale Serve, which supplies and sanitizes those headers.
