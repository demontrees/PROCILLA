import pandas as pd
from concurrent.futures import ThreadPoolExecutor

prots = pd.read_csv('/mnt/data/shane/prots.csv')

x=len(prots.index)
prots.loc[x] = prots.columns.to_list()
prots.columns = ['pdb','chain','name','seq']

prot_names = pd.read_csv('/mnt/data/shane/prot_names.csv')

prot_names.drop(columns=['Unnamed: 0','X'], inplace=True)

prot_dict={}

def fill_dict(idx):
    prot_dict[prot_names['pdb'].iloc[idx].lower()]={'syns':[str(x).lower() for x in prot_names.iloc[idx]]}
    prot_dict[prot_names['pdb'].iloc[idx].lower()]['name']=prots.loc[(prots == prot_names['pdb'].iloc[idx].lower()).any(axis=1)]['name'].to_list()[0].lower().strip()
    prot_dict[prot_names['pdb'].iloc[idx].lower()]['seq']=prots.loc[(prots == prot_names['pdb'].iloc[idx].lower()).any(axis=1)]['seq'].to_list()[0].lower().strip()
    print(idx)
	
with ThreadPoolExecutor(max_workers=96) as executor:
    executor.map(fill_dict, prot_names.index)
	
import pickle as pkl

with open('prot_dict.pickle', 'wb') as handle:
    pkl.dump(prot_dict,handle, protocol=pkl.HIGHEST_PROTOCOL)
	
corpus = pd.read_csv('/data/macaulay/GeneLLM2/contrastive/filtered_output3.tsv', sep='\t')

def match_syns(word):
    prot=[x for x in prot_dict.keys if word in prot_dict[x]['name'] or word in prot_dict[x]['syns']]
    if len(prot)>0:
        return word + ' ' + prot_dict[prot[0]]['seq']
    else:
        return word
		
def insert_AAs(idx):
    text = corpus['Article_text'][idx]
    text = text.split()
    corpus['Article_text'][idx] = ' '.join([match_syns(x.lower()) for x in text])
    print(idx)
	
with ThreadPoolExecutor(max_workers=96) as executor:
    executor.map(insert_AAs, corpus.index)