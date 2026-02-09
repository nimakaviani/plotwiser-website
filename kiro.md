# Plotwiser Website

Landing page for [plotwiser.com](https://plotwiser.com) — EUDR compliance checks made simple.

## Directory Structure

```
website/
├── content/                  # Static site files (served by CloudFront)
│   ├── plotwiser_landing.html
│   └── plotwiser_landing_files/
│       ├── image_large.png   # Dashboard screenshot (4.3MB)
│       └── image_small.png   # Logo (108KB)
├── terraform/
│   └── main.tf              # Infrastructure as code
├── deploy.sh                # One-command deploy
└── kiro.md                  # This file
```

## Infrastructure

All resources are in AWS `us-east-1` using the `personal` AWS profile.

| Resource | Detail |
|----------|--------|
| Domain | `plotwiser.com` (Route 53, zone `Z10152992WETAK9JM7ESY`) |
| S3 bucket | `plotwiser.com` — private, CloudFront OAC only |
| CloudFront | `E1W7KSJLDU4XI8` — HTTPS, redirect HTTP, PriceClass_100 |
| ACM cert | Covers `plotwiser.com` + `www.plotwiser.com`, DNS-validated |
| DNS | A-record aliases for apex and `www` → CloudFront |

## Deploy

```bash
./deploy.sh
```

This runs `terraform apply` and invalidates the CloudFront cache. Requires:
- Terraform CLI installed
- AWS CLI configured with a `personal` profile

## Update Content

1. Edit files in `content/`
2. Run `./deploy.sh`
3. Changes go live in ~30 seconds (after cache invalidation)

The HTML references images via relative paths (`./plotwiser_landing_files/...`), and Terraform uploads `plotwiser_landing.html` as both its original key and as `index.html` (CloudFront default root object).

## Tear Down

```bash
cd terraform && terraform destroy
```

This removes all AWS resources except the Route 53 hosted zone and domain registration.

## Origin

The original single-file export (`plotwiser_landing_NO_EXTRA_PANEL.html`, 5.9MB) had base64-encoded images inline. It was split into the current structure by extracting the two embedded PNGs into separate files and replacing the `data:` URIs with relative `src` paths.

A trimmed copy (`plotwiser_landing_v2.html`) exists with shorter copy — not currently deployed.

## Continuity Rule

**Every session that modifies this project must update `kiro.md` before ending.** This file is the single source of truth for anyone (human or AI) picking up the project later.

What to record:
- New or changed files and why
- Infrastructure changes (resource IDs, config updates)
- Design decisions and reversals
- Content edits (what was changed, what was reverted)
- Any commands or steps that aren't captured in `deploy.sh`

Keep it concise — bullet points, not paragraphs. Append a dated changelog entry at the bottom:

## Changelog

- **2026-02-08** — Initial setup: split 5.9MB single-file HTML into `content/` with external images. Created Terraform infra (S3 + CloudFront + ACM + Route 53). Deployed to plotwiser.com. Rewrote landing page copy for clarity. Replaced emoji card icons with monospace letters, then removed them. Created trimmed copy (`plotwiser_landing_v2.html`). Moved Terraform into `terraform/`, added `deploy.sh`.
