"""
Agent 6: Post-Mortem Writer
Trigger: Manual invoke or P1/P2 SNS event after incident resolved
Action:  Assemble timeline from CloudTrail -> Bedrock draft -> S3 + GitHub issue
"""
import json, boto3, os, logging, urllib.request
from datetime import datetime, timezone, timedelta
from common.bedrock_client import invoke_claude
from common.notifications import publish_alert, log_event

logger = logging.getLogger(); logger.setLevel(logging.INFO)
ct  = boto3.client("cloudtrail", region_name="ap-south-1")
s3  = boto3.client("s3",         region_name="ap-south-1")
ssm = boto3.client("ssm",        region_name="ap-south-1")
POSTMORTEM_BUCKET = os.environ.get("POSTMORTEM_BUCKET", "compose-portal-dev-postmortems")
GITHUB_REPO       = os.environ.get("GITHUB_REPO",       "nimmalabalagit/compose-portal-application")

def get_cloudtrail_events(start, end):
    try:
        resp = ct.lookup_events(StartTime=start, EndTime=end, MaxResults=20)
        return [f"  {e['EventTime'].strftime('%H:%M:%S')} — {e['EventName']} by {e.get('Username','unknown')}" for e in resp.get("Events",[])]
    except Exception as e:
        return [f"CloudTrail unavailable: {e}"]

def get_github_token():
    return ssm.get_parameter(Name="/compose-portal/agents/github-token", WithDecryption=True)["Parameter"]["Value"]

def lambda_handler(event, context):
    log_event("postmortem-writer", "triggered", {})
    body         = event if isinstance(event, dict) else json.loads(event.get("body","{}"))
    incident_id  = body.get("incident_id", f"INC-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M')}")
    severity     = body.get("severity", "P2")
    services     = body.get("affected_services", ["gateway","order-service"])
    description  = body.get("description", "Service degradation detected via CloudWatch alarm")
    end_time     = datetime.now(timezone.utc)
    start_time   = end_time - timedelta(hours=2)
    ct_events    = get_cloudtrail_events(start_time, end_time)

    prompt = f"""Write a blameless post-mortem for EstateFlow AI.
INCIDENT ID: {incident_id} | SEVERITY: {severity}
AFFECTED SERVICES: {', '.join(services)}
DESCRIPTION: {description}
DURATION: ~{int((end_time - start_time).total_seconds() / 60)} minutes
CLOUDTRAIL EVENTS:\n{chr(10).join(ct_events)}
Platform: EKS 1.32 ap-south-1, 4 Spring Boot microservices, ArgoCD GitOps, Karpenter Spot, Istio.
Write complete blameless post-mortem: Summary, Timeline, Root Cause, Impact, What Went Well,
What Could Be Improved, Action Items table (Action|Owner|Due Date|Priority), Lessons Learned."""

    postmortem = invoke_claude(prompt=prompt, system="You are an SRE writing a blameless post-mortem. Be factual and constructive.", model="anthropic.claude-3-5-sonnet-20241022-v2:0")
    s3_key = f"postmortems/{incident_id}.md"
    try:
        s3.put_object(Bucket=POSTMORTEM_BUCKET, Key=s3_key, Body=postmortem.encode(), ContentType="text/markdown")
    except Exception as e:
        logger.warning(f"S3 upload failed: {e}")

    try:
        token   = get_github_token()
        payload = json.dumps({"title": f"[Post-Mortem] [{severity}] {incident_id}", "body": postmortem, "labels": ["post-mortem","incident"]}).encode()
        req     = urllib.request.Request(f"https://api.github.com/repos/{GITHUB_REPO}/issues", data=payload,
            headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.v3+json", "Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=10) as r:
            issue_url = json.loads(r.read()).get("html_url","")
    except Exception as e:
        issue_url = f"GitHub issue failed: {e}"

    return {"statusCode": 200, "body": json.dumps({"incident_id": incident_id, "s3_key": s3_key, "github_issue": issue_url}, default=str)}
