"""
Common notifications — SNS publish + structured JSON logging for all agents.
"""
import json, boto3, logging, os
from datetime import datetime, timezone
logger = logging.getLogger(__name__)
sns = boto3.client("sns", region_name="ap-south-1")
ALERTS_TOPIC_ARN = os.environ.get("ALERTS_TOPIC_ARN", "arn:aws:sns:ap-south-1:371056712467:estateflowai-aiops-alerts")

def publish_alert(subject, message, severity="INFO"):
    payload = {"timestamp": datetime.now(timezone.utc).isoformat(), "severity": severity, "subject": subject, **message}
    try:
        sns.publish(TopicArn=ALERTS_TOPIC_ARN, Subject=f"[{severity}] {subject}"[:100], Message=json.dumps(payload, indent=2, default=str))
    except Exception as e:
        logger.error(f"Failed to publish alert: {e}")

def log_event(agent, action, details):
    print(json.dumps({"timestamp": datetime.now(timezone.utc).isoformat(), "agent": agent, "action": action, **details}, default=str))
