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
$conn = new mysqli($host,$user,$pass,$db);
if($conn->connect_error){ die("Database connection failed"); }

$result = $conn->query("SELECT * FROM menu");

while($row = $result->fetch_assoc()){
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
