# 🚀 Production-Grade Web Application Infrastructure on AWS

We will build a **Production-like Web Application Infrastructure (Real Company Architecture)**.

At the end you’ll have:

🌐 **Highly Available, Scalable, Secure Web App on AWS**

Using:

- VPC  
- EC2  
- Auto Scaling Group  
- Application Load Balancer  
- RDS  
- S3  
- CloudFront  
- WAF  
- Route 53  
- IAM  
- Monitoring  
- Messaging  

And we will **NOT jump randomly.**  
We’ll follow the same order real companies use to design infrastructure.

---

# 🧠 Final Project Architecture

User  
→ Route 53  
→ CloudFront  
→ WAF  
→ ALB  
→ EC2 (Auto Scaling)  
→ RDS  

↘ S3 (static files)  
↘ EFS (shared storage)  
↘ Redis Cache  
↘ SQS + SNS  
↘ CloudWatch + Logs  

---

# 🪜 PHASE 1 — NETWORK FOUNDATION (Day 1–2)

👉 Nothing runs without network. We start with VPC.

## Services Used

- VPC  
- Subnets  
- Route Tables  
- Internet Gateway  
- NAT Gateway  
- NACL  
- Security Groups  
- VPC Endpoints  

---

## STEP 1 — Create VPC

AWS Console → VPC → Create VPC  

Name: `devops-vpc`  
CIDR: `10.0.0.0/16`

Why /16?  
Because companies need large IP space for scaling (ASG, RDS, Cache, Lambda, etc.)

---

## STEP 2 — Create Subnets (High Availability)

We create Public + Private Architecture.

Type                | Purpose         | Internet Access  
--------------------|----------------|----------------  
Public Subnet       | Load Balancer  | Yes  
Private App Subnet  | EC2 Servers    | No  
Private DB Subnet   | RDS Database   | No  

Create 6 subnets (2 AZ):

Public  
- 10.0.1.0/24 (AZ-a)  
- 10.0.2.0/24 (AZ-b)  

Private App  
- 10.0.11.0/24 (AZ-a)  
- 10.0.12.0/24 (AZ-b)  

Private DB  
- 10.0.21.0/24 (AZ-a)  
- 10.0.22.0/24 (AZ-b)  

---

## STEP 3 — Internet Gateway

Create: `devops-igw`  
Attach to VPC  

---

## STEP 4 — Route Tables

Public Route Table (`public-rt`)  
- 0.0.0.0/0 → Internet Gateway  
Associate with public subnets  

Private Route Table (`private-rt`)  
- Initially no internet  
Associate with app + db subnets  

---

## STEP 5 — NAT Gateway

Create NAT in public subnet  
Allocate Elastic IP  

Update private route table:

0.0.0.0/0 → NAT Gateway  

Now private EC2 can access internet for updates but remains private.

---

## STEP 6 — Security Groups

ALB-SG  
- Allow 80 from anywhere  

EC2-SG  
- Allow 80 from ALB-SG only  

RDS-SG  
- Allow 3306 from EC2-SG only  

🔥 Real production security isolation.

---

## STEP 7 — NACL

Public NACL  
- Allow 80, 443, 1024–65535  

Private NACL  
- Allow internal VPC traffic  

---

## ✅ CHECKPOINT

✔ Enterprise-level network  
✔ Multi-AZ architecture  
✔ Production-ready security base  

---

# 🪜 PHASE 2 — COMPUTE LAYER

We build:

- EC2 (private)  
- AMI  
- Launch Template  
- Target Group  
- ALB  
- Auto Scaling Group  

---

## EC2 User Data (Production Version)

    #!/bin/bash
    yum update -y
    yum install -y httpd php php-fpm php-mysqli

    systemctl start httpd
    systemctl enable httpd
    systemctl start php-fpm
    systemctl enable php-fpm

    sed -i 's/DirectoryIndex.*/DirectoryIndex index.php index.html/' /etc/httpd/conf/httpd.conf

    cat <<EOF > /var/www/html/config.php
    <?php
    \$host = "RDS-ENDPOINT";
    \$user = "admin";
    \$pass = "PASSWORD";
    \$db   = "cafe";
    ?>
    EOF

    cat <<'EOF' > /var/www/html/index.php
    <?php include 'config.php'; ?>
    <html>
    <body>
    <h1>☕ Cloud Cafe</h1>
    <?php
    \$conn = new mysqli(\$host,\$user,\$pass,\$db);
    if(\$conn->connect_error){ die("DB Failed"); }
    \$result = \$conn->query("SELECT * FROM menu");
    while(\$row = \$result->fetch_assoc()){
        echo "<h3>".$row['item_name']."</h3>";
        echo "<p>".$row['description']."</p>";
        echo "<b>₹".$row['price']."</b><hr>";
    }
    ?>
    </body>
    </html>
    EOF

    rm -f /var/www/html/index.html
    systemctl restart httpd

