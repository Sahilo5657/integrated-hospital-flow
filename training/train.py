#!/usr/bin/env python3
"""
train.py  —  Fine-tune google/flan-t5-base on mtsamples.csv
Task    : Medical transcription  →  short clinical description (summarisation)
Split   : 60% train | 15% validation | 15% test | 10% unused (discarded)
Metrics : ROUGE-1, ROUGE-2, ROUGE-L  (standard for abstractive summarisation)
"""

import os, warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
import torch

from datasets import Dataset, DatasetDict
from transformers import (
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
    DataCollatorForSeq2Seq,
    EarlyStoppingCallback,
)
import evaluate

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
MODEL_ID   = "google/flan-t5-base"
CSV_PATH   = "../mtsamples.csv"       # one level up from training/
OUTPUT_DIR = "checkpoints"
BEST_DIR   = "best-model"
SEED       = 42

# Data split — must sum to ≤ 1.0; the leftover 10% is intentionally discarded
SPLIT_TRAIN = 0.60
SPLIT_VAL   = 0.15
SPLIT_TEST  = 0.15

# Sequence lengths — Flan-T5-base max input is 512 tokens
MAX_INPUT_LEN  = 512
MAX_TARGET_LEN = 128

# ── Hyperparameters ────────────────────────────────────────────────────────────
# Chosen to keep the model generalised (neither overfit nor underfit):
#   • Moderate LR + warmup avoids sharp early overfitting
#   • Weight-decay L2 regularises the weights
#   • Early stopping prevents training past the optimal checkpoint
#   • Effective batch 16 (8 × grad_accum=2) gives stable gradient estimates
LR             = 3e-4
BATCH_SIZE     = 8
GRAD_ACCUM     = 2        # effective batch = 16
MAX_EPOCHS     = 10       # upper bound; early stopping usually fires first
WEIGHT_DECAY   = 0.01
WARMUP_RATIO   = 0.06     # 6 % of total steps used for linear LR warm-up
NUM_BEAMS      = 4        # beam search during evaluation/prediction
EARLY_PATIENCE = 3        # stop after 3 epochs with no val-ROUGE improvement

# Set to your HF repo to push the final model automatically, or leave None
HF_REPO = None   # e.g. "sahilo56/my-medical-summarizer"

# Flan-T5 task prefix
TASK_PREFIX = "summarize medical transcription: "

# ══════════════════════════════════════════════════════════════════════════════
# 1.  DEVICE CHECK
# ══════════════════════════════════════════════════════════════════════════════
device = "cuda" if torch.cuda.is_available() else "cpu"
use_fp16 = device == "cuda"
print(f"\n{'═'*54}")
print(f"  Device : {device.upper()}")
if device == "cpu":
    print("  WARNING: No GPU detected — training will be very slow.")
    print("  Consider running on Google Colab (free GPU) instead.")
print(f"{'═'*54}\n")

# ══════════════════════════════════════════════════════════════════════════════
# 2.  LOAD & CLEAN DATA
# ══════════════════════════════════════════════════════════════════════════════
print("Loading mtsamples.csv …")
df = pd.read_csv(CSV_PATH, index_col=0)
df = df[["description", "transcription"]].dropna()
df["description"]   = df["description"].str.strip()
df["transcription"] = df["transcription"].str.strip()
df = df[(df["description"] != "") & (df["transcription"] != "")]
df = df.sample(frac=1, random_state=SEED).reset_index(drop=True)

n        = len(df)
n_train  = int(n * SPLIT_TRAIN)
n_val    = int(n * SPLIT_VAL)
n_test   = int(n * SPLIT_TEST)
n_unused = n - n_train - n_val - n_test

train_df = df.iloc[:n_train].reset_index(drop=True)
val_df   = df.iloc[n_train            : n_train + n_val].reset_index(drop=True)
test_df  = df.iloc[n_train + n_val    : n_train + n_val + n_test].reset_index(drop=True)
# rows beyond n_train+n_val+n_test are intentionally not used

