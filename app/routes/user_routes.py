from flask import Blueprint, request, jsonify

user_bp = Blueprint('users', __name__)

# In-memory user storage
_users = {
    1: {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
    2: {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'}
}
_next_user_id = 3

@user_bp.route('/', methods=['GET'])
def get_users():
    return jsonify(list(_users.values()))

@user_bp.route('/<int:user_id>', methods=['GET'])
def get_user(user_id):
    if user_id in _users:
        return jsonify(_users[user_id])
    return jsonify({'error': 'User not found'}), 404

@user_bp.route('/', methods=['POST'])
def create_user():
    global _next_user_id
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({'error': 'Name and email are required'}), 400
    
    new_user = {'id': _next_user_id, 'name': data['name'], 'email': data['email']}
    _users[_next_user_id] = new_user
    _next_user_id += 1
    return jsonify(new_user), 201