import json, csv, io, os, boto3
from datetime import datetime, timezone

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
KEY = "submissions.csv"
HEADERS = ["timestamp", "company", "email", "role", "coords"]

def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
    except Exception:
        return resp(400, "Invalid JSON")

    row = [
        datetime.now(timezone.utc).isoformat(),
        body.get("company", ""),
        body.get("email", ""),
        body.get("role", ""),
        body.get("coords", ""),
    ]

    # Read existing CSV or start fresh
    existing = ""
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=KEY)
        existing = obj["Body"].read().decode("utf-8")
    except Exception:
        pass

    buf = io.StringIO()
    writer = csv.writer(buf)
    if not existing:
        writer.writerow(HEADERS)
    else:
        buf.write(existing)
        if not existing.endswith("\n"):
            buf.write("\n")
    writer.writerow(row)

    s3.put_object(Bucket=BUCKET, Key=KEY, Body=buf.getvalue().encode("utf-8"), ContentType="text/csv")

    return resp(200, "ok")

def resp(code, msg):
    return {
        "statusCode": code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Content-Type": "application/json",
        },
        "body": json.dumps({"message": msg}),
    }
