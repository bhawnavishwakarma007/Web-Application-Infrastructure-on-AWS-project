# 🚀 Production-Grade 3-Tier Web Application on AWS

This project demonstrates how to design and deploy a **Production-Like 3-Tier Web Application Infrastructure on AWS**, following real-world company architecture patterns.

At the end of this project, you will have:

🌐 **Highly Available, Scalable, Secure Web Application**

Using:

- VPC  
- EC2  
- Auto Scaling Group  
- Application Load Balancer  
- RDS (MySQL)  
- IAM  

---

# 📁 Project Structure

aws-production-webapp/  
│  
├── README.md  
├── database/  
│   └── schema.sql  
├── user-data/  
│   └── web-user-data.sh  

---

# 🧠 Final Architecture

User  
→ Application Load Balancer  
→ Auto Scaling EC2 (Private Subnets)  
→ RDS (Private Subnets)  

High Availability across 2 Availability Zones.

---

# 🪜 PHASE 1 — NETWORK FOUNDATION

## Services Used

- VPC  
- Subnets  
- Internet Gateway  
- NAT Gateway  
- Route Tables  
- Security Groups  

---

## 1️⃣ Create VPC

Name: devops-vpc  
CIDR: 10.0.0.0/16  

Large CIDR ensures future scalability.

---

## 2️⃣ Create Subnets (Multi-AZ)

### Public Subnets (ALB)

- 10.0.1.0/24 (AZ-a)  
- 10.0.2.0/24 (AZ-b)  

### Private App Subnets (EC2)

- 10.0.11.0/24 (AZ-a)  
- 10.0.12.0/24 (AZ-b)  

### Private DB Subnets (RDS)

- 10.0.21.0/24 (AZ-a)  
- 10.0.22.0/24 (AZ-b)  

---

## 3️⃣ Internet Gateway

Attach IGW to VPC.  
Public route table → 0.0.0.0/0 → IGW.

---

## 4️⃣ NAT Gateway

Create NAT in public subnet.  
Private route table → 0.0.0.0/0 → NAT Gateway.

Allows private EC2 instances to download updates securely.

---

## 5️⃣ Security Groups (Production Isolation)

ALB-SG  
- Allow 80 from 0.0.0.0/0  

EC2-SG  
- Allow 80 from ALB-SG only  

RDS-SG  
- Allow 3306 from EC2-SG only  

This enforces strict 3-tier isolation.

---

# 🪜 PHASE 2 — COMPUTE LAYER

## Components

- Launch Template  
- Auto Scaling Group  
- Target Group  
- Application Load Balancer  

---

## Auto Scaling Configuration

Min: 2  
Desired: 2  
Max: 4  

Enable ELB Health Checks.  
Enable Instance Refresh for zero-downtime deployments.

---

## 📄 user-data/web-user-data.sh

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

---

# 🪜 PHASE 3 — DATA LAYER

## RDS Configuration

Engine: MySQL  
Multi-AZ: Enabled  
Public Access: NO  
Subnet Group: Private DB Subnets  
Security Group: Allow 3306 from EC2-SG only  

---

## 📄 database/schema.sql

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

# 🏁 FINAL ARCHITECTURE SUMMARY

✔ Multi-AZ VPC Architecture  
✔ Public ALB  
✔ Private Auto Scaling EC2  
✔ Private RDS (MySQL)  
✔ Secure Security Group Isolation  
✔ Zero-Downtime Deployments  
✔ Production-Ready 3-Tier Design  

---

# 🎯 What You Achieved

You designed and deployed:

A **Production-Grade Highly Available 3-Tier Web Application on AWS** using:

- Scalable Compute Layer  
- Isolated Network Design  
- Managed Relational Database  
- Auto Healing Infrastructure  

This is no longer a basic EC2 project.

This is a **real-world architecture implementation suitable for production environments and resume-level DevOps projects.**
