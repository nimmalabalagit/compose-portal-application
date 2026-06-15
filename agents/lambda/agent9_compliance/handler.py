"""
Agent 9: Compliance Agent
Trigger: Weekly Sunday 11 PM IST (EventBridge schedule)
Action:  Collect Security Hub scores + Config compliance -> SOC2 evidence -> S3
"""
import json, boto3, os, logging
from datetime import datetime, timezone
from common.bedrock_client import invoke_claude
from common.notifications import publish_alert, log_event

logger = logging.getLogger(); logger.setLevel(logging.INFO)
sh  = boto3.client("securityhub", region_name="ap-south-1")
cfg = boto3.client("config",      region_name="ap-south-1")
s3  = boto3.client("s3",          region_name="ap-south-1")
EVIDENCE_BUCKET = os.environ.get("EVIDENCE_BUCKET", "compose-portal-dev-compliance")
ACCOUNT_ID      = os.environ.get("ACCOUNT_ID", "371056712467")

def get_security_hub_score():
    try:
        resp     = sh.get_findings(Filters={"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],"WorkflowStatus":[{"Value":"NEW","Comparison":"EQUALS"}]}, MaxResults=100)
        findings = resp.get("Findings",[])
        by_sev   = {"CRITICAL":0,"HIGH":0,"MEDIUM":0,"LOW":0}
        for f in findings:
            sev = f.get("Severity",{}).get("Label","LOW"); by_sev[sev] = by_sev.get(sev,0)+1
        return {"total_active": len(findings), "by_severity": by_sev}
    except Exception as e:
        return {"error": str(e)}

def get_config_compliance():
    try:
        resp       = cfg.describe_compliance_by_config_rule()
        rules      = resp.get("ComplianceByConfigRules",[])
        compliant  = sum(1 for r in rules if r.get("Compliance",{}).get("ComplianceType")=="COMPLIANT")
        non_comp   = sum(1 for r in rules if r.get("Compliance",{}).get("ComplianceType")=="NON_COMPLIANT")
        return {"compliant": compliant, "non_compliant": non_comp, "total": len(rules)}
    except Exception as e:
        return {"error": str(e)}

def lambda_handler(event, context):
    log_event("compliance-agent", "triggered", {"schedule": "weekly-sunday"})
    sh_score    = get_security_hub_score()
    cfg_summary = get_config_compliance()
    timestamp   = datetime.now(timezone.utc)

    prompt = f"""Generate a weekly compliance evidence summary for EstateFlow AI (personal EKS lab, ap-south-1).
SECURITY HUB: {json.dumps(sh_score, indent=2)}
AWS CONFIG: {json.dumps(cfg_summary, indent=2)}
CONTROLS ACTIVE: Security Hub FSBP+CIS 1.4.0, GuardDuty, Inspector v2, CloudTrail, IRSA, ESO (no secrets in Git).
Provide: 1) OVERALL POSTURE (score/100) 2) CRITICAL/HIGH FINDINGS (top 3) 
3) SOC2 CONTROL MAPPING (CC6.1 CC6.2 CC7.2 CC8.1 each with status) 
4) ACTION ITEMS (3 specific fixes) 5) EVIDENCE STATEMENT (audit paragraph)
Format as markdown."""

    report = invoke_claude(prompt=prompt, system="You are a cloud compliance specialist. Map findings to SOC2 controls precisely.", model="anthropic.claude-3-5-sonnet-20241022-v2:0")
    evidence = {"timestamp": timestamp.isoformat(), "account_id": ACCOUNT_ID, "security_hub": sh_score, "config_compliance": cfg_summary, "ai_report": report}
    s3_key = f"weekly-evidence/{timestamp.strftime('%Y/%m/%d')}/compliance-report.json"
    try:
        s3.put_object(Bucket=EVIDENCE_BUCKET, Key=s3_key, Body=json.dumps(evidence, indent=2, default=str).encode(), ContentType="application/json")
    except Exception as e:
        logger.warning(f"S3 upload failed: {e}")

    critical_count = sh_score.get("by_severity",{}).get("CRITICAL",0)
    publish_alert(subject=f"[Compliance] Weekly Report — {critical_count} CRITICAL", message={"sh_score": sh_score, "config": cfg_summary, "s3_key": s3_key}, severity="CRITICAL" if critical_count>0 else "INFO")
    return {"statusCode": 200, "body": json.dumps({"s3_key": s3_key, "critical_findings": critical_count}, default=str)}
