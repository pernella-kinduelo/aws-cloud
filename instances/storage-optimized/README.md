# 💾 AWS EC2 — Storage Optimized Instances
### Real-world case: LearnUp E-Learning Platform — Real-Time Log Analytics

---

## 📌 Context

**LearnUp** now generates millions of events every day:
every click, every video watched, every quiz error, every course drop-off.

The team wants to analyze these events in **near real-time** to detect
problems immediately — a slow course, a broken video, a confusing quiz.

This requires reading and writing **millions of times per second** to disk.
A classic instance with a network disk (EBS) is too slow.
We need storage that is **physically inside the server**.

---

## 💾 What is a Storage Optimized Instance?

A storage optimized instance has **NVMe SSD drives physically built in**
to the server — no network in between. It is the right choice when your
application needs to **read and write massive amounts of data as fast as possible**.

All five instance types compared:

| Resource | General Purpose | Compute Optimized | Memory Optimized | Accelerated Computing | Storage Optimized |
|----------|----------------|-------------------|-----------------|----------------------|-------------------|
| CPU | standard | high-perf | standard | standard | standard |
| RAM | balanced | reduced | maximum | large | large |
| GPU | none | none | none | maximum | none |
| Disk | standard | standard | standard | standard | NVMe max |
| Focus | Balance | CPU power | RAM capacity | GPU power | Disk speed |

---

## ⚡ Classic Storage vs Storage Optimized — The key concept

**Classic instance with EBS (network disk):**

    Instance EC2 <---- network ----> EBS disk
                   (1ms latency)
    
    -> Data travels through the network before arriving
    -> Fast enough for most use cases
    -> Data is safe even if instance stops

**Storage optimized instance with local NVMe:**

    Instance EC2 <-- directly connected --> NVMe SSD
                    (100 microseconds)
    
    -> Data is physically inside the server
    -> 10x faster than EBS
    -> WARNING: data is lost if instance stops

> 💡 Think of the difference between having your tools in a warehouse
> 5 minutes away (EBS) versus directly on your desk (NVMe).
> For some jobs, this difference changes everything.

---

## 📊 Classic Storage vs Storage Optimized — Numbers

| Criteria | EBS (network disk) | NVMe local (storage optimized) |
|---|---|---|
| **Latency** | ~1 ms | ~100 microseconds (10x faster) |
| **Max IOPS** | 64,000 | 1,000,000+ |
| **Data persistence** | Safe if instance stops | Lost if instance stops |
| **Cost** | Moderate | High |
| **Best for** | General use | Intensive data processing |

> ⚠️ Critical point: local NVMe storage is ephemeral.
> A good architect always backs up important data to S3 or EBS regularly.

---

## 🏗️ LearnUp — The log analytics problem

LearnUp generates this every single day:

    50,000 students
    x 200 actions per student per day
    = 10,000,000 events per day
    = 115 events per second
    -> Millions of disk reads/writes per hour

**Without storage optimized:**

    Classic instance + EBS
    
    Write logs  -> goes through network -> EBS -> slow
    Read logs   -> goes through network -> EBS -> slow
    
    Result: analysis takes hours
            problems detected too late

**With storage optimized:**

    i4i.xlarge + local NVMe
    
    Write logs  -> directly to NVMe -> instant
    Read logs   -> directly from NVMe -> instant
    
    Result: analysis runs in minutes
            problems detected immediately

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
    +----------+----------+----------+
    |           |                    |
    v           v                    v
+----------+ +----------+  +----------------------+
| c6i.large| |r6i.large |  | i4i.xlarge           |
| (Compute | |(Memory   |  | (Storage Optimized)  |
| Optimized| |Optimized)|  |                      |
| AI exams | |Stats [OK]|  | Event logs      [OK] |
| [OK]     | |          |  | Real-time analytics  |
+----------+ +----------+  | Fast queries    [OK] |
                           | Backup to S3    [OK] |
    [Background]           +----------------------+
          |
          v
    +--------------+
    | g5.xlarge    |
    |(Accelerated  |
    | Computing)   |
    | AI training  |
    | [OK]         |
    +--------------+

---

## 📊 Instance Family

| Family | Profile |
|--------|---------|
| **I4i** (ex: i4i.xlarge) | NVMe ultra-fast, transactional databases |
| **I3** (ex: i3.large) | Previous generation, still widely used |
| **D3** (ex: d3.xlarge) | Very large capacity, data warehouses |
| **H1** (ex: h1.2xlarge) | Large HDD volumes, sequential processing |

> 💡 The I stands for IOPS (Input/Output Operations Per Second)
> — the standard measure of disk speed!

---

## ✅ Typical Use Cases

**Good fit:**
- Real-time log analytics
- High-traffic transactional database
- Data warehouse
- Search engine (Elasticsearch, OpenSearch)
- Data stream processing
- Database cache layer

**Not a good fit:**
- Classic website -> use General Purpose
- AI model training -> use Accelerated Computing
- Long-term storage -> use S3
- Standard application -> no need for this performance level

---

## 🎯 Key Benefits for LearnUp

**1. Near-zero latency** — Data is read in microseconds instead of
milliseconds. The analytics dashboard updates in real time.

**2. Massive throughput** — Millions of read/write operations per second.
LearnUp's 10 million daily events are processed without any bottleneck.

**3. Immediate problem detection** — A broken video or confusing quiz
is flagged within minutes, not hours. The team can fix it the same day.

**4. Cost efficiency** — Only one specialized instance handles all log
processing, freeing the general purpose instance to serve the website fast.

---

## ⚠️ The Architect's Safety Rule

Because local NVMe data is lost if the instance stops,
LearnUp follows this backup strategy:

    Every 15 minutes -> raw logs backed up to S3
    Every hour       -> processed analytics saved to RDS database
    Every day        -> full snapshot saved to S3 Glacier (cheap archive)
    
    Result: maximum 15 minutes of data loss in worst case scenario
            acceptable for analytics (not for financial transactions)

---

## 📈 Scaling Strategy

| Daily events | Recommended instance | Strategy |
|---|---|---|
| 0 – 1M events | t3.large + EBS | No need for storage optimized yet |
| 1M – 10M events | i4i.xlarge (NVMe) | Single storage optimized instance |
| 10M – 50M events | i4i.2xlarge | Vertical scaling |
| 50M+ events | i4i.4xlarge + Kinesis | Horizontal + managed streaming |

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
        ├── accelerated-computing/  <- Done
        │   ├── README.md
        │   └── main.tf
        └── storage-optimized/      <- You are here
            ├── README.md
            └── main.tf

---

## 🔗 Useful Resources

- [AWS EC2 Storage Optimized Instances](https://aws.amazon.com/ec2/instance-types/i4i/)
- [Amazon S3 — Object Storage](https://aws.amazon.com/s3/)
- [Amazon Kinesis — Data Streaming](https://aws.amazon.com/kinesis/)
- [EC2 Price Comparator](https://instances.vantage.sh/)

---

*AWS Cloud Practitioner Training — Module 2: Cloud Computing*
