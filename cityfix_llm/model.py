"""
CityFix LLM — Deep Learning Model
BiLSTM + Transformer + Character CNN + Multi-task heads:
  - Category classifier     (12 classes)
  - Subcategory classifier  (120 classes)
  - Urgency classifier      (4 levels)
  - Emotion classifier      (4 states)
  - Language detector       (3 languages)
  - Emergency flag          (binary)
  - Location detection      (binary)
  - Time extraction         (binary)
  - Sentiment intensity     (regression)
"""
import json
import os
import re
import torch
import torch.nn as nn
import torch.nn.functional as F

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
MODEL_DIR = os.path.join(os.path.dirname(__file__), "saved_model")


# ── Tokenizer ─────────────────────────────────────────────────────────────────
class CityFixTokenizer:
    def __init__(self, vocab: dict):
        self.vocab = vocab
        self.pad_id = vocab.get("<PAD>", 0)
        self.unk_id = vocab.get("<UNK>", 1)

        # char vocab (handles OOV and typos)
        chars = list("abcdefghijklmnopqrstuvwxyz0123456789 ")
        self.char_vocab = {"<PAD>": 0, "<UNK>": 1}
        for i, c in enumerate(chars, start=2):
            self.char_vocab[c] = i
        self.char_pad_id = self.char_vocab["<PAD>"]
        self.char_unk_id = self.char_vocab["<UNK>"]

    def encode(self, text: str, max_len: int = 64) -> list[int]:
        tokens = re.sub(r"[^a-zA-Z0-9\u0900-\u097F\u0A80-\u0AFF\s]", " ", text.lower()).split()
        ids = [self.vocab.get(t, self.unk_id) for t in tokens][:max_len]
        ids += [self.pad_id] * (max_len - len(ids))
        return ids

    def encode_char(self, text: str, max_len: int = 256) -> list[int]:
        text = re.sub(r"[^a-zA-Z0-9\u0900-\u097F\u0A80-\u0AFF\s]", " ", text.lower())
        chars = list(text)[:max_len]
        ids = [self.char_vocab.get(c, self.char_unk_id) for c in chars]
        ids += [self.char_pad_id] * (max_len - len(ids))
        return ids

    def batch_encode(self, texts: list[str], max_len: int = 64) -> torch.Tensor:
        return torch.tensor([self.encode(t, max_len) for t in texts], dtype=torch.long)

    def batch_encode_char(self, texts: list[str], max_len: int = 256) -> torch.Tensor:
        return torch.tensor([self.encode_char(t, max_len) for t in texts], dtype=torch.long)


class CharCNN(nn.Module):
    def __init__(self, vocab_size, char_dim=32, kernels=(2, 3, 4), n_filters=64, max_len=256):
        super().__init__()
        self.char_embedding = nn.Embedding(vocab_size, char_dim, padding_idx=0)
        self.convs = nn.ModuleList([
            nn.Conv2d(1, n_filters, (k, char_dim), padding=(k-1, 0))
            for k in kernels
        ])
        self.max_len = max_len

    def forward(self, char_ids):
        x = self.char_embedding(char_ids)  # (B, L, C)
        x = x.unsqueeze(1)                # (B, 1, L, C)
        conv_outs = []
        for conv in self.convs:
            c = conv(x)                   # (B, F, L-k+1, 1)
            c = F.relu(c.squeeze(3))      # (B, F, L-k+1)
            c = F.max_pool1d(c, c.size(2)).squeeze(2)  # (B, F)
            conv_outs.append(c)
        return torch.cat(conv_outs, dim=1)  # (B, F * len(kernels))


class MultiHeadSelfAttention(nn.Module):
    def __init__(self, hidden_dim, num_heads=8, dropout=0.1):
        super().__init__()
        self.mha = nn.MultiheadAttention(hidden_dim, num_heads, dropout=dropout, batch_first=True)
        self.dropout = nn.Dropout(dropout)
        self.norm1 = nn.LayerNorm(hidden_dim)
        self.ffn = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim * 4),
            nn.GELU(),
            nn.Linear(hidden_dim * 4, hidden_dim),
        )
        self.norm2 = nn.LayerNorm(hidden_dim)

    def forward(self, x):  # x: (B, T, H)
        attn_out, _ = self.mha(x, x, x)
        x = self.norm1(x + self.dropout(attn_out))
        ffn_out = self.ffn(x)
        x = self.norm2(x + self.dropout(ffn_out))
        return x


