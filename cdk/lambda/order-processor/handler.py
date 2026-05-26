# lambda/order-processor/handler.py
import json
import logging
import os
import boto3
from dataclasses import dataclass

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

secrets_client = boto3.client("secretsmanager", region_name="ap-south-1")

def process_order(event: dict, context) -> dict:
    """
    WHY report_batch_item_failures pattern:
    Return failed message IDs in batchItemFailures.
    SQS only requeues those specific messages, not the entire batch.
    Without this: one bad message causes 10 retries of all messages → duplicates.
    """
    batch_item_failures = []

    for record in event["Records"]:
        message_id = record["messageId"]
        try:
            body = json.loads(record["body"])
            order_id = body.get("orderId")
            event_type = body.get("eventType")

            logger.info(
                "Processing order event",
                extra={
                    "orderId": order_id,
                    "eventType": event_type,
                    "messageId": message_id,
                }
            )

            # Dispatch to handler based on event type
            if event_type == "ORDER_CREATED":
                _handle_order_created(body)
            elif event_type == "ORDER_STATUS_CHANGED":
                _handle_order_status_changed(body)
            else:
                logger.warning(f"Unknown event type: {event_type}")

        except Exception as e:
            logger.error(
                f"Failed to process message {message_id}: {e}",
                exc_info=True,
            )
            # Add to failed items — SQS will retry only this message
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}

def _handle_order_created(order: dict) -> None:
    """Send email notification, update analytics, etc."""
    logger.info(f"Order created: {order.get('orderId')}")
    # In production: send SES email, update DynamoDB analytics table, etc.

def _handle_order_status_changed(order: dict) -> None:
    logger.info(f"Order {order.get('orderId')} → {order.get('status')}")