"""
Common Bedrock client — shared across all 10 EstateFlow AI agents.
"""
import json
import boto3
import logging

logger = logging.getLogger(__name__)
bedrock = boto3.client("bedrock-runtime", region_name="ap-south-1")

def invoke_claude(prompt, system="You are an expert AWS DevOps engineer. Be concise and actionable.", model="anthropic.claude-3-5-sonnet-20241022-v2:0", max_tokens=2048):
    body = {"anthropic_version": "bedrock-2023-05-31", "max_tokens": max_tokens, "system": system, "messages": [{"role": "user", "content": prompt}]}
    try:
        response = bedrock.invoke_model(modelId=model, body=json.dumps(body), contentType="application/json", accept="application/json")
        return json.loads(response["body"].read())["content"][0]["text"]
    except Exception as e:
        logger.error(f"Bedrock invocation failed: {e}")
        raise