# ── Main Model ────────────────────────────────────────────────────────────────
class CityFixModel(nn.Module):
    def __init__(
        self,
        vocab_size: int,
        embed_dim: int = 128,
        hidden_dim: int = 256,
        num_categories: int = 12,
        num_subcategories: int = 120,
        num_urgencies: int = 4,
        num_emotions: int = 4,
        num_languages: int = 3,
        dropout: float = 0.3,
        char_dim: int = 32,
        char_kernels=(2, 3, 4),
        char_filters: int = 64,
        num_transformer_layers: int = 2,
        num_heads: int = 8,
    ):
        super().__init__()

        self.word_embedding = nn.Embedding(vocab_size, embed_dim, padding_idx=0)
        self.char_encoder = CharCNN(len(CityFixTokenizer({}).char_vocab), char_dim=char_dim, kernels=char_kernels, n_filters=char_filters)

        self.bilstm = nn.LSTM(
            embed_dim, hidden_dim // 2,
            num_layers=2,
            batch_first=True,
            bidirectional=True,
            dropout=dropout,
        )

        self.transformer_encoder = nn.TransformerEncoder(
            nn.TransformerEncoderLayer(
                d_model=hidden_dim,
                nhead=num_heads,
                dim_feedforward=hidden_dim * 4,
                dropout=dropout,
                activation="gelu",
                batch_first=True,
            ),
            num_layers=num_transformer_layers,
            norm=nn.LayerNorm(hidden_dim),
        )

        self.self_attention = MultiHeadSelfAttention(hidden_dim, num_heads=num_heads, dropout=dropout)

        fusion_dim = hidden_dim + char_filters * len(char_kernels)
        self.fusion = nn.Sequential(
            nn.Linear(fusion_dim, hidden_dim),
            nn.LayerNorm(hidden_dim),
            nn.GELU(),
            nn.Dropout(dropout),
        )

        self.temperature = nn.Parameter(torch.tensor(1.0))

        self.head_category    = nn.Linear(hidden_dim, num_categories)
        self.head_subcategory = nn.Linear(hidden_dim, num_subcategories)
        self.head_urgency     = nn.Linear(hidden_dim, num_urgencies)
        self.head_emotion     = nn.Linear(hidden_dim, num_emotions)
        self.head_language    = nn.Linear(hidden_dim, num_languages)
        self.head_emergency   = nn.Linear(hidden_dim, 1)
        self.head_location    = nn.Linear(hidden_dim, 2)
        self.head_time        = nn.Linear(hidden_dim, 2)
        self.head_sentiment   = nn.Linear(hidden_dim, 1)

        self.dropout = nn.Dropout(dropout)

    def set_temperature(self, value: float):
        with torch.no_grad():
            self.temperature.copy_(torch.tensor(value, device=self.temperature.device))

    def encode(self, input_ids: torch.Tensor, char_ids: torch.Tensor) -> torch.Tensor:
        word_embed = self.word_embedding(input_ids)  # (B,T,E)
        char_feat = self.char_encoder(char_ids)       # (B, char_f)

        x, _ = self.bilstm(word_embed)                # (B,T,H)
        x = self.transformer_encoder(x)               # (B,T,H)
        x = self.self_attention(x)                    # (B,T,H)
        x = x.mean(dim=1)                             # (B,H)

        fused = torch.cat([x, char_feat], dim=1)      # (B, fusion_dim)
        out = self.fusion(fused)                      # (B,H)
        return out

    def classify(self, hidden: torch.Tensor) -> dict:
        logits = {
            "category":    self.head_category(hidden),
            "subcategory": self.head_subcategory(hidden),
            "urgency":     self.head_urgency(hidden),
            "emotion":     self.head_emotion(hidden),
            "language":    self.head_language(hidden),
            "emergency":   self.head_emergency(hidden).squeeze(-1),
            "location":    self.head_location(hidden),
            "time":        self.head_time(hidden),
            "sentiment":   self.head_sentiment(hidden).squeeze(-1),
        }
        return logits

    def forward(self, input_ids: torch.Tensor, char_ids: torch.Tensor) -> dict:
        hidden = self.encode(input_ids, char_ids)
        return self.classify(hidden)

    def temperature_scale(self, logits: torch.Tensor) -> torch.Tensor:
        return logits / (self.temperature.clamp(min=1e-6))


