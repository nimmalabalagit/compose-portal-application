"""
EstateFlow AI — Agent Platform CDK Stack
Deploys all 10 AIOps Lambda agents + EventBridge rules + IAM roles

Deploy command (when interview scheduled):
  cd cdk/
  pip install aws-cdk-lib constructs --break-system-packages
  cdk deploy AgentPlatformStack --require-approval never

Prerequisites:
  1. Enable Bedrock model access in Console (Claude 3.5 Sonnet + Haiku)
  2. Store GitHub PAT:
     aws ssm put-parameter --name /compose-portal/agents/github-token \
       --value "ghp_xxx" --type SecureString --region ap-south-1
  3. Platform must be running (terraform apply completed)

Cost: ~$0.86/day for all 10 agents at normal usage
"""
import aws_cdk as cdk
from aws_cdk import (
    Stack, Duration,
    aws_lambda as lambda_,
    aws_iam as iam,
    aws_events as events,
    aws_events_targets as targets,
    aws_sns as sns,
    aws_ssm as ssm,
)
from constructs import Construct

ACCOUNT_ID   = "371056712467"
REGION       = "ap-south-1"
GITHUB_REPO  = "nimmalabalagit/compose-portal-application"
CLUSTER_NAME = "compose-portal-dev-eks"


class AgentPlatformStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs):
        super().__init__(scope, construct_id, **kwargs)

        # ── SNS Alert Topic ──────────────────────────────────────────────────
        alert_topic = sns.Topic(self, "AIOpsAlerts",
            topic_name="estateflowai-aiops-alerts",
            display_name="EstateFlow AI AIOps Alerts",
        )

        # ── Shared IAM Role ──────────────────────────────────────────────────
        agent_role = iam.Role(self, "AgentRole",
            role_name="estateflowai-aiops-agent-role",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole"),
            ],
        )
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="BedrockInvoke",
            actions=["bedrock:InvokeModel"],
            resources=[
                f"arn:aws:bedrock:{REGION}::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
                f"arn:aws:bedrock:{REGION}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
            ],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="SSMRead",
            actions=["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
            resources=[f"arn:aws:ssm:{REGION}:{ACCOUNT_ID}:parameter/compose-portal/*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="SNSPublish",
            actions=["sns:Publish"],
            resources=[alert_topic.topic_arn],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="CloudWatchRead",
            actions=["cloudwatch:GetMetricStatistics", "cloudwatch:DescribeAlarms",
                     "cloudwatch:GetMetricData"],
            resources=["*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="SecurityHubRead",
            actions=["securityhub:GetFindings", "securityhub:ListFindings"],
            resources=["*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="ConfigRead",
            actions=["config:DescribeComplianceByConfigRule"],
            resources=["*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="CloudTrailRead",
            actions=["cloudtrail:LookupEvents"],
            resources=["*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="CostExplorerRead",
            actions=["ce:GetCostAndUsage", "ce:GetAnomalies"],
            resources=["*"],
        ))
        agent_role.add_to_policy(iam.PolicyStatement(
            sid="S3Write",
            actions=["s3:PutObject", "s3:GetObject"],
            resources=[
                f"arn:aws:s3:::compose-portal-dev-postmortems/*",
                f"arn:aws:s3:::compose-portal-dev-compliance/*",
            ],
        ))

        # ── Common Lambda Layer ──────────────────────────────────────────────
        common_layer = lambda_.LayerVersion(self, "CommonLayer",
            layer_version_name="estateflowai-common",
            code=lambda_.Code.from_asset("../agents/lambda/common_layer"),
            compatible_runtimes=[lambda_.Runtime.PYTHON_3_12],
            description="Shared Bedrock client + SNS notifications for all AIOps agents",
        )

        common_env = {
            "ALERTS_TOPIC_ARN": alert_topic.topic_arn,
            "CLUSTER_NAME":     CLUSTER_NAME,
            "GITHUB_REPO":      GITHUB_REPO,
            "ACCOUNT_ID":       ACCOUNT_ID,
        }

        def make_lambda(name, handler_dir, timeout_min=5, memory=512, extra_env=None):
            env = {**common_env, **(extra_env or {})}
            return lambda_.Function(self, name,
                function_name=f"estateflowai-{name.lower()}",
                runtime=lambda_.Runtime.PYTHON_3_12,
                handler="handler.lambda_handler",
                code=lambda_.Code.from_asset(f"../agents/lambda/{handler_dir}"),
                role=agent_role,
                layers=[common_layer],
                timeout=Duration.minutes(timeout_min),
                memory_size=memory,
                environment=env,
            )

        # ── 10 Agent Lambda Functions ────────────────────────────────────────
        agent1  = make_lambda("IncidentResponder",  "agent1_incident")
        agent2  = make_lambda("SecurityRemediator", "agent2_security")
        agent3  = make_lambda("FinOpsOptimizer",    "agent3_finops")
        agent4  = make_lambda("PipelineDoctor",     "agent4_pipeline")
        agent5  = make_lambda("PRReviewer",         "agent5_pr_reviewer")
        agent6  = make_lambda("PostMortemWriter",   "agent6_postmortem",  timeout_min=10)
        agent7  = make_lambda("CapacityPlanner",    "agent7_capacity")
        agent8  = make_lambda("KnowledgeManager",   "agent8_knowledge")
        agent9  = make_lambda("ComplianceAgent",    "agent9_compliance",  timeout_min=10)
        agent10 = make_lambda("DeployDecision",     "agent10_deploy_decision", timeout_min=2, memory=256)

        # ── EventBridge Rules ────────────────────────────────────────────────

        # Agent 1: CloudWatch Alarm state change
        events.Rule(self, "IncidentRule",
            rule_name="estateflowai-cloudwatch-alarm",
            description="Route CloudWatch ALARM state changes to Incident Responder",
            event_pattern=events.EventPattern(
                source=["aws.cloudwatch"],
                detail_type=["CloudWatch Alarm State Change"],
                detail={"state": {"value": ["ALARM"]}},
            ),
            targets=[targets.LambdaFunction(agent1)],
        )

        # Agent 2: Security Hub finding
        events.Rule(self, "SecurityRule",
            rule_name="estateflowai-security-hub-finding",
            description="Route Security Hub CRITICAL/HIGH findings to Security Remediator",
            event_pattern=events.EventPattern(
                source=["aws.securityhub"],
                detail_type=["Security Hub Findings - Imported"],
                detail={"findings": {"Severity": {"Label": ["CRITICAL", "HIGH"]}}},
            ),
            targets=[targets.LambdaFunction(agent2)],
        )

        # Agent 3: Daily FinOps — 6 AM IST = 00:30 UTC
        events.Rule(self, "FinOpsRule",
            rule_name="estateflowai-finops-daily",
            description="Daily FinOps cost analysis at 6 AM IST",
            schedule=events.Schedule.cron(minute="30", hour="0"),
            targets=[targets.LambdaFunction(agent3)],
        )

        # Agent 7: Weekly capacity — Monday 9 AM IST = Mon 03:30 UTC
        events.Rule(self, "CapacityRule",
            rule_name="estateflowai-capacity-weekly",
            description="Weekly capacity planning every Monday 9 AM IST",
            schedule=events.Schedule.cron(minute="30", hour="3", week_day="MON"),
            targets=[targets.LambdaFunction(agent7)],
        )

        # Agent 9: Weekly compliance — Sunday 11 PM IST = Sun 17:30 UTC
        events.Rule(self, "ComplianceRule",
            rule_name="estateflowai-compliance-weekly",
            description="Weekly SOC2 evidence collection every Sunday 11 PM IST",
            schedule=events.Schedule.cron(minute="30", hour="17", week_day="SUN"),
            targets=[targets.LambdaFunction(agent9)],
        )

        # ── Outputs ──────────────────────────────────────────────────────────
        cdk.CfnOutput(self, "AlertTopicArn",    value=alert_topic.topic_arn)
        cdk.CfnOutput(self, "AgentRoleArn",     value=agent_role.role_arn)
        cdk.CfnOutput(self, "DeployDecisionFn", value=agent10.function_name,
            description="Call this Lambda from GitHub Actions for GO/NO-GO gate")


app = cdk.App()
AgentPlatformStack(app, "AgentPlatformStack",
    env=cdk.Environment(account=ACCOUNT_ID, region=REGION),
)
app.synth()
