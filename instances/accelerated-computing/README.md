# 🚀 AWS EC2 — Accelerated Computing Instances
### Real-world case: LearnUp E-Learning Platform — AI Recommendation Engine

---

## 📌 Context

**LearnUp** wants to go further. The platform launches a **personalized course
recommendation engine**: by analyzing each student's behavior, the AI suggests
the most relevant next courses for their profile.

Training this AI model requires **billions of calculations**.
No CPU can do this efficiently — we need a **GPU**.

---

## 🚀 What is an Accelerated Computing Instance?

An accelerated computing instance adds a **GPU** (Graphics Processing Unit)
alongside the classic CPU. It is the right choice for **massively parallel workloads**
like AI training, 3D rendering, and image recognition.

The four instance types compared:

| Resource | General Purpose | Compute Optimized | Memory Optimized | Accelerated Computing |
|----------|----------------|-------------------|-----------------|----------------------|
| CPU | standard | high-performance | standard | standard |
| RAM | balanced | reduced | maximum | large |
| GPU | none | none | none | maximum |
| Focus | Balance | CPU power | RAM capacity | GPU power |

---

## ⚡ CPU vs GPU — The key concept

**CPU — 8 powerful cores:**

    [■] [■] [■] [■]
    [■] [■] [■] [■]
    
    -> Few cores, very powerful
    -> Great for complex sequential tasks

**GPU — thousands of small cores:**

    [■][■][■][■][■][■][■][■][■][■][■][■][■][■][■][■]
    [■][■][■][■][■][■][■][■][■][■][■][■][■][■][■][■]
    [■][■][■][■][■][■][■][■][■][■][■][■][■][■][■][■]
    ... (thousands of cores working ALL at the same time)
    
    -> Thousands of small cores
    -> Great for millions of simple parallel calculations

> 💡 Think of building a brick wall. The CPU is 8 expert bricklayers,
> very fast. The GPU is 10,000 apprentices placing one brick each
> at the same time. For massive repetitive tasks, the 10,000 win.

---

## ⏱️ Real Impact — AI Training With vs Without GPU

Training data for LearnUp's recommendation model:
- 50,000 students
- 2 years of history
- 500 available courses
- Scores, time spent, drop-off rates

**Without GPU:**

    c6i.large (CPU only)
    Estimated time : 72 hours
    Cost           : 72h x $0.10 = $7.20
    Problem        : 3 days of waiting -> not acceptable

**With GPU:**

    g5.xlarge (Accelerated Computing)
    Estimated time : 2 hours
    Cost           : 2h x $32 = $64
    Result         : model ready in 2 hours -> ship it!

> 💡 Architect decision: paying more per hour but finishing 36x faster
> is almost always the right call for AI training workloads.

---

## 🏗️ LearnUp Full Architecture

    [Students on the platform]
                |
                v
    +---------------------------+
    |   t3.medium               |
    |   (General Purpose)       |
    |  Website, API, Auth  [OK] |
    +----------+----------------+
               |
    +----------+----------+
    |                     |
    v                     v
+---------------+   +---------------------+
|  c6i.large    |   |  r6i.large          |
| (Compute      |   |  (Memory Optimized) |
|  Optimized)   |   |  Live stats    [OK] |
|  AI exams[OK] |   |  Data cache    [OK] |
+---------------+   +---------------------+

    [Background — AI training, runs at night]
                |
                v
    +---------------------------+
    |   g5.xlarge               |
    |   (Accelerated Computing) |
    |                           |
    |  Model training      [OK] |
    |  Course recommendations   |
    |  Behavior analysis   [OK] |
    +---------------------------+
    
    -> Runs at night to save costs
    -> Instance is STOPPED once training is done
    -> We only pay for the 2 hours of use

---

## 📊 Instance Family

| Family | Profile |
|--------|---------|
| **P4d** (ex: p4d.24xlarge) | Deep learning, most powerful, highest cost |
| **G5** (ex: g5.xlarge) | AI inference + rendering, best value to start |
| **Inf2** (ex: inf2.xlarge) | AWS Inferentia chip, optimized for AI inference |
| **Trn1** (ex: trn1.2xlarge) | AWS Trainium chip, optimized for AI training |

> 💡 The **P** stands for **P**arallel computing, **G** for **G**PU — easy to remember!
> AWS custom chips (Inferentia, Trainium) are 30-40% cheaper than classic GPUs.

---

## 📊 All Four Instances — Full Comparison

| Criteria | t3.medium | c6i.large | r6i.large | g5.xlarge |
|---|---|---|---|---|
| **Type** | General Purpose | Compute Optimized | Memory Optimized | Accelerated Computing |
| **CPU** | 2 standard | 2 high-perf | 2 standard | 4 standard |
| **RAM** | 4 GB | 4 GB | 16 GB | 16 GB |
| **GPU** | None | None | None | NVIDIA A10G |
| **Cost** | ~$35/month | ~$75/month | ~$120/month | ~$1/hour |
| **LearnUp role** | Website + API | AI correction | Live stats | AI training |

> 💡 The g5.xlarge is billed per hour — turn it on, train the model, turn it off.
> No need to pay 24/7!

---

## ✅ Typical Use Cases

**Good fit:**
- AI model training / Machine Learning
- Course recommendation engine
- Video rendering and special effects
- 3D scientific simulation
- Image or voice recognition
- AI image generation

**Not a good fit:**
- Classic website -> use General Purpose
- Large database -> use Memory Optimized
- Classic CPU tasks -> use Compute Optimized
- File storage -> use S3

---

## 🎯 Key Benefits for LearnUp

**1. Massively parallel calculations** — A GPU performs millions of operations
simultaneously. What would take 72 hours on a CPU takes 2 hours on a GPU.

**2. Essential for modern AI** — Training a recommendation model without a GPU
is like digging a tunnel with a spoon. The GPU is the right tool for the job.

**3. Cost control through on/off strategy** — Unlike the other instances that
run 24/7, the GPU instance is only ON during training. Architect decision:
schedule training at night, stop the instance at dawn.

**4. AWS custom chips** — Inferentia and Trainium chips are purpose-built
by AWS for AI workloads, offering better price/performance than classic GPUs.

---

## 📈 Scaling Strategy

| Workload | Recommended instance | Billing strategy |
|---|---|---|
| Model testing / dev | g5.xlarge | On-demand, ~2h/run |
| Weekly model retraining | g5.2xlarge | Scheduled, nights only |
| Daily retraining | g5.4xlarge | Reserved instance (cheaper) |
| Real-time inference | inf2.xlarge | Always on, optimized chip |

---

## 📂 Project Structure

    aws-cloud/
    └── instances/
        ├── general-purpose/        <- Done
        │   ├── README.md
        │   └── main.tf
        ├── compute-optimized/      <- Done
        │   ├── README.md
        │   └── main.tf
        ├── memory-optimized/       <- Done
        │   ├── README.md
        │   └── main.tf
        └── accelerated-computing/  <- You are here
            ├── README.md
            └── main.tf

---

## 🔗 Useful Resources

- [AWS EC2 Accelerated Computing](https://aws.amazon.com/ec2/instance-types/g5/)
- [AWS Trainium](https://aws.amazon.com/machine-learning/trainium/)
- [AWS Inferentia](https://aws.amazon.com/machine-learning/inferentia/)
- [EC2 Price Comparator](https://instances.vantage.sh/)

---

*AWS Cloud Practitioner Training — Module 2: Cloud Computing*
