# LLM Training Script for Google Colab with Large Context Support
# Optimized for 40-50M token context windows

import torch
from transformers import (
    AutoTokenizer, AutoModelForCausalLM, 
    TrainingArguments, Trainer, DataCollatorForLanguageModeling
)
from datasets import load_dataset, Dataset
from google.colab import files
import json
import os
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import BitsAndBytesConfig
import gc

# ============= CONFIGURATION =============
CONFIG = {
    "model_name": "mistralai/Mistral-7B-v0.1",  # Change to your preferred base model
    "max_seq_length": 8192,  # Adjust based on GPU memory
    "batch_size": 1,
    "gradient_accumulation_steps": 32,
    "learning_rate": 2e-4,
    "num_epochs": 3,
    "warmup_steps": 100,
    "save_steps": 500,
    "logging_steps": 10,
    "output_dir": "./llm_output",
    "use_4bit": True,  # 4-bit quantization for memory efficiency
    "use_lora": True,  # LoRA for efficient fine-tuning
}

# ============= FILE UPLOAD =============
def upload_training_files():
    """Upload training data files from local machine"""
    print("📁 Upload your training files (txt, json, jsonl, csv)")
    uploaded = files.upload()
    return list(uploaded.keys())

# ============= DATA PREPARATION =============
def prepare_dataset(file_paths, tokenizer):
    """Prepare and tokenize dataset with long context support"""
    all_texts = []
    
    for file_path in file_paths:
        print(f"Processing {file_path}...")
        
        if file_path.endswith('.txt'):
            with open(file_path, 'r', encoding='utf-8') as f:
                all_texts.append(f.read())
        
        elif file_path.endswith('.json'):
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    all_texts.extend([item.get('text', str(item)) for item in data])
                else:
                    all_texts.append(data.get('text', str(data)))
        
        elif file_path.endswith('.jsonl'):
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    item = json.loads(line)
                    all_texts.append(item.get('text', str(item)))
    
    # Create dataset
    dataset = Dataset.from_dict({"text": all_texts})
    
    # Tokenization with chunking for long contexts
    def tokenize_function(examples):
        return tokenizer(
            examples["text"],
            truncation=True,
            max_length=CONFIG["max_seq_length"],
            padding="max_length",
            return_tensors="pt"
        )
    
    tokenized_dataset = dataset.map(
        tokenize_function,
        batched=True,
        remove_columns=dataset.column_names,
        desc="Tokenizing dataset"
    )
    
    return tokenized_dataset

# ============= MODEL SETUP =============
def setup_model_and_tokenizer():
    """Initialize model with quantization and LoRA for efficiency"""
    
    # Quantization config for memory efficiency
    if CONFIG["use_4bit"]:
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16,
            bnb_4bit_use_double_quant=True,
        )
    else:
        bnb_config = None
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(CONFIG["model_name"])
    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"
    
    # Load model
    model = AutoModelForCausalLM.from_pretrained(
        CONFIG["model_name"],
        quantization_config=bnb_config,
        device_map="auto",
        trust_remote_code=True,
        torch_dtype=torch.float16,
    )
    
    # Apply LoRA for efficient fine-tuning
    if CONFIG["use_lora"]:
        model = prepare_model_for_kbit_training(model)
        
        lora_config = LoraConfig(
            r=16,  # LoRA rank
            lora_alpha=32,
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        
        model = get_peft_model(model, lora_config)
        model.print_trainable_parameters()
    
    return model, tokenizer

# ============= TRAINING =============
def train_model(model, tokenizer, train_dataset):
    """Train the model with optimized settings"""
    
    # Training arguments optimized for high accuracy
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
    
    # Data collator
    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False
    )
    
    # Initialize trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        data_collator=data_collator,
    )
    
    # Clear cache before training
    gc.collect()
    torch.cuda.empty_cache()
    
    # Train
    print("🚀 Starting training...")
    trainer.train()
    
    # Save final model
    print("💾 Saving model...")
    trainer.save_model(CONFIG["output_dir"])
    tokenizer.save_pretrained(CONFIG["output_dir"])
    
    return trainer

# ============= MAIN EXECUTION =============
def main():
    """Main training pipeline"""
    
    print("=" * 50)
    print("🤖 LLM Training Pipeline - Large Context Support")
    print("=" * 50)
    
    # Step 1: Upload files
    print("\n📤 Step 1: Upload Training Data")
    file_paths = upload_training_files()
    
    if not file_paths:
        print("❌ No files uploaded. Exiting.")
        return
    
    # Step 2: Setup model
    print("\n🔧 Step 2: Loading Model and Tokenizer")
    model, tokenizer = setup_model_and_tokenizer()
    
    # Step 3: Prepare dataset
    print("\n📊 Step 3: Preparing Dataset")
    train_dataset = prepare_dataset(file_paths, tokenizer)
    print(f"✅ Dataset prepared: {len(train_dataset)} samples")
    
    # Step 4: Train
    print("\n🎯 Step 4: Training Model")
    trainer = train_model(model, tokenizer, train_dataset)
    
    print("\n✅ Training Complete!")
    print(f"📁 Model saved to: {CONFIG['output_dir']}")
    
    # Step 5: Test inference
    print("\n🧪 Testing model...")
    test_prompt = "Once upon a time"
    inputs = tokenizer(test_prompt, return_tensors="pt").to(model.device)
    outputs = model.generate(**inputs, max_new_tokens=100, temperature=0.7)
    print(f"Test output: {tokenizer.decode(outputs[0], skip_special_tokens=True)}")

if __name__ == "__main__":
    main()
