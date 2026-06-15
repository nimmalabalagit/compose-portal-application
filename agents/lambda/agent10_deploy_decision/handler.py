"""
Agent 10: Deployment Decision Agent
Trigger: GitHub Actions calls this Lambda as GO/NO-GO gate before ArgoCD prod sync
Action:  Check SLOs + Security Hub + active alarms -> Bedrock decision -> return GO/NO-GO
"""
import json, boto3, os, logging
from datetime import datetime, timezone, timedelta
from common.bedrock_client import invoke_claude
from common.notifications import log_event

logger = logging.getLogger(); logger.setLevel(logging.INFO)
cw = boto3.client("cloudwatch",  region_name="ap-south-1")
sh = boto3.client("securityhub", region_name="ap-south-1")
CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "compose-portal-dev-eks")
SERVICES     = ["gateway","user","product","order"]

def get_error_rate(service, minutes=30):
    end = datetime.now(timezone.utc); start = end - timedelta(minutes=minutes)
    resp = cw.get_metric_statistics(Namespace="EstateFlowAI/Services", MetricName="ErrorRate",
        Dimensions=[{"Name":"ClusterName","Value":CLUSTER_NAME},{"Name":"Service","Value":service}],
        StartTime=start, EndTime=end, Period=minutes*60, Statistics=["Average"])
    pts = resp.get("Datapoints",[]); return pts[0]["Average"] if pts else 0.0

def get_active_alarms():
    resp = cw.describe_alarms(StateValue="ALARM", MaxRecords=20)
    return [a["AlarmName"] for a in resp.get("MetricAlarms",[])]

def get_critical_findings_count():
    try:
        resp = sh.get_findings(Filters={"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}],"WorkflowStatus":[{"Value":"NEW","Comparison":"EQUALS"}]}, MaxResults=10)
        return len(resp.get("Findings",[]))
    except Exception:
        return 0

def lambda_handler(event, context):
    log_event("deploy-decision", "triggered", {})
    body        = event.get("body", event); body = json.loads(body) if isinstance(body, str) else body
    service     = body.get("service","all"); image_sha = body.get("image_sha","unknown")
    deploy_env  = body.get("environment","production")
    active_alarms   = get_active_alarms()
    critical_sec    = get_critical_findings_count()
    error_rates     = {svc: get_error_rate(svc) for svc in SERVICES}
    any_high_errors = any(r > 1.0 for r in error_rates.values())

    hard_blocks = []
    if active_alarms:         hard_blocks.append(f"Active alarms: {', '.join(active_alarms[:3])}")
    if critical_sec > 0:      hard_blocks.append(f"{critical_sec} unresolved CRITICAL Security Hub findings")
    if any_high_errors:       hard_blocks.append(f"High error rates: {[s for s,r in error_rates.items() if r>1.0]}")

    if hard_blocks:
        result = {"decision":"NO-GO","reason":"Hard blocks present","blocks":hard_blocks,"human_required":True}
        log_event("deploy-decision","no-go-hard-block",result)
        return {"statusCode":200,"body":json.dumps(result)}

    prompt = f"""You are the deployment gatekeeper for EstateFlow AI.
SERVICE: {service} | IMAGE: {image_sha} | ENV: {deploy_env}
Active Alarms: {len(active_alarms)} (none) | Critical Security Findings: {critical_sec}
Error Rates (30min): {json.dumps(error_rates)}
Current UTC: {datetime.now(timezone.utc).strftime('%H:%M')} (IST = UTC+5:30)
All hard blocks cleared. Make GO/NO-GO recommendation.
Respond ONLY with this JSON (no other text):
{{"decision":"GO or NO-GO","confidence":"HIGH or MEDIUM or LOW","reason":"one sentence","conditions":[],"deploy_window":"immediate or wait-X-minutes or reschedule"}}"""

    ai_response = invoke_claude(prompt=prompt, system="You are a deployment safety officer. Respond ONLY with the JSON object. No markdown.", model="anthropic.claude-3-haiku-20240307-v1:0", max_tokens=256)
    try:
        decision_data = json.loads(ai_response.strip())
    except Exception:
        decision_data = {"decision":"NO-GO","confidence":"LOW","reason":"AI response parse failed — defaulting to safe NO-GO","conditions":[],"deploy_window":"reschedule"}

    decision_data.update({"image_sha":image_sha,"service":service,"active_alarms":len(active_alarms),"critical_sec":critical_sec,"human_required":decision_data.get("confidence")=="LOW"})
    log_event("deploy-decision","decision-made",decision_data)
    return {"statusCode":200,"body":json.dumps(decision_data)}
