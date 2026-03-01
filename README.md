# 🚀 Production-Grade 3-Tier Web Application on AWS

This repository shows a **production-like 3-Tier Web Application Infrastructure** design and the step-by-step actions companies follow to build it. This README focuses on everything *up to RDS* (no CloudFront/WAF/etc in this version) and includes exact steps for launching EC2 into **private subnets**, AMI creation, ALB, Auto Scaling, and RDS setup & testing.

---

# 📁 Project Layout

aws-production-webapp/  
│  
├── README.md  
├── database/  
│   └── schema.sql         ← SQL for RDS (creates `cafe` + sample `menu`)  
├── user-data/  
│   └── web-user-data.sh   ← EC2 user-data (installs web app & connects to RDS)

---

# 🧠 Final Architecture (this README)

User → Application Load Balancer (public) → Auto Scaling EC2 (private subnets) → RDS (private subnets)

High availability across 2 Availability Zones (AZ-a, AZ-b). Strict Security Group isolation (ALB → EC2 → RDS).

---

# 🪜 PHASE 1 — NETWORK FOUNDATION (Day 1–2)

We build the VPC and networking primitives first. Nothing runs without network.

## Services used
- VPC  
- Subnets (public / private app / private db)  
- Internet Gateway (IGW)  
- NAT Gateway  
- Route Tables  
- Security Groups  
- NACL (optional/simple)  
- VPC Endpoints (optional for S3/SSM)

---

## STEP 1 — Create VPC
AWS Console → VPC → Create VPC  
- Name: `devops-vpc`  
- CIDR: `10.0.0.0/16`

Why /16? Companies keep a large IP space for future growth (ASG, RDS, caches, lambdas, etc).

---

## STEP 2 — Create Subnets (Multi-AZ, Highly Available)
We use Public + Private (App) + Private (DB) subnets across 2 AZs.

Public Subnets (ALB)
- 10.0.1.0/24 (AZ-a)  
- 10.0.2.0/24 (AZ-b)  

Private App Subnets (EC2)
- 10.0.11.0/24 (AZ-a)  
- 10.0.12.0/24 (AZ-b)  

Private DB Subnets (RDS)
- 10.0.21.0/24 (AZ-a)  
- 10.0.22.0/24 (AZ-b)  

---

## STEP 3 — Internet Gateway
VPC → Internet Gateways → Create  
- Name: `devops-igw`  
- Attach to `devops-vpc`

Associate public route table so public subnets can reach the internet.

---

## STEP 4 — Route Tables
- Public Route Table (`public-rt`): `0.0.0.0/0 → devops-igw` (associate with public subnets)  
- Private Route Table (`private-rt`): initially no internet (associate with app + db subnets)

---

## STEP 5 — NAT Gateway
- Create NAT Gateway in a public subnet (attach an Elastic IP).  
- Update private route table: `0.0.0.0/0 → NAT Gateway`  
This allows EC2 in private subnets to download updates while remaining unreachable from the internet directly.

---

## STEP 6 — Security Groups (3-tier firewall)
- **ALB-SG** — Inbound: HTTP 80 from `0.0.0.0/0` (or more restrictive CIDRs).  
- **EC2-SG** — Inbound: HTTP 80 only from `ALB-SG` (security group reference).  
- **RDS-SG** — Inbound: MySQL 3306 only from `EC2-SG`.  

This enforces strict lateral movement prevention between tiers.

---

## STEP 7 — NACL (optional stateless rules)
- Public NACL: allow 80, 443, ephemeral ports (1024–65535) for return traffic.  
- Private NACL: allow internal VPC traffic.  
(We keep NACLs simple — most companies rely on Security Groups for stateful control.)

---

## ✅ CHECKPOINT
You now have an enterprise-level VPC with multi-AZ coverage, NAT for patching, and production-grade Security Groups. Ready for compute.

---

# 🪜 PHASE 2 — COMPUTE LAYER (Make website live)

We build EC2 instances (private), create a golden AMI, create Target Group + ALB, then an Auto Scaling Group (ASG). The README contains the exact console steps you can follow.

## Components
- EC2 in private subnets (no public IP)  
- AMI (golden image used by ASG)  
- Launch Template (versioned)  
- Target Group  
- Application Load Balancer (public, in public subnets)  
- Auto Scaling Group (private subnets)  
- User Data script to install web app and point to RDS

