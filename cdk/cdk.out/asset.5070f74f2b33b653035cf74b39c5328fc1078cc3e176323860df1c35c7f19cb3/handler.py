import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

def process_order(event: dict, context) -> dict:
    batch_item_failures = []
    for record in event["Records"]:
        message_id = record["messageId"]
        try:
            body = json.loads(record["body"])
            order_id = body.get("orderId")
            event_type = body.get("eventType", "UNKNOWN")
            logger.info(json.dumps({
                "orderId": order_id,
                "eventType": event_type,
                "messageId": message_id,
            }))
        except Exception as e:
            logger.error(f"Failed to process {message_id}: {e}")
            batch_item_failures.append({"itemIdentifier": message_id})
    return {"batchItemFailures": batch_item_failures}
