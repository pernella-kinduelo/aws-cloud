# ☁️ AWS EC2 — General Purpose Instances
### Concrete case: E-Learning Platform "LearnUp"

---

## 📌 Context

**LearnUp** is a startup offering online training (videos, quizzes, certificates).  
She must host her application on AWS and choose the right EC2 instance type.

---

## 🖥️ What is an EC2 instance?

An EC2 instance is **renting a virtual computer** in the AWS datacenters.  
You choose its power (CPU, RAM, network) and you pay by use.

```
┌──────────────────────────────────────────────────────┐
│            Datacenter AWS (ex: eu-west-3 Paris)      │
│                                                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐         │
│  │  LearnUp  │  │  Client B │  │  Client C │  ...    │
│  │(our app)  │  │           │  │           │         │
│  └───────────┘  └───────────┘  └───────────┘         │
│                                                      │
│         → Single shared physical server              │
│           but each instance is isolated              │
└──────────────────────────────────────────────────────┘
```

---

## ⚖️ Why General Purpose Instances?

General purpose instances offer a **balance between CPU, RAM and network**.  
They are perfect when no resource dominates others.

```
Instance Optimized Compute    Instance General Purpose    Instance Optimized Memory Instance
  ┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
  │ CPU  ████████████ ↑  │    │ CPU  ███████░░░ =    │    │ CPU  ████░░░░░░ ↓    │
  │ RAM  ████░░░░░░ ↓    │    │ RAM  ███████░░░ =    │    │ RAM  ████████████ ↑  │
  │ NET  ████░░░░░░ ↓    │    │ NET  ███████░░░ =    │    │ NET  ████████░░░ =   │
  │                      │    │                      │    │                      │
  │ Ex: video rendering, │    │ Ex: website, API,    │    │ Ex: large            │
  │ machine learning     │    │ light apps           │    │ database, cache      │
  └──────────────────────┘    └──────────────────────┘    └──────────────────────┘
```

---

## 🏗️ Architecture de LearnUp sur AWS

```
                        ┌─────────────────────────┐
                        │    Students (internet)  │
                        └────────────┬────────────┘
                                     │
                                     ▼
                        ┌─────────────────────────┐
                        │    Load Balancer AWS     │  ← distributes traffic
                        └────────────┬────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
       ┌─────────────────────┐           ┌─────────────────────┐
       │  EC2 t3.medium #1   │           │  EC2 t3.medium #2   │
       │  (Usage Général)    │           │  (Usage Général)    │
       │                     │           │                     │
       │ • Website           │           │ • Website           │
       │ • API course        │           │ • API course        │
       │ • Authentification  │           │ • Authentification  │
       └─────────────────────┘           └─────────────────────┘
                    │                                 │
                    └────────────────┬────────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │   RDS database          │  ← Handled separately
                        │    (course, users,      │
                        │       progres)          │
                        └─────────────────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │     S3 (storage)        │  ← Videos, PDFs, images
                        └─────────────────────────┘
```

---

## 📊 Instance Choice—Architect Justification

| Criterion | Analysis for LearnUp |
|---|---|
| **CPU Load** | Moderate—page rendering, REST API, quiz |
| **RAM load** | Moderate—user sessions, cache course |
| **Network** | Moderate—videos are on S3, not on EC2 |
| **Conclusion** | ✅ No dominant need Perfect General Use |

### Family T vs M—What’s the difference?

| Instance | Usage | Cost (approx.) | When to use |
|---|---|---|---|
| `t3.micro` | Test / dev | ~$8/month | Development environment |
| `t3.medium` | Light production | ~$35/month | LearnUp at launch (<500 users/day) |
| `t3.large` | Increasing production | ~$65/month | growing LearnUp (500-2000 users/day) |
| `m6i.large` | Robust production | ~$90/month | LearnUp established (>2000 users/day) |

> 💡 **Architect’s decision :** We start with `t3.medium` and we monitor with **CloudWatch**.  
> If the CPU regularly exceeds 70% on scale to `t3.large` or `m6i.large`.

---

## 🎯 General Purpose Instance Benefits for LearnUp

**1. Flexibility** — A single instance type manages the site, API, and auth without over-specialization.

**2. Controlled cost** — You don’t pay for 128 GB of RAM when you only need 4 GB.

**3. Simple scalability** — In case of a peak (e.g. start of the school year), AWS Auto Scaling can duplicate instances automatically.

**4. Scalability** — One can migrate from `t3.medium` to `m6i.large` without changing the architecture.

---

## 📈 Scalability Strategy

``>
Number of students Recommended instance Strategy
─────────────────────────────────────────────────────────
0 – 200/day t3.micro (dev/test)   1 instance
200 – 500/d t3.medium 1 instance
500 – 2000/d t3.large 2 instances + Load Balancer
2000 – 5000/j m6i.large Auto Scaling Group (2-4 instances)
5000+/j m6i.xlarge Multi-AZ + Auto Scaling
``>

---

## 📂 Project Structure

```
aws-ec2-general-purpose/
├── README.md          ← This file (documentation)
├── main.tf            ← TerraformInfrastructure
└── architecture/
    └── learnup-architecture.png  ← (to be added with draw.io)
```

---

## 🔗 Useful Resources

- [AWS EC2 Instance Types](https://aws.amazon.com/fr/ec2/instance-types/)
- [Comparateur de prix EC2](https://instances.vantage.sh/)
- [AWS Well-Architected Framework](https://aws.amazon.com/fr/architecture/well-architected/)

---

*Formation AWS Cloud Practitioner 
