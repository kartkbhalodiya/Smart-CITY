"""
CityFix LLM — Training Script
Run: python train.py
"""
import json
import os
import random
import time

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset

from model import CityFixModel, CityFixTokenizer

DATA_DIR  = os.path.join(os.path.dirname(__file__), "data")
MODEL_DIR = os.path.join(os.path.dirname(__file__), "saved_model")
os.makedirs(MODEL_DIR, exist_ok=True)

EPOCHS     = 30
BATCH_SIZE = 64
LR         = 1e-3
MAX_LEN    = 64
CHAR_LEN   = 256
DROPOUT    = 0.3
PATIENCE   = 5
DEVICE     = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ── Dataset ────────────────────────────────────────────────────────────────────
class ComplaintDataset(Dataset):
    def __init__(self, samples, tokenizer, label_maps, max_len=MAX_LEN, max_char_len=CHAR_LEN):
        self.samples    = samples
        self.tokenizer  = tokenizer
        self.label_maps = label_maps
        self.max_len    = max_len
        self.max_char_len = max_char_len

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        s = self.samples[idx]
        ids      = self.tokenizer.encode(s["text"], self.max_len)
        char_ids = self.tokenizer.encode_char(s["text"], self.max_char_len)
        sub_key  = f"{s['category']}||{s['subcategory']}"

        sentiment_map = {"neutral": 0.3, "frustrated": 0.7, "scared": 0.6, "angry": 0.9}

        return {
            "ids":         torch.tensor(ids,      dtype=torch.long),
            "char_ids":    torch.tensor(char_ids, dtype=torch.long),
            "category":    torch.tensor(self.label_maps["category"].get(s["category"], 0),              dtype=torch.long),
            "subcategory": torch.tensor(self.label_maps["subcategory"].get(sub_key, 0),                 dtype=torch.long),
            "urgency":     torch.tensor(self.label_maps["urgency"].get(s.get("urgency", "low"), 0),     dtype=torch.long),
            "emotion":     torch.tensor(self.label_maps["emotion"].get(s.get("emotion", "neutral"), 0), dtype=torch.long),
            "language":    torch.tensor(self.label_maps["language"].get(s.get("language", "english"), 0), dtype=torch.long),
            "emergency":   torch.tensor(float(s.get("is_emergency", False)), dtype=torch.float),
            "location":    torch.tensor(1 if s.get("location") else 0,  dtype=torch.long),
            "time":        torch.tensor(1 if s.get("time_hint") else 0, dtype=torch.long),
            "sentiment":   torch.tensor(sentiment_map.get(s.get("emotion", "neutral"), 0.3), dtype=torch.float),
        }


# ── Loss ───────────────────────────────────────────────────────────────────────
class MultiTaskLoss(nn.Module):
    def __init__(self, label_smoothing=0.1):
        super().__init__()
        self.ce  = nn.CrossEntropyLoss(label_smoothing=label_smoothing)
        self.bce = nn.BCEWithLogitsLoss()
        self.mse = nn.MSELoss()
        self.log_vars = nn.Parameter(torch.zeros(9))

    def forward(self, preds, batch):
        losses = [
            self.ce(preds["category"],    batch["category"]),
            self.ce(preds["subcategory"], batch["subcategory"]),
            self.ce(preds["urgency"],     batch["urgency"]),
            self.ce(preds["emotion"],     batch["emotion"]),
            self.ce(preds["language"],    batch["language"]),
            self.bce(preds["emergency"],  batch["emergency"]),
            self.ce(preds["location"],    batch["location"]),
            self.ce(preds["time"],        batch["time"]),
            self.mse(torch.tanh(preds["sentiment"]), batch["sentiment"]),
        ]
        total = sum(
            torch.exp(-self.log_vars[i]) * losses[i] + self.log_vars[i]
            for i in range(len(losses))
        )
        return total, losses


# ── Helpers ────────────────────────────────────────────────────────────────────
def accuracy(logits, labels):
    return (logits.argmax(1) == labels).float().mean().item()


def train_epoch(model, loader, optimizer, loss_fn):
    model.train()
    total_loss = cat_acc = sub_acc = 0
    for batch in loader:
        batch = {k: v.to(DEVICE) for k, v in batch.items()}
        optimizer.zero_grad()
        preds = model(batch["ids"], batch["char_ids"])
        loss, _ = loss_fn(preds, batch)
        loss.backward()
        nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        total_loss += loss.item()
        cat_acc    += accuracy(preds["category"],    batch["category"])
        sub_acc    += accuracy(preds["subcategory"], batch["subcategory"])
    n = len(loader)
    return total_loss / n, cat_acc / n, sub_acc / n


