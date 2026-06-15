"""
Agent 8: Knowledge Manager
Trigger: Post-incident SNS notification -> Lambda
Action:  Extract learnings from post-mortem -> update RUNBOOK.md -> GitHub commit
"""
import json, boto3, os, logging, urllib.request, base64
from common.bedrock_client import invoke_claude
from common.notifications import log_event

logger = logging.getLogger(); logger.setLevel(logging.INFO)
ssm = boto3.client("ssm", region_name="ap-south-1")
GITHUB_REPO  = os.environ.get("GITHUB_REPO", "nimmalabalagit/compose-portal-application")
RUNBOOK_PATH = "docs/RUNBOOK.md"

def get_github_token():
    return ssm.get_parameter(Name="/compose-portal/agents/github-token", WithDecryption=True)["Parameter"]["Value"]

def get_file(token, path):
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{GITHUB_REPO}/contents/{path}",
            headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.v3+json"})
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read()); return base64.b64decode(data["content"]).decode(), data["sha"]
    except Exception:
        return "# EstateFlow AI Runbook\n\n## Known Issues\n\n", ""

def update_file(token, path, content, sha, message):
    encoded = base64.b64encode(content.encode()).decode()
    payload = {"message": message, "content": encoded}
    if sha: payload["sha"] = sha
    req = urllib.request.Request(f"https://api.github.com/repos/{GITHUB_REPO}/contents/{path}",
        data=json.dumps(payload).encode(), method="PUT",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.v3+json", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read()).get("commit",{}).get("html_url","")

def lambda_handler(event, context):
    log_event("knowledge-manager", "triggered", {})
    records     = event.get("Records",[{}])
    sns_message = records[0].get("Sns",{}).get("Message","{}")
    body        = json.loads(sns_message) if isinstance(sns_message, str) else sns_message
    incident_id = body.get("incident_id","UNKNOWN")
    postmortem  = body.get("postmortem_text", body.get("rca","No post-mortem text provided"))

    prompt = f"""Extract reusable runbook entries from this incident for EstateFlow AI.
INCIDENT: {incident_id}
POST-MORTEM:\n{str(postmortem)[:3000]}
For each distinct issue, provide this EXACT format:
### Issue: [short name]
**Symptoms:** [what engineer sees]
**Root Cause:** [1-2 sentences]
**Resolution:**
```bash
# exact fix commands
```
**Prevention:** [config change or alert]
**Labels:** [kubernetes|docker|aws|database|networking|ci-cd]
Only include reusable knowledge, not incident-specific details."""

    new_entries = invoke_claude(prompt=prompt, system="You are a technical writer extracting reusable runbook knowledge.", model="anthropic.claude-3-5-sonnet-20241022-v2:0", max_tokens=1500)
    try:
        token           = get_github_token()
        existing, sha   = get_file(token, RUNBOOK_PATH)
        updated_content = existing + f"\n\n---\n<!-- Added after {incident_id} -->\n{new_entries}\n"
        commit_url      = update_file(token, RUNBOOK_PATH, updated_content, sha, f"docs: add runbook entries from {incident_id} [automated]")
        log_event("knowledge-manager", "runbook_updated", {"commit": commit_url})
    except Exception as e:
        commit_url = f"Update failed: {e}"; logger.error(commit_url)

    return {"statusCode": 200, "body": json.dumps({"incident_id": incident_id, "runbook_commit": commit_url}, default=str)}
