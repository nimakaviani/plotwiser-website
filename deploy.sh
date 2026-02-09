#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")/terraform" && pwd)"

cd "$DIR"
terraform init -input=false
terraform apply -auto-approve

# Invalidate CloudFront cache so changes go live immediately
DIST_ID=$(terraform output -raw cloudfront_url | sed 's|https://||')
CF_ID=$(aws cloudfront list-distributions --profile personal \
  --query "DistributionList.Items[?DomainName=='${DIST_ID}'].Id" --output text)

if [ -n "$CF_ID" ]; then
  echo "Invalidating CloudFront cache ($CF_ID)..."
  aws cloudfront create-invalidation --profile personal \
    --distribution-id "$CF_ID" --paths "/*" --output text
fi

echo ""
echo "✓ Deployed to $(terraform output -raw site_url)"
