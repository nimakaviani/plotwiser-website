# Plotwiser

Landing page for [plotwiser.com](https://plotwiser.com) — a tool to validate plot data, flag risks, and export audit-ready evidence packs.

## Quick Start

```bash
./deploy.sh
```

Deploys everything (infra + content + Lambda) and prints the live URL.

## Get Form Submissions

```bash
aws s3 cp s3://plotwiser.com-data/submissions.csv . --profile personal --region us-east-1
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://aws.amazon.com/cli/) with a `personal` profile configured

## Details

See [kiro.md](kiro.md) for full architecture, infrastructure IDs, and changelog.
