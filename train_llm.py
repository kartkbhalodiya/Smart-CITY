"""
LLM Training Script for Google Colab
Upload this file to Colab and run it
"""

# Install dependencies
print("Installing dependencies...")
import subprocess
import sys
subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "torch", "transformers", "datasets", "accelerate", "peft", "bitsandbytes", "scipy", "sentencepiece", "protobuf"])
print("✅ Installation complete!\n")

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments, Trainer, DataCollatorForLanguageModeling
from datasets import Dataset
from google.colab import files
import json
import os
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import BitsAndBytesConfig
import gc

# ============= CONFIG =============
CONFIG = {
    "model_name": "mistralai/Mistral-7B-v0.1",
    "max_seq_length": 8192,
    "batch_size": 1,
    "gradient_accumulation_steps": 32,
    "learning_rate": 2e-4,
    "num_epochs": 3,
    "warmup_steps": 100,
    "save_steps": 500,
    "logging_steps": 10,
    "output_dir": "./trained_model",
    "use_4bit": True,
    "use_lora": True,
}

print("=" * 60)
print("🤖 LLM TRAINING - HIGH ACCURACY MODE")
print("=" * 60)
print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'No GPU'}")
print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB" if torch.cuda.is_available() else "")
print("=" * 60)

# ============= UPLOAD FILES =============
print("\n📁 UPLOAD YOUR TRAINING FILES")
print("Supported: .txt, .json, .jsonl")
uploaded = files.upload()
file_paths = list(uploaded.keys())
print(f"\n✅ Uploaded {len(file_paths)} files\n")

# ============= LOAD DATA =============
print("📊 Loading data...")
all_texts = []

for fp in file_paths:
    print(f"  Processing {fp}...")
    if fp.endswith('.txt'):
        with open(fp, 'r', encoding='utf-8') as f:
            all_texts.append(f.read())
    elif fp.endswith('.json'):
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if isinstance(data, list):
                all_texts.extend([item.get('text', str(item)) for item in data])
            else:
                all_texts.append(data.get('text', str(data)))
    elif fp.endswith('.jsonl'):
        with open(fp, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    all_texts.append(json.loads(line).get('text', line))

print(f"✅ Loaded {len(all_texts)} samples\n")

# ============= LOAD MODEL =============
print("🔧 Loading model...")

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
)

tokenizer = AutoTokenizer.from_pretrained(CONFIG["model_name"])
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right"

model = AutoModelForCausalLM.from_pretrained(
    CONFIG["model_name"],
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True,
    torch_dtype=torch.float16,
)

model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)
print("✅ Model loaded\n")
model.print_trainable_parameters()

# ============= PREPARE DATASET =============
print("\n🔄 Tokenizing...")

dataset = Dataset.from_dict({"text": all_texts})

def tokenize_function(examples):
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=CONFIG["max_seq_length"],
        padding="max_length",
    )

train_dataset = dataset.map(
    tokenize_function,
    batched=True,
    remove_columns=dataset.column_names,
)

print(f"✅ Dataset ready: {len(train_dataset)} samples\n")

# ============= TRAIN =============
print("🚀 STARTING TRAINING...\n")

training_args = TrainingArguments(
    output_dir=CONFIG["output_dir"],
    num_train_epochs=CONFIG["num_epochs"],
    per_device_train_batch_size=CONFIG["batch_size"],
    gradient_accumulation_steps=CONFIG["gradient_accumulation_steps"],
    learning_rate=CONFIG["learning_rate"],
    warmup_steps=CONFIG["warmup_steps"],
    logging_steps=CONFIG["logging_steps"],
    save_steps=CONFIG["save_steps"],
    save_total_limit=3,
    fp16=True,
    optim="paged_adamw_8bit",
    lr_scheduler_type="cosine",
    gradient_checkpointing=True,
    max_grad_norm=0.3,
    weight_decay=0.001,
    report_to="none",
)

data_collator = DataCollatorForLanguageModeling(tokenizer=tokenizer, mlm=False)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    data_collator=data_collator,
)

gc.collect()
torch.cuda.empty_cache()

trainer.train()

print("\n✅ TRAINING COMPLETE!\n")

# ============= SAVE =============
print("💾 Saving model...")
trainer.save_model(CONFIG["output_dir"])
tokenizer.save_pretrained(CONFIG["output_dir"])
print(f"✅ Saved to {CONFIG['output_dir']}\n")

# ============= TEST =============
print("🧪 Testing model...\n")
model.eval()

test_prompt = "Once upon a time"
inputs = tokenizer(test_prompt, return_tensors="pt").to(model.device)

with torch.no_grad():
    outputs = model.generate(**inputs, max_new_tokens=100, temperature=0.7)

print(f"Prompt: {test_prompt}")
print(f"Output: {tokenizer.decode(outputs[0], skip_special_tokens=True)}\n")

# ============= DOWNLOAD =============
print("📦 Creating download package...")
import shutil
shutil.make_archive('trained_model', 'zip', CONFIG["output_dir"])
files.download('trained_model.zip')
print("✅ DONE! Model downloaded to your computer")
