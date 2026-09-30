"""access_models: routes a prompt to the right Bedrock foundation model.

Supported tasks:
- "summarize": text summarization via the text model
- "assistant": conversational / virtual-assistant replies via the text model
- "image": image generation via the image model
"""
import base64
import json
import os

import boto3

REGION = os.environ.get("REGION", "us-east-1")
TEXT_MODEL_ID = os.environ["TEXT_MODEL_ID"]
IMAGE_MODEL_ID = os.environ["IMAGE_MODEL_ID"]

bedrock = boto3.client(
    "bedrock-runtime",
    region_name=REGION,
    endpoint_url="http://localhost:4566",
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

SUPPORTED_TASKS = {"summarize", "assistant", "image"}


def _invoke_text_model(prompt):
    body = json.dumps({
        "inputText": prompt,
        "textGenerationConfig": {
            "maxTokenCount": 512,
            "temperature": 0.5,
        },
    })
    response = bedrock.invoke_model(
        modelId=TEXT_MODEL_ID,
        body=body,
        contentType="application/json",
        accept="application/json",
    )
    payload = json.loads(response["body"].read())
    results = payload.get("results", [])
    text = results[0]["outputText"] if results else ""
    return {"model": TEXT_MODEL_ID, "output": text}


def _invoke_image_model(prompt):
    body = json.dumps({
        "text_prompts": [{"text": prompt}],
        "cfg_scale": 7,
        "steps": 30,
    })
    response = bedrock.invoke_model(
        modelId=IMAGE_MODEL_ID,
        body=body,
        contentType="application/json",
        accept="application/json",
    )
    payload = json.loads(response["body"].read())
    artifacts = payload.get("artifacts", [])
    image_b64 = artifacts[0]["base64"] if artifacts else ""
    return {"model": IMAGE_MODEL_ID, "output_base64": image_b64}


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Request body must be valid JSON."}),
        }

    task = body.get("task")
    prompt = body.get("prompt")

    if task not in SUPPORTED_TASKS:
        return {
            "statusCode": 400,
            "body": json.dumps({
                "error": f"'task' must be one of {sorted(SUPPORTED_TASKS)}.",
            }),
        }

    if not prompt:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "'prompt' is required."}),
        }

    if task == "image":
        result = _invoke_image_model(prompt)
    else:
        result = _invoke_text_model(prompt)

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"task": task, **result}),
    }
