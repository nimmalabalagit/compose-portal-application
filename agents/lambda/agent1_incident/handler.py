"""
Agent 1: Incident Responder
Trigger: CloudWatch Alarm -> EventBridge -> Lambda
Action:  Gathers metrics + ArgoCD history -> Bedrock RCA -> SNS alert
"""
import json, boto3, os, logging
from datetime import datetime, timezone, timedelta
from common.bedrock_client import invoke_claude
from common.notifications import publish_alert, log_event

logger = logging.getLogger()
logger.setLevel(logging.INFO)
cw  = boto3.client("cloudwatch", region_name="ap-south-1")
ssm = boto3.client("ssm",        region_name="ap-south-1")
CLUSTER_NAME  = os.environ.get("CLUSTER_NAME",  "compose-portal-dev-eks")
ARGOCD_SERVER = os.environ.get("ARGOCD_SERVER", "argocd.estateflowai.co")

def get_alarm_context(alarm_name):
    resp   = cw.describe_alarms(AlarmNames=[alarm_name])
    alarms = resp.get("MetricAlarms", [])
    if not alarms: return {}
    a = alarms[0]
    return {"alarm_name": a["AlarmName"], "state": a["StateValue"],
            "reason": a.get("StateReason",""), "namespace": a.get("Namespace",""),
            "metric": a.get("MetricName",""), "threshold": a.get("Threshold",0),
            "comparison": a.get("ComparisonOperator","")}

def get_argocd_recent_syncs():
    try:
        token = ssm.get_parameter(Name="/compose-portal/aiops/argocd-token", WithDecryption=True)["Parameter"]["Value"]
        import urllib.request, ssl
        req = urllib.request.Request(
            f"https://{ARGOCD_SERVER}/api/v1/applications/compose-portal-dev/events?limit=5",
            headers={"Authorization": f"Bearer {token}"})
        ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
        with urllib.request.urlopen(req, context=ctx, timeout=5) as r:
            events = json.loads(r.read()).get("items",[])
            return "\n".join([f"  - {e.get('reason','')}: {e.get('message','')} at {e.get('lastTimestamp','')}" for e in events[-5:]])
    except Exception as e:
        return f"ArgoCD history unavailable: {e}"

def classify_severity(ctx):
    name = ctx.get("alarm_name","").lower()
    if any(k in name for k in ["error-rate","5xx","crash","down"]): return "P2"
    if any(k in name for k in ["latency","cpu","memory","lag"]):    return "P3"
    return "P4"

def lambda_handler(event, context):
    log_event("incident-responder", "triggered", {"event": str(event)[:200]})
    detail     = event.get("detail", event)
    alarm_name = detail.get("alarmName") or detail.get("AlarmName") or "unknown-alarm"
    alarm_ctx  = get_alarm_context(alarm_name)
    severity   = classify_severity(alarm_ctx)
    argocd_history = get_argocd_recent_syncs()

    prompt = f"""You are the on-call SRE for EstateFlow AI (EKS ap-south-1).
ALARM: {alarm_name} | SEVERITY: {severity} | STATE: {alarm_ctx.get('state','UNKNOWN')}
REASON: {alarm_ctx.get('reason','N/A')}
METRIC: {alarm_ctx.get('namespace','')}/{alarm_ctx.get('metric','')} {alarm_ctx.get('comparison','')} {alarm_ctx.get('threshold','')}
ARGOCD RECENT EVENTS:\n{argocd_history}
PLATFORM: 4 Spring Boot 3.2 microservices on EKS 1.32. Aurora PostgreSQL, ElastiCache Redis, DocumentDB.
Provide: 1) ROOT CAUSE 2) BLAST RADIUS 3) IMMEDIATE ACTION (exact kubectl/aws commands) 4) ROLLBACK COMMAND 5) PREVENTION"""

    rca    = invoke_claude(prompt=prompt, system="You are an expert AWS EKS SRE. Give exact commands. No fluff.", model="anthropic.claude-3-5-sonnet-20241022-v2:0")
    result = {"alarm_name": alarm_name, "severity": severity, "state": alarm_ctx.get("state","UNKNOWN"), "rca": rca, "human_required": severity in ("P1","P2")}
    publish_alert(subject=f"[{severity}] Incident: {alarm_name}", message=result, severity=severity)
    log_event("incident-responder", "completed", {"alarm": alarm_name, "severity": severity})
    return {"statusCode": 200, "body": json.dumps(result, default=str)}
