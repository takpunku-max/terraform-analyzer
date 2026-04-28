from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from mangum import Mangum
import boto3
import json

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://analyzer.kjdevops-portfolio.com",
    "http://localhost:5173"],
    allow_headers=["*"],
    allow_methods=["*"],
)

client = boto3.client("bedrock-runtime", region_name="us-east-1")


class AnalyzeRequest(BaseModel):
    terraform_code: str


@app.post("/analyze")
def analyze(request: AnalyzeRequest):
    if len(request.terraform_code) > 50_000:
        raise HTTPException(status_code=400, detail="Input too large")
    prompt = f"""You are a DevOps and cloud security expert. Analyze the following Terraform code and provide:
    1. Security issues and misconfigurations
    2. Cost optimization suggestions
    3. Best practices violations
    4. A plain-English summary of what the infrastructure does

    Terraform Code:
    {request.terraform_code}"""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [
            {"role": "user", "content": prompt}
        ]
    })

    try:
        response = client.invoke_model(
            modelId="us.anthropic.claude-haiku-4-5-20251001-v1:0",
            body=body
        )
        result = json.loads(response["body"].read())
        return {"analysis": result["content"][0]["text"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

handler = Mangum(app)


