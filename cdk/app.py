from aws_cdk import (
    Stack, App, Duration,
    aws_sns as sns,
    aws_sqs as sqs,
    aws_lambda as _lambda,
    aws_sns_subscriptions as sns_subs,
    aws_lambda_event_sources as lambda_events,
    aws_logs as logs,
)
from constructs import Construct

class OrderProcessingStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs):
        super().__init__(scope, id, **kwargs)

        dlq = sqs.Queue(
            self, "OrdersDLQ",
            queue_name="compose-portal-orders-dlq",
            retention_period=Duration.days(14),
        )

        order_queue = sqs.Queue(
            self, "OrdersQueue",
            queue_name="compose-portal-orders",
            visibility_timeout=Duration.seconds(180),
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=dlq,
            ),
        )

        order_topic = sns.Topic(
            self, "OrdersTopic",
            topic_name="compose-portal-order-events",
        )

        order_topic.add_subscription(
            sns_subs.SqsSubscription(
                order_queue,
                raw_message_delivery=True,
            )
        )

        order_processor = _lambda.Function(
            self, "OrderProcessor",
            function_name="compose-portal-order-processor",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="handler.process_order",
            code=_lambda.Code.from_asset("lambda/order-processor"),
            timeout=Duration.seconds(30),
            memory_size=256,
            environment={
                "ENVIRONMENT": "dev",
                "LOG_LEVEL": "INFO",
            },
            log_retention=logs.RetentionDays.ONE_MONTH,
        )

        order_queue.grant_consume_messages(order_processor)

        order_processor.add_event_source(
            lambda_events.SqsEventSource(
                order_queue,
                batch_size=10,
                max_batching_window=Duration.seconds(0),
                report_batch_item_failures=True,
            )
        )

app = App()
OrderProcessingStack(
    app, "ComposePortalOrderProcessing",
    env={"account": "371056712467", "region": "ap-south-1"},
)
app.synth()
