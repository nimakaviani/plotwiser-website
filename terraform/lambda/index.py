import json, csv, io, os, boto3
from datetime import datetime, timezone

s3 = boto3.client("s3")
ses = boto3.client("ses", region_name="us-east-1")
BUCKET = os.environ["BUCKET"]
NOTIFY = os.environ.get("NOTIFY_EMAIL", "")
KEY = "submissions.csv"
HEADERS = ["timestamp", "company", "email", "role", "coords"]

def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
    except Exception:
        return resp(400, "Invalid JSON")

    # Honeypot: if this hidden field has a value, it's a bot
    if body.get("website", ""):
        return resp(200, "ok")

    now = datetime.now(timezone.utc).isoformat()
    row = [now, body.get("company",""), body.get("email",""), body.get("role",""), body.get("coords","")]

    # Append to CSV
    existing = ""
    try:
        existing = s3.get_object(Bucket=BUCKET, Key=KEY)["Body"].read().decode("utf-8")
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

    # Send notification email
    if NOTIFY:
        try:
            ses.send_email(
                Source=NOTIFY,
                Destination={"ToAddresses": [NOTIFY]},
                Message={
                    "Subject": {"Data": f"Plotwiser: new request from {body.get('company','(unknown)')}"},
                    "Body": {"Text": {"Data":
                        f"New submission at {now}\n\n"
                        f"Company: {body.get('company','')}\n"
                        f"Email:   {body.get('email','')}\n"
                        f"Role:    {body.get('role','')}\n"
                        f"Coords:  {body.get('coords','(none)')}\n"
                    }},
                },
            )
        except Exception as e:
            print(f"SES error: {e}")

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