---

## STEP 0 — Prerequisites & quick notes
- Ensure your VPC, subnets, IGW, NAT, route tables, and security groups (ALB-SG, EC2-SG, RDS-SG) are created as above.  
- Create or confirm the following security groups exist and have correct inbound rules: `ALB-SG`, `EC2-SG`, `RDS-SG`.  
- Keep keys/credentials secure — production practice often relies on SSM Session Manager and no public key login.

---

## STEP 1 — Create EC2 in PRIVATE SUBNET (Very Important)

**Console path:** AWS Console → EC2 → Launch Instance

**Basic config**
- Name: `web-server-1`  
- AMI: **Amazon Linux 2**  
- Instance type: `t2.micro` (free tier for demo)

**Network**
- VPC: `devops-vpc`  
- Subnet: `Private-App-Subnet-A` (10.0.11.0/24)  
- Auto-assign public IP: **Disable** (very important — keep instance private)

**Security Group**
- Choose: `EC2-SG` (which allows inbound 80 only from `ALB-SG`)

**Storage**
- Default root volume is fine for demo; use encrypted volumes in production.

**User Data** (add in Advanced → User Data)
Paste the full user-data script (the README's `user-data/web-user-data.sh` — shown below in the `user-data` file section). This will auto-install Apache, PHP, and create the web app that talks to RDS.

**Launch Instance.**

> ⚠️ Note: You cannot access this instance directly from the Internet (no public IP) — this is expected.

---

## STEP 2 — Test Using Temporary Bastion (Quick check)
If you need to confirm the web server installed correctly:

- Option A (temporary): temporarily allow SSH from your IP to `EC2-SG`, assign an elastic IP or use an instance with a public IP for testing, SSH in, then run `curl localhost` to verify the page served. Remove SSH rule afterwards.  
- Option B (better): use SSM Session Manager (recommended) or EC2 Instance Connect Endpoint to securely access the instance from the console without exposing SSH.

What to test from inside the instance:

    curl localhost

You should see the web app HTML (or error showing DB connection if RDS creds not set).

---

## STEP 3 — Create AMI (Golden Image)
Once a private instance is configured and validated:

- EC2 → Instances → Select `web-server-1` → Actions → Image → Create Image  
- Name: `web-ami`  
- Wait for AMI to become **available**. Use this AMI in Launch Template for ASG to ensure identical instances.

Why? Auto Scaling uses the AMI for homogenous, reproducible instances.

---

## STEP 4 — Create TARGET GROUP
EC2 → Target Groups → Create target group

- Type: `Instances`  
- Protocol: HTTP  
- Port: 80  
- VPC: `devops-vpc`  
- Health check path: `/`  
- Register instance: add your test EC2 instance.  
- Create.

---

## STEP 5 — Create APPLICATION LOAD BALANCER (ALB)
EC2 → Load Balancers → Create Load Balancer → Application Load Balancer

**Basic**
- Name: `devops-alb`  
- Scheme: Internet-facing  
- IP type: IPv4

**Network**
- VPC: `devops-vpc`  
- Subnets: choose **Public-Subnet-A** and **Public-Subnet-B** (10.0.1.0/24 and 10.0.2.0/24)

**Security Group**
- Select: `ALB-SG` (allows inbound HTTP 80 from internet)

**Listeners**
- HTTP : 80 → Forward to the target group created earlier.

Create ALB and wait for it to become available. Copy the ALB DNS name.

Open in your browser:

    http://<ALB-DNS>

You should see the website served by instances registered in the Target Group (if health checks pass).

---

## STEP 6 — Launch Template (for Auto Scaling)
EC2 → Launch Templates → Create Launch Template

- Name: `web-template`  
- AMI: `web-ami` (created earlier)  
- Instance type: `t2.micro`  
- Security group: `EC2-SG`  
- Network interfaces: none (ASG will place instances in private subnets)  
- User data: (optional) you can keep user-data in the AMI or paste again here for idempotency.

Create launch template.

---

## STEP 7 — Auto Scaling Group (ASG)
EC2 → Auto Scaling → Create Auto Scaling Group

- Name: `web-asg`  
- Launch template: `web-template`  
- VPC: `devops-vpc`  
- Subnets: `Private-App-Subnet-A` and `Private-App-Subnet-B`  
- Load balancer: Attach to existing target group (`web-target-group`)  
- Health checks: enable ELB health checks  
- Group size: Desired: 2, Min: 2, Max: 4  
- Scaling policies: add later (e.g., target tracking on CPU)

Create ASG. Instances will launch into private subnets and register to the target group. ALB will distribute traffic to healthy instances.

---

## ✅ Compute Layer Checkpoint
- EC2 instances run in private subnets (no public IP).  
- ALB is internet-facing in public subnets and forwards to EC2 in private subnets.  
- ASG ensures desired capacity, auto-healing, and version-controlled rollouts via AMI/Launch Template.

---

# 🪜 PHASE 3 — DATA LAYER (RDS)

We create a managed MySQL instance (RDS) in private DB subnets and lock it down to accept connections only from the EC2 security group.

---

## STEP 1 — Create RDS (MySQL)

RDS → Create database

**Settings**
- Engine: MySQL  
- Template: Free tier (for demo)  
- DB instance identifier: `cafe-db`  
- Master username: `admin`  
- Master password: (choose a strong password and store securely)

**Connectivity**
- VPC: `devops-vpc`  
- Subnet group: Private DB subnets (10.0.21.0/24 and 10.0.22.0/24)  
- Public accessibility: **NO** (must be private)  
- VPC security group: `RDS-SG` (create if not present)

Create DB and wait for it to be available (~5–10 minutes).

---

## STEP 2 — Allow EC2 to talk to RDS (VERY IMPORTANT)
RDS → Connectivity & security → Security group (or go to EC2 Console → Security Groups)

Edit **RDS-SG** inbound rules:
- Type: MySQL/Aurora  
- Port: 3306  
- Source: `EC2-SG` (select by security group ID, not 0.0.0.0/0)

This restricts DB access to only EC2 instances that have the `EC2-SG` attached.

---

## STEP 3 — Connect from EC2 & Create Schema

**From an EC2 instance (via SSM / bastion / temporary SSH):**

Install MySQL client and connect:

    sudo yum install mysql -y
    mysql -h <RDS-ENDPOINT> -u admin -p

Enter password when prompted. If you can login, networking is configured correctly.

Run the schema SQL (file provided in `database/schema.sql`) to create the `cafe` database, `menu` table, and sample rows.

---

## STEP 4 — Database & Tables (schema.sql)

The SQL placed at `database/schema.sql`:

    CREATE DATABASE cafe;
    USE cafe;

    CREATE TABLE menu (
        id INT AUTO_INCREMENT PRIMARY KEY,
        item_name VARCHAR(50),
        description VARCHAR(200),
        price INT
    );

    INSERT INTO menu (item_name, description, price) VALUES
    ('Espresso','Strong and bold coffee',120),
    ('Cappuccino','Creamy milk foam delight',180),
    ('Cold Brew','Smooth chilled coffee',150),
    ('Latte','Smooth milky coffee',160);

---

## STEP 5 — Wiring EC2 → RDS
- In the EC2 user-data (below), update `RDS-ENDPOINT` with the actual RDS endpoint, and set the database password (`YOUR_DB_PASSWORD`) or use Parameter Store / Secrets Manager for production secrets (recommended).  
- If you change DB credentials, ensure your instances have the right configuration and can reach RDS via the `EC2-SG` reference.

---

# 🔐 Secrets & Configuration Best Practices (important)
- **Do not hardcode DB passwords** in user-data for production — use **AWS Secrets Manager** or **SSM Parameter Store (SecureString)** and grant the EC2 instance role permission to read them.  
- Use IAM instance profile (EC2 role) to grant `ssm:StartSession`, `secretsmanager:GetSecretValue`, and `ssm:GetParameter` for secure configuration.

---

# 📄 Files (contents)

## user-data/web-user-data.sh (place inside repository `user-data/web-user-data.sh`)

    #!/bin/bash
    yum update -y

    # Install Apache + PHP + MySQL support
    yum install -y httpd php php-fpm php-mysqli

    # Start services
    systemctl start httpd
    systemctl enable httpd
    systemctl start php-fpm
    systemctl enable php-fpm

    # Make Apache prioritize PHP
    sed -i 's/DirectoryIndex.*/DirectoryIndex index.php index.html/' /etc/httpd/conf/httpd.conf

    # -------------------------------
    # Database Config
    # -------------------------------
    cat <<EOF > /var/www/html/config.php
    <?php
    \$host = "RDS-ENDPOINT";
    \$user = "admin";
    \$pass = "YOUR_DB_PASSWORD";
    \$db   = "cafe";
    ?>
    EOF

    # -------------------------------
    # Website
    # -------------------------------
    cat <<'EOF' > /var/www/html/index.php
    <?php include 'config.php'; ?>
    <!DOCTYPE html>
    <html>
    <head>
    <title>Cloud Cafe</title>
    <style>
    body{margin:0;font-family:Arial;background:#f4f1ee}
    header{background:#4b2e2e;color:white;padding:20px;text-align:center}
    .item{background:white;margin:15px auto;padding:15px;width:250px;border-radius:8px}
    </style>
    </head>
    <body>

    <header>
    <h1>☕ Cloud Cafe</h1>
    <p>AWS 3-Tier Architecture</p>
    </header>

    <section>
    <?php
    \$conn = new mysqli(\$host,\$user,\$pass,\$db);
    if(\$conn->connect_error){ die("Database connection failed"); }

    \$result = \$conn->query("SELECT * FROM menu");

    while(\$row = \$result->fetch_assoc()){
    echo "<div class='item'>";
    echo "<h3>".$row['item_name']."</h3>";
    echo "<p>".$row['description']."</p>";
    echo "<b>₹".$row['price']."</b>";
    echo "</div>";
    }
    ?>
    </section>

    </body>
    </html>
    EOF

    rm -f /var/www/html/index.html
    systemctl restart httpd

> Place the above file in `user-data/web-user-data.sh` and paste its contents into EC2 Launch → Advanced → User data when launching test instances or in the Launch Template so new instances are configured automatically.

---

## database/schema.sql (place at `database/schema.sql`)
(Exact same content as earlier "STEP 4 — Database & Tables")

    CREATE DATABASE cafe;
    USE cafe;

    CREATE TABLE menu (
        id INT AUTO_INCREMENT PRIMARY KEY,
        item_name VARCHAR(50),
        description VARCHAR(200),
        price INT
    );

    INSERT INTO menu (item_name, description, price) VALUES
    ('Espresso','Strong and bold coffee',120),
    ('Cappuccino','Creamy milk foam delight',180),
    ('Cold Brew','Smooth chilled coffee',150),
    ('Latte','Smooth milky coffee',160);

---

# ✅ Operational Runbook (short checklist)
1. Build VPC & subnets (public/app/db) across 2 AZs.  
2. Create IGW, NAT, Route Tables.  
3. Create Security Groups: `ALB-SG`, `EC2-SG`, `RDS-SG`.  
4. Launch a test EC2 in **Private-App-Subnet-A** (use `EC2-SG`) and confirm user-data runs.  
5. Create AMI from validated EC2 → `web-ami`.  
6. Create Target Group and ALB (ALB in public subnets; ALB-SG attached).  
7. Create Launch Template (use `web-ami`) and ASG (private subnets + target group).  
8. Create RDS (private DB subnets) → update `RDS-SG` to allow inbound 3306 from `EC2-SG`.  
9. Populate DB using `database/schema.sql`.  
10. Point config in `user-data/web-user-data.sh` to the real `RDS-ENDPOINT` (or use Secrets Manager).

---

# 🎯 Outcomes & Resume Summary
By following the above steps you will have built a **production-style**, highly available 3-tier architecture on AWS:
- VPC with multi-AZ subnets  
- Internet-facing ALB in public subnets  
- Private EC2 Auto Scaling Group serving web app (no public IPs)  
- Private managed MySQL RDS with security-group only access from app tier  
- Golden AMI and Launch Template for consistent bootstrapping

This is a real-world, resume-level DevOps project.

---

# Next steps (suggested)
- Replace DB credentials with **Secrets Manager** or **Parameter Store (SecureString)** and fetch at boot.  
- Add HTTPS: ACM + ALB (or CloudFront in front of ALB).  
- Add monitoring: CloudWatch metrics, alarms, and SNS alerts.  
- Create CI/CD pipelines to build AMIs and deploy configuration changes.

4