# ── Inference Engine ──────────────────────────────────────────────────────────
class CityFixInference:
    """Load trained model and run predictions."""

    def __init__(self, model_dir: str = MODEL_DIR, data_dir: str = DATA_DIR):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self._load(model_dir, data_dir)

    def _load(self, model_dir: str, data_dir: str):
        vocab_path = os.path.join(data_dir, "vocab.json")
        label_path = os.path.join(data_dir, "label_map.json")
        weights_path = os.path.join(model_dir, "cityfix.pt")
        config_path = os.path.join(model_dir, "config.json")

        with open(vocab_path, encoding="utf-8") as f:
            vocab = json.load(f)
        with open(label_path, encoding="utf-8") as f:
            self.label_maps = json.load(f)
        with open(config_path, encoding="utf-8") as f:
            cfg = json.load(f)

        self.tokenizer = CityFixTokenizer(vocab)
        self.model = CityFixModel(
            vocab_size=cfg["vocab_size"],
            embed_dim=cfg.get("embed_dim", 128),
            hidden_dim=cfg.get("hidden_dim", 256),
            num_categories=cfg.get("num_categories", 12),
            num_subcategories=cfg.get("num_subcategories", 120),
            num_urgencies=cfg.get("num_urgencies", 4),
            num_emotions=cfg.get("num_emotions", 4),
            num_languages=cfg.get("num_languages", 3),
        )
        self.model.load_state_dict(torch.load(weights_path, map_location=self.device))
        self.model.to(self.device)
        self.model.eval()

    def _run_model(self, input_ids, char_ids, mc_dropout=0, mc_samples=8):
        if mc_dropout > 0:
            self.model.train()
            logits_accum = None
            for _ in range(mc_samples):
                logits = self.model(input_ids, char_ids)
                if logits_accum is None:
                    logits_accum = {k: v.detach().float() for k, v in logits.items()}
                else:
                    for k in logits_accum:
                        logits_accum[k] += logits[k].detach().float()
            for k in logits_accum:
                logits_accum[k] /= mc_samples
            self.model.eval()
            return logits_accum

        return self.model(input_ids, char_ids)

    @torch.no_grad()
    def predict(self, text: str, mc_dropout: int = 0, mc_samples: int = 8) -> dict:
        ids = self.tokenizer.batch_encode([text]).to(self.device)
        char_ids = self.tokenizer.batch_encode_char([text]).to(self.device)

        out = self._run_model(ids, char_ids, mc_dropout=mc_dropout, mc_samples=mc_samples)

        # apply temperature to classification logits before softmax
        cat_logits = self.model.temperature_scale(out["category"])
        sub_logits = self.model.temperature_scale(out["subcategory"])

        cat_probs = F.softmax(cat_logits, dim=-1)
        sub_probs = F.softmax(sub_logits, dim=-1)

        cat_idx = cat_probs.argmax(1).item()
        sub_idx = sub_probs.argmax(1).item()
        urg_idx = out["urgency"].argmax(1).item()
        emo_idx = out["emotion"].argmax(1).item()
        lang_idx = out["language"].argmax(1).item()
        loc_idx = out["location"].argmax(1).item()
        time_idx = out["time"].argmax(1).item()

        emergency = torch.sigmoid(out["emergency"])[0].item() > 0.5
        sentiment_intensity = torch.tanh(out["sentiment"])[0].item()

        category = self.label_maps["category_inv"][str(cat_idx)]
        sub_raw = self.label_maps["subcategory_inv"][str(sub_idx)]
        subcategory = sub_raw.split("||")[-1] if "||" in sub_raw else sub_raw
        urgency = self.label_maps["urgency_inv"][str(urg_idx)]
        emotion = self.label_maps["emotion_inv"][str(emo_idx)]
        language = self.label_maps["language_inv"][str(lang_idx)]

        location = "yes" if loc_idx == 1 else "no"
        time_mention = "yes" if time_idx == 1 else "no"

        cat_conf = cat_probs.max().item()
        sub_conf = sub_probs.max().item()

        top3 = cat_probs.topk(3)
        alternatives = [
            self.label_maps["category_inv"][str(i.item())]
            for i in top3.indices[0]
        ]

        return {
            "category": category,
            "subcategory": subcategory,
            "urgency": urgency,
            "emotion": emotion,
            "language": language,
            "is_emergency": emergency,
            "location": location,
            "time": time_mention,
            "sentiment_intensity": round(sentiment_intensity, 3),
            "confidence": round(cat_conf, 3),
            "sub_confidence": round(sub_conf, 3),
            "alternatives": alternatives,
        }

    @torch.no_grad()
    def predict_batch(self, texts: list[str], mc_dropout: int = 0, mc_samples: int = 8) -> list[dict]:
        results = []
        for t in texts:
            results.append(self.predict(t, mc_dropout=mc_dropout, mc_samples=mc_samples))
        return results



