#!/usr/bin/env python3
"""
train.py  —  Fine-tune google/flan-t5-base on mtsamples.csv
Task    : Medical transcription → short clinical description (abstractive summarisation)
Split   : 60 % train | 15 % validation | 15 % test | 10 % discarded
Metrics : ROUGE-1, ROUGE-2, ROUGE-L  (standard for text summarisation)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 HOW TO RUN IN GOOGLE COLAB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. Open a new Colab notebook  (Runtime → Change runtime type → T4 GPU)

 2. In the first cell, install dependencies:
      !pip install transformers datasets evaluate rouge_score accelerate sentencepiece

 3. Upload mtsamples.csv either:
      Option A — directly from your machine:
        from google.colab import files
        files.upload()            # pick mtsamples.csv → it lands at /content/

      Option B — from Google Drive:
        from google.colab import drive
        drive.mount('/content/drive')
        # then set CSV_PATH below to the Drive path

 4. Upload this train.py to /content/ and run:
      !python train.py

    OR paste the whole file into a single Colab code cell and run it.

 5. After training, the best model is saved to /content/best-model/
    and optionally pushed to your Hugging Face repo (set HF_REPO below).
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

# ══════════════════════════════════════════════════════════════════════════════
# STEP 0 — COLAB PACKAGE INSTALL  (uncomment when running in Colab)
# ══════════════════════════════════════════════════════════════════════════════
# import subprocess, sys
# subprocess.check_call([sys.executable, "-m", "pip", "install", "-q",
#     "transformers", "datasets", "evaluate", "rouge_score",
#     "accelerate", "sentencepiece"])

import os, re, warnings
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
# STEP 1 — CONFIGURATION  (edit these before running)
# ══════════════════════════════════════════════════════════════════════════════
MODEL_ID   = "google/flan-t5-base"

# ── CSV path ──────────────────────────────────────────────────────────────────
# Colab direct-upload  → "/content/mtsamples.csv"
# Colab Google Drive   → "/content/drive/MyDrive/mtsamples.csv"
# Local (from training/) → "../mtsamples.csv"
CSV_PATH   = "/content/mtsamples.csv"

# ── Output dirs ───────────────────────────────────────────────────────────────
OUTPUT_DIR = "/content/checkpoints"   # intermediate checkpoints
BEST_DIR   = "/content/best-model"    # final best model saved here

# ── Hugging Face Hub ──────────────────────────────────────────────────────────
# Set to your repo ID to push automatically after training.
# Run `huggingface-cli login` (or use notebook_login()) before training.
HF_REPO = None   # set to "username/repo-name" to push to HuggingFace Hub

SEED = 42

# ── Data split ────────────────────────────────────────────────────────────────
SPLIT_TRAIN = 0.60
SPLIT_VAL   = 0.15
SPLIT_TEST  = 0.15
# Remaining 10 % is intentionally discarded

# ── Sequence lengths (Flan-T5-base hard max = 512) ───────────────────────────
MAX_INPUT_LEN  = 512   # encoder — clinical notes (truncated if longer)
MAX_TARGET_LEN = 128   # decoder — short description

# ── Preprocessing filters ─────────────────────────────────────────────────────
MIN_TRANSCRIPTION_CHARS = 100   # discard transcriptions shorter than this
MIN_DESCRIPTION_CHARS   = 10    # discard descriptions  shorter than this

# ── Training hyperparameters ──────────────────────────────────────────────────
# These are chosen to produce a generalised model:
#   • LR 3e-4 + cosine schedule → smooth convergence
#   • weight_decay 0.01         → L2 regularisation (prevents overfit)
#   • warmup_ratio 0.06         → avoids destructively large early updates
#   • early stopping patience=3 → halts training before the model memorises data
#   • effective batch 16 (8×2)  → stable gradient signal
LR             = 3e-4
BATCH_SIZE     = 8
GRAD_ACCUM     = 2          # effective batch = 16
MAX_EPOCHS     = 10         # upper bound; early stopping fires first
WEIGHT_DECAY   = 0.01
WARMUP_RATIO   = 0.06
NUM_BEAMS      = 4          # beam search for eval generation quality
EARLY_PATIENCE = 3          # stop if val ROUGE-1 has not improved for 3 epochs

TASK_PREFIX = "summarize medical transcription: "

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — DEVICE CHECK
# ══════════════════════════════════════════════════════════════════════════════
device   = "cuda" if torch.cuda.is_available() else "cpu"
use_fp16 = device == "cuda"

print(f"\n{'═'*58}")
print(f"  Device : {device.upper()}")
if device == "cpu":
    print("  ⚠  No GPU found — training will be very slow on CPU.")
    print("     In Colab: Runtime → Change runtime type → T4 GPU")
print(f"{'═'*58}\n")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — DATA PREPROCESSING
# ══════════════════════════════════════════════════════════════════════════════

# ── 3a. Cleaning functions ────────────────────────────────────────────────────

# Some mtsamples entries have a boilerplate disclaimer appended to the
# transcription text — we strip it so the model never trains on it.
_DISCLAIMER = re.compile(
    r'NOTE\s*:?\s*These?\s+transcribed?\s+medical\s+transcription.*$',
    re.IGNORECASE | re.DOTALL,
)

def clean_transcription(text: str) -> str:
    """
    Full cleaning pipeline for clinical transcription text.

    Steps applied (in order):
      1. Remove the mtsamples boilerplate disclaimer
      2. Decode common HTML entities
      3. Normalise tabs → spaces
      4. Collapse runs of 2+ spaces to one space
      5. Collapse 3+ consecutive blank lines to two (preserve paragraph breaks)
      6. Strip whitespace from every line
      7. Final strip
    """
    if not isinstance(text, str):
        return ""

    # 1. Boilerplate disclaimer
    text = _DISCLAIMER.sub("", text)

    # 2. HTML entities
    text = (text
            .replace("&amp;",  "&")
            .replace("&lt;",   "<")
            .replace("&gt;",   ">")
            .replace("&nbsp;", " ")
            .replace("&#39;",  "'")
            .replace("&quot;", '"'))

    # 3. Tabs → single space
    text = text.replace("\t", " ")

    # 4. Multiple spaces → one space (within a line)
    text = re.sub(r"[ ]{2,}", " ", text)

    # 5. More than two consecutive newlines → two
    text = re.sub(r"\n{3,}", "\n\n", text)

    # 6. Strip each line
    text = "\n".join(line.strip() for line in text.splitlines())

    # 7. Overall strip
    return text.strip()


def clean_description(text: str) -> str:
    """
    Clean the short summary / description text.

    Steps:
      1. Decode HTML entities
      2. Collapse all whitespace variants to a single space
      3. Strip
    """
    if not isinstance(text, str):
        return ""

    text = (text
            .replace("&amp;",  "&")
            .replace("&lt;",   "<")
            .replace("&gt;",   ">")
            .replace("&nbsp;", " "))

    text = re.sub(r"\s+", " ", text)
    return text.strip()


# ── 3b. Load raw CSV ──────────────────────────────────────────────────────────
print("═"*58)
print("  PREPROCESSING PIPELINE")
print("═"*58)

raw_df = pd.read_csv(CSV_PATH, index_col=0)
n_raw  = len(raw_df)
print(f"\n  Raw CSV rows             : {n_raw}")

# ── 3c. Keep only the two columns we need ─────────────────────────────────────
df = raw_df[["description", "transcription"]].copy()

# ── 3d. Drop rows where either column is entirely null ────────────────────────
df = df.dropna(subset=["transcription"])
n_after_drop_txn = len(df)

df = df.dropna(subset=["description"])
n_after_drop_desc = len(df)

print(f"  After dropping null txn  : {n_after_drop_txn}  "
      f"(-{n_raw - n_after_drop_txn})")
print(f"  After dropping null desc : {n_after_drop_desc}  "
      f"(-{n_after_drop_txn - n_after_drop_desc})")

# ── 3e. Apply text cleaning ───────────────────────────────────────────────────
df["transcription"] = df["transcription"].apply(clean_transcription)
df["description"]   = df["description"].apply(clean_description)

# ── 3f. Length filtering ──────────────────────────────────────────────────────
# Very short transcriptions carry no clinical signal.
# Very short descriptions cannot form a meaningful target sentence.
mask_txn  = df["transcription"].str.len() >= MIN_TRANSCRIPTION_CHARS
mask_desc = df["description"].str.len()   >= MIN_DESCRIPTION_CHARS
df = df[mask_txn & mask_desc]
n_after_len = len(df)

removed_by_len = n_after_drop_desc - n_after_len
print(f"  After length filter      : {n_after_len}  "
      f"(-{removed_by_len} too short  "
      f"[txn<{MIN_TRANSCRIPTION_CHARS} or desc<{MIN_DESCRIPTION_CHARS} chars])")

# ── 3g. Deduplication ─────────────────────────────────────────────────────────
# Drop rows with identical transcription text (keep first occurrence).
df = df.drop_duplicates(subset=["transcription"], keep="first")
n_after_dedup = len(df)

removed_by_dedup = n_after_len - n_after_dedup
print(f"  After deduplication      : {n_after_dedup}  "
      f"(-{removed_by_dedup} duplicate transcriptions)")

# ── 3h. Final shuffle ─────────────────────────────────────────────────────────
df = df.sample(frac=1, random_state=SEED).reset_index(drop=True)

print(f"\n  {'─'*52}")
print(f"  Final clean dataset      : {n_after_dedup} rows")
print(f"  Rows removed total       : {n_raw - n_after_dedup}  "
      f"({(n_raw-n_after_dedup)/n_raw*100:.1f}% of raw)")
print(f"  {'─'*52}")

# ── 3i. Sample preview ────────────────────────────────────────────────────────
print("\n  SAMPLE (first 2 rows after cleaning):")
print("  " + "─"*52)
for i in range(min(2, len(df))):
    txn_preview  = df.iloc[i]["transcription"][:120].replace("\n", " ")
    desc_preview = df.iloc[i]["description"][:80]
    print(f"  [{i}] Description : {desc_preview}")
    print(f"       Transcription: {txn_preview}…")
    print()

# ── 3j. Length statistics ─────────────────────────────────────────────────────
txn_chars  = df["transcription"].str.len()
desc_chars = df["description"].str.len()
print(f"  Transcription length (chars): "
      f"min={txn_chars.min()}, "
      f"median={int(txn_chars.median())}, "
      f"max={txn_chars.max()}")
print(f"  Description length   (chars): "
      f"min={desc_chars.min()}, "
      f"median={int(desc_chars.median())}, "
      f"max={desc_chars.max()}")
print(f"{'═'*58}\n")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — DATA SPLIT  (60 / 15 / 15 / 10)
# ══════════════════════════════════════════════════════════════════════════════
n        = len(df)
n_train  = int(n * SPLIT_TRAIN)
n_val    = int(n * SPLIT_VAL)
n_test   = int(n * SPLIT_TEST)
n_unused = n - n_train - n_val - n_test   # ~10 % intentionally discarded

train_df = df.iloc[:n_train].reset_index(drop=True)
val_df   = df.iloc[n_train           : n_train + n_val].reset_index(drop=True)
test_df  = df.iloc[n_train + n_val   : n_train + n_val + n_test].reset_index(drop=True)

print(f"{'═'*58}")
print(f"  DATA SPLIT")
print(f"{'─'*58}")
print(f"  {'Split':<24} {'Rows':>7}   {'Share':>6}")
print(f"  {'─'*40}")
print(f"  {'Total (after preprocessing)':<24} {n:>7}")
print(f"  {'Train          (60 %)':<24} {n_train:>7}   {n_train/n*100:>5.1f} %")
print(f"  {'Validation     (15 %)':<24} {n_val:>7}   {n_val/n*100:>5.1f} %")
print(f"  {'Test           (15 %)':<24} {n_test:>7}   {n_test/n*100:>5.1f} %")
print(f"  {'Unused/discarded(10 %)':<24} {n_unused:>7}   {n_unused/n*100:>5.1f} %")
print(f"{'═'*58}\n")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — TOKENISATION
# ══════════════════════════════════════════════════════════════════════════════
print("Loading tokeniser …")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

def tokenise_batch(batch):
    """
    Encode (input, target) pairs for Seq2Seq training.

    Input  : TASK_PREFIX + transcription   (truncated to MAX_INPUT_LEN)
    Target : description                   (truncated to MAX_TARGET_LEN)

    Note: `text_target=` is the current transformers API for encoding labels.
    The older `tokenizer.as_target_tokenizer()` context manager is deprecated
    and will raise warnings/errors on newer library versions.
    """
    inputs  = [TASK_PREFIX + t for t in batch["transcription"]]
    targets = batch["description"]

    model_inputs = tokenizer(
        inputs,
        max_length=MAX_INPUT_LEN,
        truncation=True,
        padding=False,
    )

    # `text_target` encodes into the decoder vocabulary (same tokeniser for T5)
    label_encodings = tokenizer(
        text_target=targets,
        max_length=MAX_TARGET_LEN,
        truncation=True,
        padding=False,
    )
    model_inputs["labels"] = label_encodings["input_ids"]
    return model_inputs


def build_dataset(frame: pd.DataFrame) -> Dataset:
    ds = Dataset.from_pandas(frame[["transcription", "description"]])
    return ds.map(
        tokenise_batch,
        batched=True,
        remove_columns=ds.column_names,
        desc="Tokenising",
    )


print("Tokenising all splits …")
dataset = DatasetDict({
    "train":      build_dataset(train_df),
    "validation": build_dataset(val_df),
    "test":       build_dataset(test_df),
})
print(dataset)

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6 — MODEL + DATA COLLATOR
# ══════════════════════════════════════════════════════════════════════════════
print(f"\nLoading {MODEL_ID} …")
model    = AutoModelForSeq2SeqLM.from_pretrained(MODEL_ID)
n_params = sum(p.numel() for p in model.parameters()) / 1e6
print(f"Parameters : {n_params:.0f} M")

collator = DataCollatorForSeq2Seq(
    tokenizer,
    model=model,
    label_pad_token_id=-100,              # -100 is ignored by the loss function
    pad_to_multiple_of=8 if use_fp16 else None,
)

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7 — ROUGE EVALUATION METRIC
# ══════════════════════════════════════════════════════════════════════════════
rouge_metric = evaluate.load("rouge")

def compute_metrics(eval_preds):
    preds, labels = eval_preds

    # Older transformers returns a (preds, decoder_states) tuple
    if isinstance(preds, tuple):
        preds = preds[0]

    # Replace the -100 padding sentinel before decoding
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
    return {k: round(v * 100, 2) for k, v in scores.items()}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8 — TRAINING ARGUMENTS
# ══════════════════════════════════════════════════════════════════════════════
steps_per_epoch = max(1, n_train // (BATCH_SIZE * GRAD_ACCUM))
total_steps     = steps_per_epoch * MAX_EPOCHS

print(f"\n  Steps / epoch   : {steps_per_epoch}")
print(f"  Max total steps : {total_steps}")
print(f"  Warmup steps    : {int(total_steps * WARMUP_RATIO)}\n")

training_args = Seq2SeqTrainingArguments(
    output_dir=OUTPUT_DIR,

    # ── Epochs & batches ──────────────────────────────────────────────────────
    num_train_epochs=MAX_EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    per_device_eval_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=GRAD_ACCUM,

    # ── Optimiser (generalisation settings) ───────────────────────────────────
    learning_rate=LR,
    weight_decay=WEIGHT_DECAY,       # L2 regularisation
    warmup_ratio=WARMUP_RATIO,
    lr_scheduler_type="cosine",      # smooth decay; generalises better than step

    # ── Evaluation & checkpointing ────────────────────────────────────────────
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="rouge1",
    greater_is_better=True,
    save_total_limit=2,              # only keep the 2 best checkpoints

    # ── Seq2Seq generation ────────────────────────────────────────────────────
    predict_with_generate=True,
    generation_max_length=MAX_TARGET_LEN,
    generation_num_beams=NUM_BEAMS,

    # ── Mixed precision ───────────────────────────────────────────────────────
    fp16=use_fp16,                   # auto-enabled on GPU, off on CPU

    # ── Misc ──────────────────────────────────────────────────────────────────
    seed=SEED,
    logging_steps=50,
    report_to="none",

    # Hub push disabled
    push_to_hub=False,
)

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9 — TRAINER
# ══════════════════════════════════════════════════════════════════════════════
trainer = Seq2SeqTrainer(
    model=model,
    args=training_args,
    train_dataset=dataset["train"],
    eval_dataset=dataset["validation"],
    processing_class=tokenizer,   # renamed from `tokenizer=` in transformers >= 4.46
    data_collator=collator,
    compute_metrics=compute_metrics,
    callbacks=[
        EarlyStoppingCallback(early_stopping_patience=EARLY_PATIENCE),
    ],
)

# ══════════════════════════════════════════════════════════════════════════════
# STEP 10 — TRAIN
# ══════════════════════════════════════════════════════════════════════════════
print("═"*58)
print("  TRAINING  —  watch eval/rouge1 each epoch")
print("═"*58)
trainer.train()

# ══════════════════════════════════════════════════════════════════════════════
# STEP 11 — FINAL EVALUATION
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "═"*58)
print("  EVALUATING ON HELD-OUT TEST SET")
print("═"*58)

# Test set
test_out = trainer.predict(dataset["test"], metric_key_prefix="test")
test_m   = test_out.metrics

# Validation set (best checkpoint, loaded automatically)
val_out = trainer.evaluate(dataset["validation"])

# Train-set sample (300 rows) — gives a quick overfit diagnostic without
# running inference over all 3000 training examples (that takes too long).
train_sample = dataset["train"].select(range(min(300, len(dataset["train"]))))
train_out    = trainer.evaluate(train_sample, metric_key_prefix="train")

# ── Generalisation verdict ────────────────────────────────────────────────────
train_r1 = train_out.get("train_rouge1", 0)
val_r1   = val_out.get("eval_rouge1",   0)
test_r1  = test_m.get("test_rouge1",    0)
gap      = train_r1 - val_r1

if gap > 10:
    verdict = "⚠  OVERFIT  — train ROUGE >> val ROUGE (gap > 10 pts)"
elif val_r1 < 15:
    verdict = "⚠  UNDERFIT — all ROUGE scores are very low (< 15)"
else:
    verdict = "✓  GENERALISED — train ≈ val ≈ test"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 12 — RESULTS TABLE
# ══════════════════════════════════════════════════════════════════════════════
print(f"\n{'═'*58}")
print(f"  FINAL RESULTS SUMMARY")
print(f"{'─'*58}")
print(f"  DATA SPLIT")
print(f"  {'─'*52}")
print(f"  {'Total (preprocessed)':<28} {n:>6} rows")
print(f"  {'Train        (60 %)':<28} {n_train:>6} rows  ({n_train/n*100:.1f}%)")
print(f"  {'Validation   (15 %)':<28} {n_val:>6} rows  ({n_val/n*100:.1f}%)")
print(f"  {'Test         (15 %)':<28} {n_test:>6} rows  ({n_test/n*100:.1f}%)")
print(f"  {'Discarded    (10 %)':<28} {n_unused:>6} rows  ({n_unused/n*100:.1f}%)")
print(f"{'─'*58}")
print(f"  ROUGE ACCURACY  (% — higher is better, max = 100)")
print(f"  {'─'*52}")
print(f"  {'Metric':<14}  {'Train*':>9}  {'Val':>9}  {'Test':>9}")
print(f"  {'─'*52}")
for key in ("rouge1", "rouge2", "rougeL", "rougeLsum"):
    tr = train_out.get(f"train_{key}", 0)
    vl = val_out.get(f"eval_{key}",   0)
    te = test_m.get(f"test_{key}",    0)
    print(f"  {key.upper():<14}  {tr:>8.2f}%  {vl:>8.2f}%  {te:>8.2f}%")
print(f"  {'─'*52}")
print(f"  * Train ROUGE measured on a 300-row subsample (for speed)")
print(f"{'─'*58}")
print(f"  Generalisation : {verdict}")
print(f"  Train−Val gap  : {gap:+.2f} pts on ROUGE-1")
print(f"{'═'*58}\n")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 13 — SAVE & PUSH TO HUB
# ══════════════════════════════════════════════════════════════════════════════
trainer.save_model(BEST_DIR)
tokenizer.save_pretrained(BEST_DIR)
print(f"Best model saved → {BEST_DIR}/")

print("Hub push disabled — take a screenshot of the results table above.")
