import json
dic = {}

dic['name'] = "Chandan"
dic['name1'] = "Chandan1"

x = {
  "name": "John",
  "age": 30,
  "married": True,
  "divorced": False,
  "children": ("Ann","Billy"),
  "pets": None,
  "cars": [
    {"model": "BMW 230", "mpg": 27.5},
    {"model": "Ford Edge", "mpg": 24.1}
  ]
}

print (dic)

# print(json.dumps(x))