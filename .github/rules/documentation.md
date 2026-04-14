# Documentation Conventions

## `PROJECT_SUMMARY.md`

Include these sections (in order):

1. **Title** — `# <Project Name> - Project Summary`
2. **📁 File Structure** — tree diagram
3. **📊 Project Overview** — table (Name, Description, Use Case, Complexity ⭐, Deployment Time)
4. **🎯 Key Features** — bulleted ✅ list
5. **🚀 Quick Start Commands** — PowerShell examples
6. **🔧 Technical Specifications** — resource details
7. **🎨 Architecture Diagram** — ASCII box diagram

## `Readme.md`

Include these sections (in order):

1. **Title** with emoji — `# 🏗️ <Project Name>`
2. **🎯 Overview** — 2–3 sentence description
3. **🏛️ Architecture** — ASCII diagram + component list
4. **📋 Features** — bullet list
5. **🔧 Parameters** — markdown table (Name | Type | Default | Description)
6. **🚀 Quick Deploy** — step-by-step CLI commands
7. **🧪 Testing** — how to verify the deployment
8. **💰 Estimated Cost** — monthly cost breakdown
9. **📚 References** — links to Azure docs

## Architecture Diagrams

Use Unicode box-drawing characters:

```
┌─────────────────────────────────────┐
│  Azure Resource Group               │
│  ┌───────────────────────────────┐  │
│  │  Virtual Network (10.0.0.0/16)│  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Subnet (10.0.0.0/24)  │  │  │
│  │  │  ┌───────┐ ┌───────┐   │  │  │
│  │  │  │  VM1  │ │  VM2  │   │  │  │
│  │  │  └───────┘ └───────┘   │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```
