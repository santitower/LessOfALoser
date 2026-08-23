# Private Computer Coach over Tailscale

LessOfALoser can use a model running on a Mac, Linux PC, or Windows PC when an iPhone cannot run the preferred local model. Tailscale provides the private network and HTTPS identity; iCloud is not used as a tunnel.

```text
iPhone app
  -> Tailscale HTTPS (tailnet members only)
  -> localhost-only LessOfALoser gateway
  -> Ollama on the selected computer
```

The app sends one aggregate `WellnessTrendSummary`: the date, current and baseline sleep/step/Screen Time totals, percentage changes, canonical observations, and data coverage. The gateway recomputes the observations from the numeric trends and rejects mismatches, raw samples, app names, domains, arbitrary prompts, tools, and unknown fields.

## Current tested setup

The checked-in defaults match the existing Santitower tailnet:

- Gateway host: the Mac running this repository
- Model host: `http://thetower-1:11434`
- Model: `qwen2.5:7b-instruct`
- Public internet exposure: none; Tailscale Funnel is not enabled

The Ollama host can be changed without changing the app:

```sh
LESSOFALOSER_OLLAMA_URL=http://another-tailnet-computer:11434 \
LESSOFALOSER_OLLAMA_MODEL=qwen3:8b \
./scripts/run-desktop-gateway.sh
```

## One-command Mac setup

Install and sign in to Tailscale on both the iPhone and gateway Mac. Make sure the Ollama computer is also on that tailnet, then run:

```sh
./scripts/install-macos-gateway.sh
```

To persist a different Ollama computer or model, provide the variables while installing:

```sh
LESSOFALOSER_OLLAMA_URL=http://my-model-pc:11434 \
LESSOFALOSER_OLLAMA_MODEL=qwen3:8b \
./scripts/install-macos-gateway.sh
```

The installer copies the small gateway runtime to `~/Library/Application Support/LessOfALoser`, creates a per-user LaunchAgent, starts the localhost gateway after login, and configures Tailscale Serve on private HTTPS port 443. The runtime copy avoids macOS privacy restrictions on background processes reading a repository in `Documents`. The installer prints the URL to enter in the app. Nothing is exposed with Tailscale Funnel.

To run it only for the current terminal instead:

```sh
./scripts/run-desktop-gateway.sh
tailscale serve --bg --yes 8787
```

The first command prints both the HTTPS address and a `lessofaloser://connect?...` link. Open that connection link on an installed build, review the prefilled address, and tap **Connect & Use**. The app does not contact or save a server supplied by a link until that explicit confirmation. You can instead paste the HTTPS address into **Computer Coach** and tap **Quick Connect**.

Verify the authenticated path from another tailnet device:

```sh
curl https://your-computer.your-tailnet.ts.net/v1/ready
```

## Configuration

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `LESSOFALOSER_OLLAMA_URL` | `http://thetower-1:11434` in the run script | Ollama server reachable through the tailnet |
| `LESSOFALOSER_OLLAMA_MODEL` | `qwen2.5:7b-instruct` | Installed Ollama model name |
| `LESSOFALOSER_ALLOWED_TAILSCALE_USERS` | Any authenticated member of the tailnet | Optional comma-separated user allowlist |
| `LESSOFALOSER_GATEWAY_TOKEN` | unset | Optional bearer token for localhost development only |
| `LESSOFALOSER_OLLAMA_TIMEOUT` | `180` | Maximum upstream generation time in seconds |

The group can share the connection URL after each member joins the same tailnet and signs in to Tailscale on their iPhone. Set `LESSOFALOSER_ALLOWED_TAILSCALE_USERS` if only particular identities should be allowed.

Production deployments should use a Tailscale ACL or grant so only the gateway machine can reach Ollama's port `11434`. The iPhone should reach only the gateway's HTTPS service. Keep the gateway bound to `127.0.0.1`; it deliberately refuses a non-loopback bind. The app accepts only Tailscale `*.ts.net` HTTPS addresses (plus loopback HTTP for development) and does not follow redirects.

## Stop or remove the Mac service

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.santitower.lessofaloser-gateway.plist"
tailscale serve --https=443 off
```

The installer backs up an existing LaunchAgent plist before replacing it. Removing the plist itself is optional and can be done in Finder.

## Why Tailscale instead of iCloud

iCloud is useful for syncing records, but it is not a request/response transport to a specific personal computer and does not provide model-service discovery or availability. Tailscale gives the phone a private route, device identity, MagicDNS name, and HTTPS certificate while keeping the service off the public internet.

## Safety and failure behavior

- Tailscale identity or an explicit development token is required for model requests.
- The gateway logs only timestamp, client address, route, and status—not request bodies.
- The model receives a fixed wellness-only prompt and cannot invoke tools.
- The model can return only an action category; it cannot supply user-visible prose.
- The gateway converts the category to a vetted headline and action, and rejects categories whose metric is missing or does not match the first canonical observation.
- The gateway supplies the fixed medical disclaimer rather than trusting model output.
- If the computer is offline, unauthorized, too slow, or returns invalid output, the app falls back to its on-device model and then deterministic rules.
