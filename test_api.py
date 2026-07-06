import urllib.request
import json

url = "http://127.0.0.1:5000/api/predict"
data = {"text": "Analysts had projected a decline in quarterly earnings, but the firm surprised the market by reporting a 12% increase in net sales, driven primarily by stronger-than-expected demand in emerging markets"}
req = urllib.request.Request(url, method="POST")
req.add_header('Content-Type', 'application/json')
data_bytes = json.dumps(data).encode('utf-8')

print("Mengirim teks ke API...")
print(f"Teks: \"{data['text']}\"\n")

try:
    with urllib.request.urlopen(req, data=data_bytes) as response:
        result = json.loads(response.read().decode('utf-8'))
        print(" TAMPILAN RESPONS JSON ")
        print(json.dumps(result, indent=4))
        print("")
except Exception as e:
    print("Error:", e)
