from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from mangum import Mangum
import boto3
import json

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins = ["*"],
    allow_headers = ["*"],
    allow_methods = ["*"],
)
class AnalyzerRequest(BaseModel):
    terraform_code:str


@app.post("/analyze")
def analyzer (request: AnalyzerRequest):
    client = boto3.client("bedrock-runtime", region_name="us-east-1")

    prompt = f"""You are a DevOps and cloud security expert. Analyze the following Terraform code and provide:
    1. Security issues and misconfigurations
    2. Cost optimization suggestions
    3. Best practices violations
    4. A plain-English summary of what the infrastructure does

    Terrafrom Code:
    {request.terrafrom_code}"""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [
            {"role": "user", "content":prompt}
        ]
    })

    response = client.invoke_model(
        modelId = "anthropic.claude-3-haiku-20240307-v1:0",
        body = body
    )

    result = json.loads(response)

handler = Mangum(app)

