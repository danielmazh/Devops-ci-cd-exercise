from calc import add, subtract, multiply, divide

import pytest

@pytest.fixture
def zero():
    return 0

class TestCalc: 
    def test_add(self):
        assert add(2, 3) == 5

    def test_subtract(self):
        assert subtract(5, 3) == 2

    @pytest.mark.xfail(reason="Multiplication with negative numbers not allowed")
    def test_multiply(self):
        assert multiply(4, 3) == 12

    @pytest.mark.skip(reason="Skipping division test temporarily")
    def test_divide(self, zero):
        with pytest.raises(ValueError):
            assert divide(10, 2) == 5