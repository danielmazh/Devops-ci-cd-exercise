import pytest


class TestMathUtils:
    @pytest.mark.unit
    def test_addition(self):
        assert 2 + 2 == 4
    
    def test_subtraction(self):
        assert 10 - 5 == 5
    
    def test_multiplication(self):
        assert 3 * 4 == 12
    
    def test_division(self):
        assert 10 / 2 == 5
    
    def test_division_by_zero_raises_error(self):
        with pytest.raises(ZeroDivisionError):
            result = 10 / 0


class TestStringUtils:
    def test_string_length(self):
        assert len("hello") == 5
    
    def test_string_concatenation(self):
        assert "hello" + " " + "world" == "hello world"
    
    def test_string_uppercase(self):
        assert "hello".upper() == "HELLO"
    
    def test_string_lowercase(self):
        assert "WORLD".lower() == "world"
    
    def test_string_contains(self):
        assert "hello" in "hello world"


class TestListOperations:
    def test_list_length(self):
        assert len([1, 2, 3, 4, 5]) == 5
    
    def test_list_append(self):
        my_list = [1, 2, 3]
        my_list.append(4)
        assert 4 in my_list
        assert len(my_list) == 4
    
    def test_list_remove(self):
        my_list = [1, 2, 3, 4]
        my_list.remove(2)
        assert 2 not in my_list
        assert len(my_list) == 3
    
    def test_list_sorting(self):
        my_list = [3, 1, 4, 2]
        my_list.sort()
        assert my_list == [1, 2, 3, 4]


class TestDictionaryOperations:
    def test_dictionary_access(self):
        my_dict = {"name": "John", "age": 30}
        assert my_dict["name"] == "John"
        assert my_dict["age"] == 30
    
    def test_dictionary_keys(self):
        my_dict = {"name": "John", "age": 30}
        keys = list(my_dict.keys())
        assert "name" in keys
        assert "age" in keys
    
    def test_dictionary_values(self):
        my_dict = {"name": "John", "age": 30}
        values = list(my_dict.values())
        assert "John" in values
        assert 30 in values
    
    def test_dictionary_update(self):
        my_dict = {"name": "John"}
        my_dict["age"] = 30
        assert my_dict["age"] == 30