print(f"\n{'─'*54}")
print(f"  {'SPLIT':<22} {'ROWS':>8}   {'%':>6}")
print(f"{'─'*54}")
print(f"  {'Total (clean)':<22} {n:>8}")
print(f"  {'Train  (60%)':<22} {n_train:>8}   {n_train/n*100:>5.1f}%")
print(f"  {'Validation (15%)':<22} {n_val:>8}   {n_val/n*100:>5.1f}%")
print(f"  {'Test   (15%)':<22} {n_test:>8}   {n_test/n*100:>5.1f}%")
print(f"  {'Unused (10%)':<22} {n_unused:>8}   {n_unused/n*100:>5.1f}%")
print(f"{'─'*54}\n")

# ══════════════════════════════════════════════════════════════════════════════
# 3.  TOKENISE
# ══════════════════════════════════════════════════════════════════════════════
print("Loading tokeniser …")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

def preprocess(batch):
    inputs  = [TASK_PREFIX + t for t in batch["transcription"]]
    targets = batch["description"]

    model_inputs = tokenizer(
        inputs,
        max_length=MAX_INPUT_LEN,
        truncation=True,
        padding=False,
    )
    with tokenizer.as_target_tokenizer():
        labels = tokenizer(
            targets,
            max_length=MAX_TARGET_LEN,
            truncation=True,
            padding=False,
        )
    model_inputs["labels"] = labels["input_ids"]
    return model_inputs

def make_hf_dataset(frame):
    ds = Dataset.from_pandas(frame[["transcription", "description"]])
    return ds.map(preprocess, batched=True, remove_columns=ds.column_names,
                  desc="Tokenising")

print("Tokenising splits …")
dataset = DatasetDict({
    "train":      make_hf_dataset(train_df),
    "validation": make_hf_dataset(val_df),
    "test":       make_hf_dataset(test_df),
})
print(dataset)

# ══════════════════════════════════════════════════════════════════════════════
# 4.  MODEL + COLLATOR
# ══════════════════════════════════════════════════════════════════════════════
print(f"\nLoading {MODEL_ID} …")
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_ID)
n_params = sum(p.numel() for p in model.parameters()) / 1e6
print(f"Parameters: {n_params:.0f}M")

collator = DataCollatorForSeq2Seq(
    tokenizer,
    model=model,
    label_pad_token_id=-100,
    pad_to_multiple_of=8 if use_fp16 else None,
)

# ══════════════════════════════════════════════════════════════════════════════
# 5.  ROUGE METRIC
# ══════════════════════════════════════════════════════════════════════════════
rouge_metric = evaluate.load("rouge")

def compute_metrics(eval_preds):
    preds, labels = eval_preds

    # Some transformers versions return a tuple (preds, decoder_hidden, ...)
    if isinstance(preds, tuple):
        preds = preds[0]

    # -100 is the ignore-index; replace before decoding
    preds  = np.where(preds  != -100, preds,  tokenizer.pad_token_id)
    labels = np.where(labels != -100, labels, tokenizer.pad_token_id)

    decoded_preds  = tokenizer.batch_decode(preds,  skip_special_tokens=True)
    decoded_labels = tokenizer.batch_decode(labels, skip_special_tokens=True)

    decoded_preds  = [p.strip() for p in decoded_preds]
    decoded_labels = [l.strip() for l in decoded_labels]

    scores = rouge_metric.compute(
        predictions=decoded_preds,
        references=decoded_labels,
        use_stemmer=True,
    )
    # Return as percentages
    return {k: round(v * 100, 2) for k, v in scores.items()}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  TRAINING ARGUMENTS
