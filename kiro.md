# Plotwiser Website

Landing page for [plotwiser.com](https://plotwiser.com) — plot checks made simple.

## Directory Structure

```
website/
├── content/                          # Static site files (served by CloudFront)
│   ├── plotwiser_landing.html        # Landing page (contains %%API_URL%% placeholder)
│   └── plotwiser_landing_files/
│       ├── image_large.png           # Dashboard screenshot (4.3MB)
│       └── image_small.png           # Logo (108KB)
├── terraform/
│   ├── main.tf                       # Infrastructure as code
│   └── lambda/
│       └── index.py                  # Form submission handler
├── deploy.sh                         # One-command deploy
├── .gitignore
└── kiro.md                           # This file
```

## Infrastructure

All resources are in AWS `us-east-1` using the `personal` AWS profile.

| Resource | Detail |
|----------|--------|
| Domain | `plotwiser.com` (Route 53, zone `Z10152992WETAK9JM7ESY`) |
| S3 bucket (site) | `plotwiser.com` — private, CloudFront OAC only |
| S3 bucket (data) | `plotwiser.com-data` — private, encrypted (AES256), no public access |
| CloudFront | `E1W7KSJLDU4XI8` — HTTPS, redirect HTTP, PriceClass_100 |
| ACM cert | Covers `plotwiser.com` + `www.plotwiser.com`, DNS-validated |
| DNS | A-record aliases for apex and `www` → CloudFront |
| API Gateway | `gyrixyqhwl` — HTTP API, CORS locked to plotwiser.com |
| Lambda | `plotwiser-form` — Python 3.12, appends form submissions to CSV |
| IAM role | `plotwiser-form-lambda` — scoped to `submissions.csv` only + CloudWatch logs |

## Form Submissions

The "Request access" form on the landing page POSTs to API Gateway → Lambda → S3.

- Submissions are stored in `s3://plotwiser.com-data/submissions.csv`
- CSV columns: `timestamp, company, email, role, coords`
- The data bucket is fully private — no public access, server-side encryption enabled
- Only your AWS credentials (`personal` profile) can access the CSV

### Download submissions

The `deploy.sh` script prints a 1-hour pre-signed URL at the end of every deploy. To get a link manually:

```bash
aws s3 presign s3://plotwiser.com-data/submissions.csv --expires-in 3600 --profile personal --region us-east-1
```

Or download directly:

```bash
aws s3 cp s3://plotwiser.com-data/submissions.csv ./submissions.csv --profile personal --region us-east-1
```

## Deploy

```bash
./deploy.sh
```

This script:
1. Runs `terraform init` + `terraform apply` (infra + Lambda)
2. Injects the API Gateway URL into the HTML (replaces `%%API_URL%%` placeholder)
3. Uploads patched HTML to S3 as `index.html` and `plotwiser_landing.html`
4. Syncs images to S3
5. Invalidates CloudFront cache
6. Prints a 1-hour pre-signed URL for the submissions CSV

Requires: Terraform CLI, AWS CLI, `personal` AWS profile configured.

## Update Content

1. Edit files in `content/`
2. Run `./deploy.sh`
3. Changes go live in ~30 seconds (after cache invalidation)

**Important:** The HTML source in `content/` contains `%%API_URL%%` as a placeholder. The deploy script replaces it at deploy time. Do not hardcode the API URL in the source file.

## Tear Down

```bash
cd terraform && terraform destroy
```

This removes all AWS resources except the Route 53 hosted zone and domain registration. The data bucket will fail to delete if it contains the CSV — empty it first with `aws s3 rm s3://plotwiser.com-data --recursive --profile personal`.

## Known Issues

- No `favicon.ico` — browsers log a 403. Harmless but could be fixed by uploading one.
- Curly quotes/apostrophes in JS strings will break the script. Always use straight quotes in `<script>` blocks.

## Continuity Rule

**Every session that modifies this project must update `kiro.md` before ending.** This file is the single source of truth for anyone (human or AI) picking up the project later.

What to record:
- New or changed files and why
- Infrastructure changes (resource IDs, config updates)
- Design decisions and reversals
- Content edits (what was changed, what was reverted)
- Any commands or steps that aren't captured in `deploy.sh`

Keep it concise — bullet points, not paragraphs. Append a dated changelog entry at the bottom.

## Changelog

- **2026-02-08** — Initial setup: split 5.9MB single-file HTML into `content/` with external images. Created Terraform infra (S3 + CloudFront + ACM + Route 53). Deployed to plotwiser.com. Rewrote landing page copy for clarity. Replaced emoji card icons with monospace letters, then removed them. Created trimmed copy (`plotwiser_landing_v2.html`). Moved Terraform into `terraform/`, added `deploy.sh`.
- **2026-02-08** — Added form submission backend: Lambda + API Gateway + private S3 data bucket (`plotwiser.com-data`). Form POSTs to API, Lambda appends to `submissions.csv`. Deploy script injects API URL and prints pre-signed CSV download link. Fixed curly apostrophe bug in JS that broke `submitForm`. Removed all `file:///` local paths from links. Removed EUDR references from copy. Updated logo sizing from height-based to width-based (140px).
