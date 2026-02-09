#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")/terraform" && pwd)"
CONTENT="$(cd "$(dirname "$0")/content" && pwd)"

cd "$DIR"
terraform init -input=false
terraform apply -auto-approve

# Get outputs
API_URL=$(terraform output -raw api_url)
SITE_URL=$(terraform output -raw site_url)
DATA_BUCKET=$(terraform output -raw data_bucket)
CF_DOMAIN=$(terraform output -raw cloudfront_url | sed 's|https://||')

# Inject API URL into HTML before uploading to S3
TMPHTML=$(mktemp)
sed "s|%%API_URL%%|${API_URL}|g" "$CONTENT/plotwiser_landing.html" > "$TMPHTML"

# Upload patched HTML as index.html and original key
aws s3 cp "$TMPHTML" "s3://plotwiser.com/index.html" \
  --content-type "text/html" --profile personal --region us-east-1
aws s3 cp "$TMPHTML" "s3://plotwiser.com/plotwiser_landing.html" \
  --content-type "text/html" --profile personal --region us-east-1
rm "$TMPHTML"

# Sync images
aws s3 sync "$CONTENT/plotwiser_landing_files/" "s3://plotwiser.com/plotwiser_landing_files/" \
  --profile personal --region us-east-1

# Invalidate CloudFront cache
CF_ID=$(aws cloudfront list-distributions --profile personal --region us-east-1 \
  --query "DistributionList.Items[?DomainName=='${CF_DOMAIN}'].Id" --output text)
if [ -n "$CF_ID" ]; then
  echo "Invalidating CloudFront cache ($CF_ID)..."
  aws cloudfront create-invalidation --profile personal --region us-east-1 \
    --distribution-id "$CF_ID" --paths "/*" --output text
fi

echo ""
echo "✓ Deployed to $SITE_URL"
echo "  API: $API_URL/submit"
echo ""

# Generate pre-signed URL for CSV download (valid 1 hour, only you can generate this)
CSV_URL=$(aws s3 presign "s3://${DATA_BUCKET}/submissions.csv" \
  --expires-in 3600 --profile personal --region us-east-1 2>/dev/null || echo "")
if [ -n "$CSV_URL" ]; then
  echo "📋 Submissions CSV (1hr link, do not share):"
  echo "   $CSV_URL"
else
  echo "📋 No submissions yet. CSV will appear after the first form submission."
fi