---

## Auto Scaling Configuration

Desired: 2  
Min: 2  
Max: 4  

Enable ELB health checks.  

Use Launch Template versioning + Instance Refresh for zero downtime deployment.

---

## ✅ CHECKPOINT

✔ Private servers  
✔ Load balancer  
✔ Auto healing  
✔ Zero-downtime deployment  

---

# 🪜 PHASE 3 — DATA LAYER

We add:

- RDS (MySQL)  
- EFS  
- S3  

---

## RDS

Engine: MySQL  
Public Access: NO  
Security Group: Allow 3306 from EC2-SG only  

Create database and table:

    CREATE DATABASE cafe;
    USE cafe;

    CREATE TABLE menu (
      id INT AUTO_INCREMENT PRIMARY KEY,
      item_name VARCHAR(50),
      description VARCHAR(200),
      price INT
    );

---

## EFS (Shared Storage)

Mount inside user data:

    yum install amazon-efs-utils -y
    mkdir /data
    mount -t efs EFS-ID:/ /data
    chmod 777 /data

Now all EC2 instances share same storage.

---

## S3 (Object Storage)

Use for:

- Static assets  
- Backups  
- Logs  

Attach IAM Role to EC2 with S3 permissions.

Test:

    echo "hello" > test.txt
    aws s3 cp test.txt s3://your-bucket-name/

---

## ✅ CHECKPOINT

✔ Managed database  
✔ Shared storage  
✔ Object storage  
✔ True 3-tier architecture  

---

# 🪜 PHASE 4 — DOMAIN + CDN + SECURITY

Final flow:

User  
→ Route 53  
→ CloudFront  
→ WAF  
→ ALB  
→ EC2  

---

## SSL (ACM)

Request public certificate.  
Use DNS validation.  

CloudFront requires certificate in us-east-1.

---

## CloudFront

Origin: ALB DNS  
Viewer Protocol: Redirect HTTP to HTTPS  
Attach ACM certificate  

---

## Route 53

Create A record (Alias)  
Point to CloudFront distribution  

---

## WAF

Attach to CloudFront  
Add:

- AWS Managed Common Rules  
- SQL Injection protection  
- Rate limiting  

Shield Standard automatically enabled.

---

## ✅ CHECKPOINT

✔ Domain  
✔ HTTPS  
✔ CDN acceleration  
✔ Firewall protection  
✔ DDoS protection  

---

# 🪜 PHASE 5 — MONITORING & OPERATIONS

This is what makes you DevOps.

We add:

- CloudWatch  
- SNS  
- CloudTrail  
- SQS  
- EventBridge  
- Parameter Store  
- Secrets Manager  
- Inspector  

---

## CloudWatch Agent (User Data Add)

    yum install amazon-cloudwatch-agent -y
    cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<EOF
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "ec2-system-logs",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      }
    }
    EOF

Attach IAM policy: CloudWatchAgentServerPolicy

---

## SNS Alerts

Create topic: `devops-alerts`  
Subscribe email  
Attach to CloudWatch alarm  

---

## CloudTrail

Create trail  
Store logs in S3  

Audit every AWS action.

---

## SQS

Create queue: `image-processing-queue`

    aws sqs send-message \
    --queue-url QUEUE-URL \
    --message-body "process image 1"

---

## EventBridge

Trigger SNS when EC2 state changes.

---

## Parameter Store & Secrets Manager

Store:

- DB endpoint  
- Environment variables  
- DB password (never hardcode)

---

## Inspector

Enable Amazon Inspector  
Scan EC2 for vulnerabilities.

---

# 🏁 FINAL ARCHITECTURE

User  
→ Route 53  
→ CloudFront  
→ WAF  
→ ALB  
→ Auto Scaling EC2  
→ RDS  
→ EFS  
→ S3  

Monitoring: CloudWatch  
Audit: CloudTrail  
Alerts: SNS  
Queue: SQS  
Automation: EventBridge  
Secrets: Parameter Store + Secrets Manager  
Security Scan: Inspector  

---

# 🎉 Conclusion

You built:

✔ Highly Available Infrastructure  
✔ Scalable Architecture  
✔ Secure Network  
✔ Automated Deployment  
✔ Monitoring & Alerts  
✔ Production-Grade AWS Stack  

This is no longer a beginner project.

This is:

“Designed and deployed production-grade highly available scalable secure AWS infrastructure on AWS using multi-tier architecture with automation and monitoring.”

⭐ Resume-level project complete.
