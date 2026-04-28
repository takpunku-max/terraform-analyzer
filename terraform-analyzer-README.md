# Terraform Analyzer

> An AI-powered Terraform security and cost analysis tool built on AWS serverless infrastructure.

🌐 **Live:** [analyzer.kjdevops-portfolio.com](https://analyzer.kjdevops-portfolio.com)

---

## What It Does

Paste any Terraform code into the analyzer and get back:

- 🔴 **Security issues** — misconfigurations, overly permissive IAM, exposed resources
- 💰 **Cost optimization** — storage class recommendations, right-sizing suggestions
- ⚠️ **Best practices violations** — missing tags, hardcoded values, state management issues
- 📋 **Plain-English summary** — what the infrastructure actually does
- ✅ **Corrected code** — fixed Terraform with explanations

---

## Architecture

```
Browser
  └── Route 53 (DNS)
        └── analyzer.kjdevops-portfolio.com
              └── CloudFront (CDN + HTTPS)
                    └── S3 (React/Vite static frontend)

Browser (API calls)
  └── analyzer-api.kjdevops-portfolio.com
        └── API Gateway (HTTP)
              └── Lambda (FastAPI + Mangum + Docker)
                    └── ECR (container image registry)
                          └── AWS Bedrock (Claude Haiku 4.5)

GitHub Actions
  ├── frontend-deploy.yml  →  build → S3 sync → CloudFront invalidation
  └── backend-deploy.yml   →  build image → push to ECR → update Lambda
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Vite |
| Backend | FastAPI, Python 3.12, Mangum |
| AI | AWS Bedrock — Claude Haiku 4.5 |
| Containerization | Docker, AWS ECR |
| Serverless | AWS Lambda, API Gateway |
| CDN | AWS CloudFront |
| Storage | AWS S3 |
| DNS + SSL | AWS Route 53, ACM (wildcard cert) |
| IaC | Terraform |
| CI/CD | GitHub Actions |

---

## Project Structure

```
terraform-analyzer/
├── frontend/               # React/Vite app
│   ├── src/
│   │   └── App.jsx         # Textarea input + analysis display
│   └── vite.config.js
├── backend/                # FastAPI app
│   ├── main.py             # /analyze endpoint + Bedrock call
│   ├── Dockerfile          # Lambda container image
│   └── requirements.txt
├── infra/                  # Terraform IaC
│   └── main.tf             # All AWS resources
└── .github/
    └── workflows/
        ├── frontend-deploy.yml
        └── backend-deploy.yml
```

---

## Local Development

**Prerequisites:** Node 20+, Python 3.12, Docker, AWS CLI, Terraform

**Frontend:**
```bash
cd frontend
npm install
echo "VITE_API_URL=http://localhost:8000" > .env.local
npm run dev                  # http://localhost:5173
```

**Backend:**
```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload    # http://localhost:8000
```

---

## CI/CD Pipelines

**Frontend pipeline** triggers on changes to `frontend/**`:
1. Checkout code
2. Install Node and dependencies
3. Build React app with `VITE_API_URL` injected from GitHub Secrets
4. Sync `dist/` to S3
5. Invalidate CloudFront cache

**Backend pipeline** triggers on changes to `backend/**`:
1. Configure AWS credentials
2. Authenticate to ECR
3. Build Docker image for `linux/amd64`
4. Push image to ECR
5. Update Lambda function to use new image

---

## Infrastructure (Terraform)

All AWS resources are defined as code in `infra/main.tf`:

- **ECR** — private container registry with vulnerability scanning on push
- **Lambda** — 512MB, 60s timeout (increased for AI inference latency)
- **API Gateway** — HTTP API with CORS configured for the frontend domain
- **Custom domain** — `analyzer-api.kjdevops-portfolio.com` via ACM wildcard cert
- **IAM** — least-privilege Lambda execution role scoped to specific Bedrock model ARNs
- **S3** — private bucket for frontend static files
- **CloudFront** — CDN with OAC, HTTPS enforcement, custom domain
- **Route 53** — DNS records for both frontend and API subdomains

---

## Challenges & Solutions

**Bedrock IAM cross-region routing** — Lambda's Bedrock calls were being routed to `us-east-2` by the inference profile but the IAM policy only allowed `us-east-1`. Fixed by scoping the policy resource ARNs to all regions using wildcards while keeping model specificity.

**Docker architecture mismatch** — Mac ARM builds rejected by Lambda's `linux/amd64` runtime. Fixed with `docker buildx build --platform linux/amd64 --provenance=false` to produce a single-platform image without multi-manifest metadata that Lambda rejects.

**Input validation** — Added a 50,000 character limit on Terraform input to prevent Lambda timeouts and runaway Bedrock costs on oversized payloads.

**Wildcard certificate scope** — `*.kjdevops-portfolio.com` only covers one subdomain level. Designed the URL structure (`analyzer.` for frontend, `analyzer-api.` for backend) to stay within the single wildcard cert coverage.

---

## Security Considerations

- Lambda execution role scoped to specific Bedrock model ARNs only
- No marketplace permissions on the Lambda role
- S3 bucket private — only accessible via CloudFront OAC
- CORS locked to the production frontend domain
- Input size validation to prevent abuse
- AWS credentials never stored in code — injected via GitHub Secrets at build time

---

## Author

**KJ** — Aspiring DevOps Engineer | AWS CCP | ITIL 4 | CompTIA A+

Currently pursuing BSIT at WGU (expected Summer 2026) and working as an IT Student Worker at Texas A&M University System Office.
