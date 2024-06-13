import time
import torch
import pandas as pd
import pickle as pkl
from transformers import BertForMaskedLM, BertTokenizer, AutoModelForCausalLM, AutoTokenizer, LineByLineTextDataset, DataCollatorForLanguageModeling, Trainer, TrainingArguments

from accelerate import Accelerator

accelerator = Accelerator()

torch.set_default_dtype(torch.float32)

# Load BERT and its tokenizer
bert_model = BertForMaskedLM.from_pretrained('microsoft/BiomedNLP-BiomedBERT-base-uncased-abstract')
bert_tokenizer = BertTokenizer.from_pretrained('microsoft/BiomedNLP-BiomedBERT-base-uncased-abstract',do_lower_case=False)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
#bert_model.to(device)

with open('/data/shane/PROCILLA/vocab_seqs.pkl', 'rb') as f:
   vocab = pkl.load(f)

seq_toks = [i[0] for i in vocab.items()]

bert_tokenizer.add_tokens(seq_toks)
bert_model.resize_token_embeddings(len(bert_tokenizer))

data_collator = DataCollatorForLanguageModeling(
    tokenizer=bert_tokenizer, mlm=True, mlm_probability=0.15
)

from peft import LoraConfig, TaskType, get_peft_model

peft_config = LoraConfig(inference_mode=False, r=4, lora_alpha=32, lora_dropout=0.1)

model = get_peft_model(bert_model, peft_config)
model.print_trainable_parameters()

from peft import LoraConfig, TaskType, get_peft_model

peft_config = LoraConfig(inference_mode=False, r=4, lora_alpha=32, lora_dropout=0.1)

model = get_peft_model(bert_model, peft_config)
model.print_trainable_parameters()
model.to(accelerator.device)

dataset= LineByLineTextDataset(
    tokenizer = bert_tokenizer,
    file_path = '/data/shane/PROCILLA/med_corpus.txt',
    block_size = 512  # maximum sequence length
)
len(dataset)

training_args = TrainingArguments(
    output_dir='/data/shane/PROCILLA/BERT_outs/',
    overwrite_output_dir=True,
    num_train_epochs=1,
    per_device_train_batch_size=1,
    save_steps=10_000,
    save_total_limit=2,
    dataloader_num_workers=accelerator.num_processes
)

trainer = accelerator.prepare(Trainer(
    model=model,
    args=training_args,
    data_collator=data_collator,
    train_dataset=dataset,
))

trainer.train()
trainer.save_model('/data/shane/PROCILLA/model/')