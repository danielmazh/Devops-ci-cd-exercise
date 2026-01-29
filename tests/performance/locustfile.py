from locust import HttpUser, task, between
import random
import json


class WebsiteUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        self.client.get("/")
    
    @task(3)
    def get_users(self):
        self.client.get("/api/users/")
    
    @task(2)
    def get_single_user(self):
        user_id = random.choice([1, 2])
        self.client.get(f"/api/users/{user_id}")
    
    @task(3)
    def get_products(self):
        self.client.get("/api/products/")
    
    @task(2)
    def get_single_product(self):
        product_id = random.choice([1, 2, 3])
        self.client.get(f"/api/products/{product_id}")
    
    @task(1)
    def health_check(self):
        self.client.get("/health")
    
    @task(1)
    def create_user(self):
        user_data = {
            "name": f"Test User {random.randint(1000, 9999)}",
            "email": f"test{random.randint(1000, 9999)}@example.com"
        }
        self.client.post("/api/users/", 
                         data=json.dumps(user_data),
                         headers={"Content-Type": "application/json"})
    
    @task(1)
    def create_product(self):
        product_data = {
            "name": f"Test Product {random.randint(1000, 9999)}",
            "price": round(random.uniform(10.0, 100.0), 2),
            "stock": random.randint(1, 100)
        }
        self.client.post("/api/products/",
                         data=json.dumps(product_data),
                         headers={"Content-Type": "application/json"})
    
    @task(1)
    def update_product(self):
        product_id = random.choice([1, 2, 3])
        update_data = {
            "price": round(random.uniform(10.0, 100.0), 2),
            "stock": random.randint(1, 100)
        }
        self.client.put(f"/api/products/{product_id}",
                       data=json.dumps(update_data),
                       headers={"Content-Type": "application/json"})


class ReadOnlyUser(HttpUser):
    wait_time = between(0.5, 2)
    
    @task(4)
    def get_users(self):
        self.client.get("/api/users/")
    
    @task(3)
    def get_single_user(self):
        user_id = random.choice([1, 2])
        self.client.get(f"/api/users/{user_id}")
    
    @task(4)
    def get_products(self):
        self.client.get("/api/products/")
    
    @task(3)
    def get_single_product(self):
        product_id = random.choice([1, 2, 3])
        self.client.get(f"/api/products/{product_id}")
    
    @task(2)
    def health_check(self):
        self.client.get("/health")
    
    @task(1)
    def view_homepage(self):
        self.client.get("/")


class WriteHeavyUser(HttpUser):
    wait_time = between(2, 5)
    
    def on_start(self):
        self.client.get("/")
    
    @task(1)
    def get_users(self):
        self.client.get("/api/users/")
    
    @task(1)
    def get_products(self):
        self.client.get("/api/products/")
    
    @task(3)
    def create_user(self):
        user_data = {
            "name": f"Write User {random.randint(1000, 9999)}",
            "email": f"write{random.randint(1000, 9999)}@example.com"
        }
        self.client.post("/api/users/", 
                         data=json.dumps(user_data),
                         headers={"Content-Type": "application/json"})
    
    @task(3)
    def create_product(self):
        product_data = {
            "name": f"Write Product {random.randint(1000, 9999)}",
            "price": round(random.uniform(10.0, 100.0), 2),
            "stock": random.randint(1, 100)
        }
        self.client.post("/api/products/",
                         data=json.dumps(product_data),
                         headers={"Content-Type": "application/json"})
    
    @task(2)
    def update_product(self):
        product_id = random.choice([1, 2, 3])
        update_data = {
            "price": round(random.uniform(10.0, 100.0), 2),
            "stock": random.randint(1, 100)
        }
        self.client.put(f"/api/products/{product_id}",
                       data=json.dumps(update_data),
                       headers={"Content-Type": "application/json"})
    
    @task(1)
    def health_check(self):
        self.client.get("/health")