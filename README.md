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
     └── API Gateway (HTTP + throttling)
         └── Lambda (FastAPI + Mangum + Docker)
             └── ECR (container image registry)
             └── AWS Bedrock (Claude Haiku 4.5)

GitHub Actions
 ├── frontend-deploy.yml → build → S3 sync → CloudFront invalidation
 ├── backend-deploy.yml  → build image → push to ECR → update Lambda → health check
 └── lint.yml            → ruff (Python) + ESLint (JS) on push and PR
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
├── frontend/                   # React/Vite app
│   ├── src/
│   │   └── App.jsx             # Textarea input + analysis display
│   └── vite.config.js
├── backend/                    # FastAPI app
│   ├── main.py                 # /health + /analyze endpoints + Bedrock call
│   ├── Dockerfile              # Lambda container image
│   ├── .dockerignore           # Excludes venv, pycache, .env from image
│   └── requirements.txt        # Pinned dependencies
├── infra/                      # Terraform IaC
│   ├── backend.tf              # Remote state (S3 + DynamoDB lock)
│   ├── provider.tf             # AWS provider config
│   ├── main.tf                 # Root module — calls child modules
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Stack outputs
│   └── modules/
│       ├── storage/            # S3 bucket + OAC + public access block
│       ├── cdn/                # CloudFront + Route53
│       └── compute/            # Lambda + API Gateway + ECR + IAM + Bedrock
└── .github/
    └── workflows/
        ├── frontend-deploy.yml
        ├── backend-deploy.yml
        └── lint.yml
```

---

## Local Development

**Prerequisites:** Node 20+, Python 3.12, Docker, AWS CLI, Terraform

**Frontend:**
```bash
cd frontend
npm install
echo "VITE_API_URL=http://localhost:8000" > .env.local
npm run dev # http://localhost:5173
```

**Backend:**
```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload # http://localhost:8000
```

---

## CI/CD Pipelines

**Frontend pipeline** triggers on changes to `frontend/**`:
1. Install Node and dependencies
2. Build React app with `VITE_API_URL` injected from GitHub Secrets
3. Sync `dist/` to S3
4. Invalidate CloudFront cache

**Backend pipeline** triggers on changes to `backend/**`:
1. Build Docker image for `linux/amd64`
2. Authenticate to ECR
3. Push image tagged with `sha-run_number` to ECR
4. Update Lambda function to use new image
5. Wait for Lambda update to complete
6. Hit `/health` endpoint — fail the pipeline if not 200

**Lint pipeline** triggers on push to main and all pull requests:
1. Run ruff linter against backend Python
2. Run ESLint against frontend JavaScript
3. Both jobs must pass before a PR can be merged into main

---

## Infrastructure (Terraform)

AWS resources are defined as code across three modules in `infra/modules/`:

- **storage** — S3 private bucket + public access block + CloudFront OAC
- **cdn** — CloudFront distribution with OAC, HTTPS enforcement, custom domain + Route 53 record
- **compute** — Lambda (512MB, 60s timeout) + API Gateway (HTTP, CORS, throttling) + ECR (immutable tags, scan on push) + IAM (scoped to specific Bedrock model ARNs) + custom API domain + Route 53 record

Remote state is stored in S3 (`terraform-analyzer-tfstate-kj`) with DynamoDB locking (`terraform-analyzer-tflock`) to prevent concurrent apply conflicts.

---

## Security

- **CORS** — FastAPI middleware restricts allowed origins to production domain only, methods to GET/POST/OPTIONS, and headers to content-type
- **API Gateway throttling** — default route throttling set to burst 10 / rate 20 to protect Lambda and Bedrock from abuse
- **S3 public access block** — all public ACLs and policies explicitly blocked at the bucket level
- **ECR immutable tags** — image tags cannot be overwritten; pipeline uses `sha-run_number` format to guarantee uniqueness across retries
- **IAM least-privilege** — Lambda execution role scoped to specific Bedrock model ARNs only
- **TLS 1.2+** — CloudFront enforces TLSv1.2_2021 minimum protocol
- **Input validation** — 50,000 character limit on Terraform input to prevent Lambda timeouts and runaway Bedrock costs
- **Branch protection** — main branch requires passing lint checks and a pull request before any merge; force pushes and direct deletion blocked
- **AWS credentials** — never stored in code, injected via GitHub Secrets at build time

---

## Challenges & Solutions

**Bedrock IAM cross-region routing** — Lambda's Bedrock calls were being routed to `us-east-2` by the inference profile but the IAM policy only allowed `us-east-1`. Fixed by scoping the policy resource ARNs to all regions using wildcards while keeping model specificity.

**Docker architecture mismatch** — Mac ARM builds rejected by Lambda's `linux/amd64` runtime. Fixed with `docker buildx build --platform linux/amd64 --provenance=false` to produce a single-platform image without multi-manifest metadata that Lambda rejects.

**Input validation** — Added a 50,000 character limit on Terraform input to prevent Lambda timeouts and runaway Bedrock costs on oversized payloads.

**Wildcard certificate scope** — `*.kjdevops-portfolio.com` only covers one subdomain level. Designed the URL structure (`analyzer.` for frontend, `analyzer-api.` for backend) to stay within the single wildcard cert coverage.

**Shared CloudFront distribution** — Both projects initially shared the same CloudFront distribution, causing the analyzer frontend to break when devops-portfolio's Terraform reclaimed it. Fixed by destroying and rebuilding the analyzer infrastructure from scratch with a completely separate distribution, remote state, and module structure.

**ECR immutable tags + pipeline retry failure** — Switching ECR to immutable tags broke the pipeline on retries since the same git SHA tag already existed. Fixed by tagging images with `github.sha`-`github.run_number` — the run number increments on every attempt.

---

## What I Learned

- Integrating AWS Bedrock into a serverless FastAPI backend — invoking foundation models via the boto3 runtime client
- IAM policy scoping for AI services — restricting Lambda to specific model ARNs and inference profiles
- Terraform module design — consistent module structure across multiple projects for reusability
- Remote state management — S3 backend with DynamoDB locking
- The importance of infrastructure isolation — sharing resources across projects creates hidden dependencies that cause production outages
- DevSecOps practices — immutable image tags, throttling, input validation, and branch protection applied consistently across projects

---

## Author

**KJ** — DevOps/Cloud Engineer | AWS CCP | ITIL 4 | CompTIA A+

Currently pursuing BSIT at WGU (expected December 2026) and working as an IT Student Worker at Texas A&M University System Office.