@torch.no_grad()
def eval_epoch(model, loader, loss_fn):
    model.eval()
    total_loss = cat_acc = sub_acc = 0
    for batch in loader:
        batch = {k: v.to(DEVICE) for k, v in batch.items()}
        preds = model(batch["ids"], batch["char_ids"])
        loss, _ = loss_fn(preds, batch)
        total_loss += loss.item()
        cat_acc    += accuracy(preds["category"],    batch["category"])
        sub_acc    += accuracy(preds["subcategory"], batch["subcategory"])
    n = len(loader)
    return total_loss / n, cat_acc / n, sub_acc / n


# ── Main ───────────────────────────────────────────────────────────────────────
def main():
    print(f"Device: {DEVICE}")

    with open(os.path.join(DATA_DIR, "train.json"),    encoding="utf-8") as f:
        samples = json.load(f)
    with open(os.path.join(DATA_DIR, "vocab.json"),    encoding="utf-8") as f:
        vocab = json.load(f)
    with open(os.path.join(DATA_DIR, "label_map.json"), encoding="utf-8") as f:
        label_maps = json.load(f)

    # Ensure location/time maps exist
    if "location" not in label_maps:
        label_maps["location"] = {"no": 0, "yes": 1}
        label_maps["location_inv"] = {"0": "no", "1": "yes"}
    if "time" not in label_maps:
        label_maps["time"] = {"no": 0, "yes": 1}
        label_maps["time_inv"] = {"0": "no", "1": "yes"}

    print(f"Samples: {len(samples)} | Vocab: {len(vocab)} | Categories: {len(label_maps['category'])}")

    random.shuffle(samples)
    split = int(0.9 * len(samples))
    train_samples, val_samples = samples[:split], samples[split:]

    tokenizer = CityFixTokenizer(vocab)
    train_ds  = ComplaintDataset(train_samples, tokenizer, label_maps)
    val_ds    = ComplaintDataset(val_samples,   tokenizer, label_maps)
    train_dl  = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
    val_dl    = DataLoader(val_ds,   batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    model = CityFixModel(
        vocab_size=len(vocab),
        embed_dim=128,
        hidden_dim=256,
        num_categories=len(label_maps["category"]),
        num_subcategories=len(label_maps["subcategory"]),
        num_urgencies=len(label_maps["urgency"]),
        num_emotions=len(label_maps["emotion"]),
        num_languages=len(label_maps["language"]),
        dropout=DROPOUT,
    ).to(DEVICE)

    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    loss_fn   = MultiTaskLoss().to(DEVICE)
    optimizer = torch.optim.AdamW(
        list(model.parameters()) + list(loss_fn.parameters()),
        lr=LR, weight_decay=1e-4
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS)

    best_val_loss    = float("inf")
    patience_counter = 0

    print("\nEpoch | Train Loss | Val Loss | Cat Acc | Sub Acc | Time")
    print("-" * 65)

    for epoch in range(1, EPOCHS + 1):
        t0 = time.time()
        tr_loss, tr_cat, tr_sub = train_epoch(model, train_dl, optimizer, loss_fn)
        vl_loss, vl_cat, vl_sub = eval_epoch(model, val_dl, loss_fn)
        scheduler.step()
        elapsed = time.time() - t0

        print(f"  {epoch:3d}  | {tr_loss:9.4f}  | {vl_loss:8.4f} | {vl_cat:6.1%}  | {vl_sub:6.1%}  | {elapsed:.1f}s")

        if vl_loss < best_val_loss:
            best_val_loss    = vl_loss
            patience_counter = 0
            torch.save(model.state_dict(), os.path.join(MODEL_DIR, "cityfix.pt"))
            print(f"         Saved best model (val_loss={vl_loss:.4f})")
        else:
            patience_counter += 1
            if patience_counter >= PATIENCE:
                print(f"\nEarly stopping at epoch {epoch}")
                break

    config = {
        "vocab_size":        len(vocab),
        "embed_dim":         128,
        "hidden_dim":        256,
        "num_categories":    len(label_maps["category"]),
        "num_subcategories": len(label_maps["subcategory"]),
        "num_urgencies":     len(label_maps["urgency"]),
        "num_emotions":      len(label_maps["emotion"]),
        "num_languages":     len(label_maps["language"]),
    }
    with open(os.path.join(MODEL_DIR, "config.json"), "w") as f:
        json.dump(config, f, indent=2)

    print(f"\nTraining complete. Best val loss: {best_val_loss:.4f}")
    print(f"Model saved to: {MODEL_DIR}/cityfix.pt")


if __name__ == "__main__":
    main()