# ══════════════════════════════════════════════════════════════════════════════
steps_per_epoch = max(1, n_train // (BATCH_SIZE * GRAD_ACCUM))
total_steps     = steps_per_epoch * MAX_EPOCHS

print(f"\nTraining plan:")
print(f"  Steps / epoch  : {steps_per_epoch}")
print(f"  Max total steps: {total_steps}")
print(f"  Warmup steps   : {int(total_steps * WARMUP_RATIO)}")

args = Seq2SeqTrainingArguments(
    output_dir=OUTPUT_DIR,

    # Epochs & batches
    num_train_epochs=MAX_EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    per_device_eval_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=GRAD_ACCUM,

    # Optimiser — weight_decay is the L2 regularisation term (prevents overfit)
    learning_rate=LR,
    weight_decay=WEIGHT_DECAY,
    warmup_ratio=WARMUP_RATIO,
    lr_scheduler_type="cosine",   # cosine decay generalises better than linear

    # Evaluation & checkpointing
    evaluation_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="rouge1",
    greater_is_better=True,
    save_total_limit=2,           # keep only the 2 best checkpoints on disk

    # Generation (used during eval)
    predict_with_generate=True,
    generation_max_length=MAX_TARGET_LEN,
    generation_num_beams=NUM_BEAMS,

    # Mixed precision
    fp16=use_fp16,

    # Misc
    seed=SEED,
    logging_steps=50,
    report_to="none",

    # Hub (optional)
    push_to_hub=(HF_REPO is not None),
    hub_model_id=HF_REPO if HF_REPO else "",
)

# ══════════════════════════════════════════════════════════════════════════════
# 7.  TRAINER
# ══════════════════════════════════════════════════════════════════════════════
trainer = Seq2SeqTrainer(
    model=model,
    args=args,
    train_dataset=dataset["train"],
    eval_dataset=dataset["validation"],
    tokenizer=tokenizer,
    data_collator=collator,
    compute_metrics=compute_metrics,
    callbacks=[
        EarlyStoppingCallback(early_stopping_patience=EARLY_PATIENCE),
    ],
)

# ══════════════════════════════════════════════════════════════════════════════
# 8.  TRAIN
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "═"*54)
print("  TRAINING STARTED")
print("═"*54)
trainer.train()

# ══════════════════════════════════════════════════════════════════════════════
# 9.  FINAL EVALUATION
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "═"*54)
print("  EVALUATING ON TEST SET (held-out data)")
print("═"*54)
test_out = trainer.predict(
    dataset["test"],
    metric_key_prefix="test",
)
test_m = test_out.metrics

val_out = trainer.evaluate(dataset["validation"])

train_out = trainer.evaluate(dataset["train"], metric_key_prefix="train")

# ── Generalisation diagnostics ────────────────────────────────────────────────
train_r1 = train_out.get("train_rouge1", 0)
val_r1   = val_out.get("eval_rouge1",  0)
test_r1  = test_m.get("test_rouge1",  0)
gap      = train_r1 - val_r1

if gap > 10:
    verdict = "⚠  POSSIBLE OVERFIT  — train >> val"
elif val_r1 < 15:
    verdict = "⚠  POSSIBLE UNDERFIT — scores very low"
else:
    verdict = "✓  GENERALISED       — train ≈ val ≈ test"

# ══════════════════════════════════════════════════════════════════════════════
# 10.  RESULTS SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
print(f"\n{'═'*54}")
print(f"  DATA SPLIT")
print(f"{'─'*54}")
print(f"  {'Total (clean)':<22} {n:>8} rows")
print(f"  {'Train  (60%)':<22} {n_train:>8} rows   ({n_train/n*100:.1f}%)")
print(f"  {'Validation (15%)':<22} {n_val:>8} rows   ({n_val/n*100:.1f}%)")
print(f"  {'Test   (15%)':<22} {n_test:>8} rows   ({n_test/n*100:.1f}%)")
print(f"  {'Unused (10%)':<22} {n_unused:>8} rows   ({n_unused/n*100:.1f}%)")
print(f"{'─'*54}")
print(f"  ROUGE ACCURACY  (higher = better, max 100)")
print(f"{'─'*54}")
print(f"  {'Metric':<14} {'Train':>8} {'Val':>8} {'Test':>8}")
print(f"  {'─'*42}")
for key in ("rouge1", "rouge2", "rougeL", "rougeLsum"):
    tr = train_out.get(f"train_{key}", 0)
    vl = val_out.get(f"eval_{key}",  0)
    te = test_m.get(f"test_{key}",   0)
    print(f"  {key.upper():<14} {tr:>7.2f}% {vl:>7.2f}% {te:>7.2f}%")
print(f"{'─'*54}")
print(f"  Generalisation: {verdict}")
print(f"  Train−Val gap on ROUGE-1: {gap:+.2f}%")
print(f"{'═'*54}\n")

# ══════════════════════════════════════════════════════════════════════════════
# 11.  SAVE
# ══════════════════════════════════════════════════════════════════════════════
trainer.save_model(BEST_DIR)
tokenizer.save_pretrained(BEST_DIR)
print(f"Best model saved to  → training/{BEST_DIR}/")

if HF_REPO:
    trainer.push_to_hub(commit_message="Fine-tuned flan-t5-base on mtsamples")
    print(f"Model pushed to Hub  → {HF_REPO}")
