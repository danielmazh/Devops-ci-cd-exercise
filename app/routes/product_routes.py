from flask import Blueprint, request, jsonify

product_bp = Blueprint('products', __name__)

products = [
    {'id': 1, 'name': 'Laptop', 'price': 999.99, 'stock': 10},
    {'id': 2, 'name': 'Mouse', 'price': 29.99, 'stock': 50},
    {'id': 3, 'name': 'Keyboard', 'price': 79.99, 'stock': 25}
]

@product_bp.route('/', methods=['GET'])
def get_products():
    return jsonify(products)

@product_bp.route('/<int:product_id>', methods=['GET'])
def get_product(product_id):
    product = next((p for p in products if p['id'] == product_id), None)
    if product:
        return jsonify(product)
    return jsonify({'error': 'Product not found'}), 404

@product_bp.route('/', methods=['POST'])
def create_product():
    data = request.get_json()
    if not data or 'name' not in data or 'price' not in data:
        return jsonify({'error': 'Name and price are required'}), 400
    
    new_product = {
        'id': max(p['id'] for p in products) + 1,
        'name': data['name'],
        'price': data['price'],
        'stock': data.get('stock', 0)
    }
    products.append(new_product)
    return jsonify(new_product), 201

@product_bp.route('/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    product = next((p for p in products if p['id'] == product_id), None)
    if not product:
        return jsonify({'error': 'Product not found'}), 404
    
    data = request.get_json()
    if 'name' in data:
        product['name'] = data['name']
    if 'price' in data:
        product['price'] = data['price']
    if 'stock' in data:
        product['stock'] = data['stock']
    
    return jsonify(product)