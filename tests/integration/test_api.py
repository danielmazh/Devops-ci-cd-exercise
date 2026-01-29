import pytest
import json
from app import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config['TESTING'] = True
    
    with app.test_client() as client:
        yield client


@pytest.fixture
def app_context():
    app = create_app()
    with app.app_context():
        yield app


class TestUserAPIIntegration:
    def test_get_users_endpoint(self, client):
        response = client.get('/api/users/')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert isinstance(data, list)
        assert len(data) == 2
        
        for user in data:
            assert 'id' in user
            assert 'name' in user
            assert 'email' in user
    
    def test_get_user_by_id(self, client):
        response = client.get('/api/users/1')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['id'] == 1
        assert data['name'] == 'John Doe'
        assert data['email'] == 'john@example.com'
    
    def test_get_nonexistent_user(self, client):
        response = client.get('/api/users/999')
        
        assert response.status_code == 404
        data = json.loads(response.data)
        assert 'error' in data
        assert data['error'] == 'User not found'
    
    def test_create_user(self, client):
        user_data = {
            'name': 'Test User',
            'email': 'test@example.com'
        }
        
        response = client.post('/api/users/', 
                              data=json.dumps(user_data),
                              content_type='application/json')
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data['name'] == 'Test User'
        assert data['email'] == 'test@example.com'
        assert 'id' in data
    
    def test_create_user_missing_data(self, client):
        incomplete_data = {'name': 'Test User'}
        
        response = client.post('/api/users/',
                              data=json.dumps(incomplete_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data


class TestProductAPIIntegration:
    def test_get_products_endpoint(self, client):
        response = client.get('/api/products/')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert isinstance(data, list)
        assert len(data) == 3
        
        for product in data:
            assert 'id' in product
            assert 'name' in product
            assert 'price' in product
            assert 'stock' in product
    
    def test_get_product_by_id(self, client):
        response = client.get('/api/products/1')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['id'] == 1
        assert data['name'] == 'Laptop'
        assert data['price'] == 999.99
        assert data['stock'] == 10
    
    def test_create_product(self, client):
        product_data = {
            'name': 'Test Product',
            'price': 19.99,
            'stock': 100
        }
        
        response = client.post('/api/products/',
                              data=json.dumps(product_data),
                              content_type='application/json')
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data['name'] == 'Test Product'
        assert data['price'] == 19.99
        assert data['stock'] == 100
        assert 'id' in data
    
    def test_update_product(self, client):
        update_data = {
            'price': 899.99,
            'stock': 15
        }
        
        response = client.put('/api/products/1',
                             data=json.dumps(update_data),
                             content_type='application/json')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['price'] == 899.99
        assert data['stock'] == 15
        assert data['name'] == 'Laptop'
    
    def test_update_nonexistent_product(self, client):
        update_data = {'price': 99.99}
        
        response = client.put('/api/products/999',
                             data=json.dumps(update_data),
                             content_type='application/json')
        
        assert response.status_code == 404
        data = json.loads(response.data)
        assert 'error' in data


class TestApplicationIntegration:
    def test_health_check(self, client):
        response = client.get('/health')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert data['service'] == 'devops-testing-app'
    
    def test_index_page(self, client):
        response = client.get('/')
        
        assert response.status_code == 200
        assert b'DevOps Testing Application' in response.data
        assert b'Users API' in response.data
        assert b'Products API' in response.data
    
    def test_api_cors_headers(self, client):
        response = client.get('/api/users/')
        
        assert response.status_code == 200
        assert 'Content-Type' in response.headers
        assert 'application/json' in response.headers['Content-Type']


class TestWorkflows:
    def test_user_creation_then_retrieval(self, client):
        create_data = {
            'name': 'Workflow User',
            'email': 'workflow@example.com'
        }
        
        create_response = client.post('/api/users/',
                                    data=json.dumps(create_data),
                                    content_type='application/json')
        
        assert create_response.status_code == 201
        created_user = json.loads(create_response.data)
        user_id = created_user['id']
        
        get_response = client.get(f'/api/users/{user_id}')
        assert get_response.status_code == 200
        retrieved_user = json.loads(get_response.data)
        
        assert retrieved_user['name'] == create_data['name']
        assert retrieved_user['email'] == create_data['email']
    
    def test_product_crud_workflow(self, client):
        create_data = {
            'name': 'Workflow Product',
            'price': 49.99,
            'stock': 20
        }
        
        create_response = client.post('/api/products/',
                                    data=json.dumps(create_data),
                                    content_type='application/json')
        
        assert create_response.status_code == 201
        created_product = json.loads(create_response.data)
        product_id = created_product['id']
        
        get_response = client.get(f'/api/products/{product_id}')
        assert get_response.status_code == 200
        retrieved_product = json.loads(get_response.data)
        
        update_data = {'price': 39.99, 'stock': 15}
        update_response = client.put(f'/api/products/{product_id}',
                                   data=json.dumps(update_data),
                                   content_type='application/json')
        
        assert update_response.status_code == 200
        updated_product = json.loads(update_response.data)
        
        assert updated_product['price'] == 39.99
        assert updated_product['stock'] == 15
        assert updated_product['name'] == create_data['name']