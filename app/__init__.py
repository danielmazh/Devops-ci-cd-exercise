from flask import Flask, render_template, request, jsonify
from app.routes.user_routes import user_bp
from app.routes.product_routes import product_bp
import os

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
    
    # Register blueprints
    app.register_blueprint(user_bp, url_prefix='/api/users')
    app.register_blueprint(product_bp, url_prefix='/api/products')
    
    @app.route('/')
    def index():
        return render_template('index.html')
    
    @app.route('/health')
    def health_check():
        from flask import jsonify
        return jsonify({'status': 'healthy', 'service': 'devops-testing-app'})
    
    return app
