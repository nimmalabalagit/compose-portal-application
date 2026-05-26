# cdk/app.py
# WHY CDK Python for this component:
# The SNS+SQS+Lambda async pipeline is a greenfield component — nothing exists yet.
# CDK Python is faster to write for AWS-native serverless patterns than Terraform.
# Both coexist: Terraform manages persistent infrastructure (EKS, VPC, RDS).
# CDK manages event-driven components (Lambda, SNS, SQS, EventBridge).
# This is the correct "right tool" answer for interviewers who ask why mix IaC tools.

from aws_cdk import (
    Stack, App, Duration, RemovalPolicy,
    aws_sns as sns,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_sns_subscriptions as sns_subs,
    aws_lambda_event_sources as lambda_events,
    aws_iam as iam,
    aws_logs as logs,
)
from constructs import Construct

class OrderProcessingStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        # Dead Letter Queue — where failed messages go after 3 processing attempts
        # WHY DLQ: Without it, a poison pill message loops forever:
        # Lambda fails → message returns to SQS → Lambda retries → fails → loop
        # DLQ catches messages after maxReceiveCount=3 → alerts can fire on DLQ depth
        dlq = sqs.Queue(
            self, "OrdersDLQ",
            queue_name="orders-processing-dlq",
            retention_period=Duration.days(14),  # 14 days to investigate failures
            encryption=sqs.QueueEncryption.KMS_MANAGED,
        )

        # Main processing queue
        # WHY visibility_timeout = 6× Lambda timeout:
        # Lambda has 30s timeout. If Lambda takes 29s and crashes, the message
        # becomes visible again and retries. visibility_timeout = 6× timeout (AWS best practice)
        # prevents concurrent processing of the same message.
        order_queue = sqs.Queue(
            self, "OrdersQueue",
            queue_name="orders-processing",
            visibility_timeout=Duration.seconds(180),  # 6× Lambda 30s timeout
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,  # 3 failures → moves to DLQ
                queue=dlq,
            ),
            encryption=sqs.QueueEncryption.KMS_MANAGED,
        )

        # SNS topic (order-service publishes here)
        order_topic = sns.Topic(
            self, "OrdersTopic",
            topic_name="compose-portal-orders",
        )

        # Subscribe SQS to SNS (fan-out pattern)
        order_topic.add_subscription(
            sns_subs.SqsSubscription(
                order_queue,
                raw_message_delivery=True,  # WHY: Without this, SQS message body is SNS envelope
                                            # Lambda must parse SNS → SQS wrapper = extra complexity
                                            # raw_message_delivery=True sends the order JSON directly
            )
        )

        # Lambda function (Python)
        order_processor = _lambda.Function(
            self, "OrderProcessor",
            function_name="compose-portal-order-processor",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="handler.process_order",
            code=_lambda.Code.from_asset("lambda/order-processor"),
            timeout=Duration.seconds(30),
            memory_size=256,
            environment={
                "DB_SECRET_ARN": "arn:aws:secretsmanager:ap-south-1:371056712467:secret:compose-portal/rds",
                "NOTIFICATION_TABLE": "order-notifications",
                "LOG_LEVEL": "INFO",
            },
            log_retention=logs.RetentionDays.ONE_MONTH,
        )

        # Grant Lambda permissions
        order_queue.grant_consume_messages(order_processor)

        # IRSA-equivalent for Lambda: IAM role with RDS Data API + Secrets Manager
        order_processor.add_to_role_policy(iam.PolicyStatement(
            actions=[
                "secretsmanager:GetSecretValue",
                "rds-data:ExecuteStatement",
            ],
            resources=[
                "arn:aws:secretsmanager:ap-south-1:371056712467:secret:compose-portal/*",
                "arn:aws:rds:ap-south-1:371056712467:cluster:*",
            ],
        ))

        # SQS trigger for Lambda (event source mapping)
        order_processor.add_event_source(
            lambda_events.SqsEventSource(
                order_queue,
                batch_size=10,
                # WHY max_batching_window:
                # Lambda waits up to 5 minutes before triggering if batch isn't full.
                # For order processing (latency-sensitive), use 0 = trigger immediately.
                max_batching_window=Duration.seconds(0),
                report_batch_item_failures=True,  # WHY: Allows partial batch success
                                                   # If 9/10 messages succeed and 1 fails,
                                                   # only the failed message goes back to SQS
                                                   # Without this: all 10 retry = 9 duplicate processes
            )
        )

# Lambda handler
app = App()
OrderProcessingStack(
    app, "ComposePortalOrderProcessing",
    env={"account": "371056712467", "region": "ap-south-1"},
)
app.synth()