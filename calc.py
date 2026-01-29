
# calc.py
# Unit tests for basic arithmetic operations

def add(a, b):
    return a + b

def subtract(a, b):
    return a - b

def multiply(a, b):
    if a < 0 or b < 0:
        raise ValueError("Negative values are not allowed.")
    return a * b

def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero.")
    return a / b