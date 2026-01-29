from calc import add, subtract, multiply, divide
import pytest

@pytest.fixture
def zero():
    return 0

@pytest.mark.bad
def test_add():
    assert add(2, 3) == 7

@pytest.mark.good
def test_subtract():
    assert subtract(5, 3) == 2

@pytest.mark.good
def test_multiply():
    assert multiply(2, 3) == 6

@pytest.mark.good
def test_divide(zero):
    with pytest.raises(ValueError):
        assert divide(6, zero) == 3

