# ⚡ AWS EC2 — Compute Optimized Instances
### Real-world case: LearnUp E-Learning Platform — AI Exam Correction

---

## 📌 Context

**LearnUp** is growing. The platform now offers **AI-powered automatic exam correction**.  
When 500 students submit their exams at the same time, the general purpose instance can't handle it.  
We need a dedicated instance built for **heavy computation**.

---

## ⚡ What is a Compute Optimized Instance?

A compute optimized instance puts **maximum power into the CPU**.  
It's the right choice when your application needs to perform **complex, intensive calculations**.

```
        General Purpose              Compute Optimized

        CPU ████████░░               CPU ██████████ ← pushed to the max
        RAM ████████░░               RAM █████░░░░░ ← intentionally reduced
     Network ████████░░           Network ██████░░░░

      → Balanced                    → Everything focused on raw CPU power
```

> 💡 Think of it as the difference between a versatile employee (general purpose)
> and a math expert (compute optimized) — incredible at calculations, specialized by design.

---

## 🏗️ LearnUp Architecture — Before vs After

### Before — One instance doing everything

```
        [500 students submit exams at the same time]
                            │
                            ▼
              ┌─────────────────────────┐
              │   t3.medium instance    │
              │   (General Purpose)     │
              │                         │
              │ • Website       ✅      │
              │ • Course API    ✅      │
              │ • AI Correction ❌      │  ← CPU overloaded!
              │                         │     site becomes slow
              └─────────────────────────┘
```

### After — Responsibilities separated (Architect decision)

```
        [500 students submit exams at the same time]
                            │
                            ▼
            ┌───────────────────────────┐
            │   t3.medium instance      │
            │   (General Purpose)       │
            │                           │
            │ • Website         ✅      │  ← stays fast for everyone
            │ • Course API      ✅      │
            │ • Authentication  ✅      │
            └─────────────┬─────────────┘
                          │
                          │  sends exams to be corrected
                          ▼
            ┌───────────────────────────┐
            │   c6i.large instance      │
            │   (Compute Optimized) ⚡  │
            │                           │
            │ • AI correction    ✅     │  ← built exactly for this
            │ • Answer analysis  ✅     │
            │ • Score generation ✅     │
            │ • Personal feedback ✅    │
            └───────────────────────────┘
```

---

## 📊 Instance Family

| Family | Profile |
|--------|---------|
| **C6i** (ex: c6i.large) | Intel-based, intensive computation |
| **C7g** (ex: c7g.large) | ARM Graviton processor, best price/performance ratio |
| **C6a** (ex: c6a.large) | AMD-based, great value for compute workloads |


---

## 📊 General Purpose vs Compute Optimized — Comparison

| Criteria | t3.medium (General Purpose) | c6i.large (Compute Optimized) |
|---|---|---|
| **vCPU** | 2 standard vCPUs | 2 high-performance vCPUs |
| **RAM** | 4 GB | 4 GB |
| **Cost** | ~$35/month | ~$75/month |
| **Best for** | Website, API, auth | AI correction, heavy compute |
| **Avoid when** | Intensive calculations | Storing large amounts of data |

---

## ✅ Typical Use Cases

```
AI exam correction             → ✅ Compute Optimized
Video encoding for courses     → ✅ Compute Optimized
Search engine (indexing)       → ✅ Compute Optimized
Scientific simulations         → ✅ Compute Optimized
Multiplayer game servers       → ✅ Compute Optimized

Simple website / blog          → ❌ Overkill, use General Purpose
File storage                   → ❌ Wrong choice, use S3
Large database                 → ❌ Use Memory Optimized instead
```

---

## 🎯 Benefits for LearnUp

**1. Maximum CPU power** — The CPU/RAM ratio is intentionally unbalanced in favor of CPU.  
More computing power for the same price compared to a general purpose instance.

**2. Stable and predictable performance** — Unlike T-type instances which use a "CPU credit" system,  
C-type instances deliver constant, reliable power with no surprises during peak exam periods.

**3. Cost efficiency** — A C instance completes in 1 hour what a general instance would do in 3 hours.  
You pay for less time.

**4. Separation of concerns** — The website stays fast for students while the AI correction  
runs in parallel on a dedicated instance. Best practice for a Cloud Architect.

---

## 📈 Scaling Strategy

```
Simultaneous exams per hour     Recommended instance      Strategy
──────────────────────────────────────────────────────────────────
0   – 50  exams/hour        →  t3.medium                 Shared with web server
50  – 200 exams/hour        →  c6i.large                 Dedicated correction instance
200 – 500 exams/hour        →  c6i.xlarge                Vertical scaling (more power)
500+ exams/hour             →  c6i.2xlarge + Auto Scaling Horizontal scaling (more instances)
```

---

## 📂 Project Structure

```
aws-cloud/
└── instances/
    ├── general-purpose/               ← Done
    │   ├── README.md
    │   └── main.tf
    └── compute-optimized/             ← You are here
        ├── README.md
        └── main.tf
```

---

## 🔗 Useful Resources

- [AWS EC2 Compute Optimized Instances](https://aws.amazon.com/ec2/instance-types/c6i/)
- [EC2 Price Comparator](https://instances.vantage.sh/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

*AWS Cloud Practitioner Training — Module 2: Cloud Computing*
