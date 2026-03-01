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
