import os
import torch
import torch.nn.functional as F
import joblib
from flask import Flask, render_template, request, jsonify
from transformers import AutoTokenizer, AutoModelForSequenceClassification

app = Flask(__name__)

# Setup device (gunakan GPU jika tersedia)
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# Konfigurasi Path
SAVE_DIR = "./finbert_sentiment_final" # Path tempat model FinBERT disimpan
ARTIFACTS_PATH = "sentiment_artifacts.joblib"

# Load Artifacts (Label Encoder, dll)
loaded_artifacts = joblib.load(ARTIFACTS_PATH)
loaded_le = loaded_artifacts["label_encoder"]
MAX_LEN = loaded_artifacts.get("max_len", 64)

# Load Tokenizer & Model
loaded_tokenizer = AutoTokenizer.from_pretrained(SAVE_DIR)
loaded_model = AutoModelForSequenceClassification.from_pretrained(SAVE_DIR)
loaded_model.to(device)
loaded_model.eval() # Set model ke mode evaluasi

def predict_sentiment(text):
    """Fungsi preprocessing dan prediksi sentimen menggunakan FinBERT"""
    # 1. Preprocessing & Tokenization
    inputs = loaded_tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=MAX_LEN
    )
    
    # 2. Pindahkan input ke device (CPU/GPU)
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    # 3. Prediksi menggunakan model
    with torch.no_grad():
        outputs = loaded_model(**inputs)
        logits = outputs.logits
        
        # 4. Hitung probabilitas menggunakan Softmax
        probs = F.softmax(logits, dim=-1).cpu().numpy()[0]
    
    # 5. Dapatkan index dengan probabilitas tertinggi
    pred_idx = probs.argmax()
    
    # 6. Konversi index kembali ke label string (negative/neutral/positive)
    label = loaded_le.inverse_transform([pred_idx])[0]
    confidence = float(probs[pred_idx])
    
    # 7. Buat dictionary untuk detail probabilitas tiap kelas
    breakdown = dict(zip(loaded_le.classes_, [float(p) for p in probs]))
    
    return label, confidence, breakdown

# --- FLASK ROUTES ---

@app.route('/')
def home():
    # Render halaman utama (opsional, jika menggunakan antarmuka web HTML)
    result = ''
    breakdown = {}
    input_text = ''
    return render_template('index.html', **locals())

@app.route('/predict', methods=['POST'])
def predict():
    # Endpoint untuk antarmuka web form HTML
    input_text = request.form.get('text', '')
    if not input_text.strip():
        result = "Teks tidak boleh kosong!"
        breakdown = {}
        return render_template('index.html', **locals())
        
    sentiment, confidence, breakdown = predict_sentiment(input_text)
    result = f'Sentimen: {sentiment} ({confidence * 100:.2f}%)'
    return render_template('index.html', **locals())

@app.route('/api/predict', methods=['POST'])
def api_predict():
    # Endpoint API JSON (Cocok untuk dipanggil dari Frontend Dart/Flutter)
    data = request.get_json()
    if not data or 'text' not in data:
        return jsonify({'error': 'No text provided'}), 400
        
    text = data['text']
    sentiment, confidence, breakdown = predict_sentiment(text)
    
    return jsonify({
        'sentiment': sentiment,
        'confidence': confidence,
        'breakdown': breakdown
    })

if __name__ == '__main__':
    # Jalankan di port 5001 agar tidak bentrok dengan app.py jika sedang jalan
    app.run(debug=True, port=5001)