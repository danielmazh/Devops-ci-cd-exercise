import pytest
from app import create_app


class TestUserRoutes:
    def test_get_users_returns_correct_structure(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.user_routes import get_users
            
            response = get_users()
            json_data = response.get_json()
            
            assert isinstance(json_data, list)
            assert len(json_data) == 2
            assert all('id' in user for user in json_data)
            assert all('name' in user for user in json_data)
            assert all('email' in user for user in json_data)
    
    def test_get_user_valid_id(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.user_routes import get_user
            
            response = get_user(1)
            json_data = response.get_json()
            
            assert json_data['id'] == 1
            assert json_data['name'] == 'John Doe'
            assert json_data['email'] == 'john@example.com'
    
    def test_get_user_invalid_id(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.user_routes import get_user
            
            response = get_user(999)
            
            # Handle tuple response (response, status_code)
            if isinstance(response, tuple):
                response_obj, status_code = response
                assert status_code == 404
                json_data = response_obj.get_json()
            else:
                assert response.status_code == 404
                json_data = response.get_json()
            
            assert 'error' in json_data
            assert json_data['error'] == 'User not found'


class TestProductRoutes:
    def test_get_products_returns_correct_structure(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.product_routes import get_products
            
            response = get_products()
            json_data = response.get_json()
            
            assert isinstance(json_data, list)
            assert len(json_data) == 3
            assert all('id' in product for product in json_data)
            assert all('name' in product for product in json_data)
            assert all('price' in product for product in json_data)
            assert all('stock' in product for product in json_data)
    
    def test_get_product_valid_id(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.product_routes import get_product
            
            response = get_product(1)
            json_data = response.get_json()
            
            assert json_data['id'] == 1
            assert json_data['name'] == 'Laptop'
            assert json_data['price'] == 999.99
            assert json_data['stock'] == 10
    
    def test_get_product_invalid_id(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.product_routes import get_product
            
            response = get_product(999)
            
            # Handle tuple response (response, status_code)
            if isinstance(response, tuple):
                response_obj, status_code = response
                assert status_code == 404
                json_data = response_obj.get_json()
            else:
                assert response.status_code == 404
                json_data = response.get_json()
            
            assert 'error' in json_data
            assert json_data['error'] == 'Product not found'


class TestBusinessLogic:
    def test_product_price_validation(self):
        from app.routes.product_routes import products
        
        for product in products:
            assert isinstance(product['price'], (int, float))
            assert product['price'] >= 0
    
    def test_user_email_format(self):
        app = create_app()
        with app.test_request_context():
            from app.routes.user_routes import get_users
            
            response = get_users()
            users = response.get_json()
            
            for user in users:
                assert '@' in user['email']
                assert '.' in user['email']