#!/bin/bash

function process_hmms {
	
	local hmm_file="$1"
	
	echo "processing hmms"
	
	awk 'BEGIN {hmm_n = "1"; sequence = ""}
		$0~"^>Consensus" {printf("HMM %s\n", hmm_n) > "hmm_seqlist.tmp"; printf("HMM %s\n", hmm_n) > "hmm_list.tmp"; hmm_n += 1}
		NR >= line && $0!~"^>|^#" && x == 1 {sequence = sequence $0}
		NR >= line && $0~"^>|^#" && x == 1 {x = 0; print sequence > "hmm_seqlist.tmp"; sequence = ""}
		$0~"^>tr|^>sp" { gsub(/^>|[[:space:]].*$|_consensus/, ""); print > "hmm_list.tmp"; line = NR; line += 1; x = 1}' "$hmm_file"
		
		
	awk 'BEGIN {id = "";sequence = "";c="0"}
		{getline seqline < "hmm_seqlist.tmp"}
		$0~"^HMM"{if (c>=4) print id > "hmm_list.txt";if (c>=4) print sequence > "hmm_seqlist.txt";id = $0 "\n";sequence = $0 "\n";c="0"}
		$0~"^tr|^sp" {c+=1; id = id $0 "\n"; sequence = sequence seqline "\n"}' hmm_list.tmp
	
	rm hmm_list.tmp
	rm hmm_seqlist.tmp
	
	echo "getting unique sequences"
	
	grep '^tr\|^sp' hmm_list.txt| sort | uniq > uniq_seqs.txt

	echo "completed"
	if (($(grep -c '^HMM' hmm_list.txt) == $(grep -c '^HMM' hmm_list.txt))); then
		echo "number HMMs: " $(grep -c '^HMM' hmm_list.txt)
	else 
		echo "! number HMMs don't match !"
	fi
	}



function get_seqs {
	
	local seq_id="$1"
	
	if echo "$seq_id" | grep -q ^tr; then
		seq=$(grep -A 1 -m 1 -e "$seq_id" data/trembl.fasta | grep -v "^>tr")
	else 
		seq=$(grep -A 1 -m 1 -e "$seq_id" data/sprot.fasta | grep -v "^>sp")
	fi
	
	echo "$seq"

	return
	}
		
function match_hmms {

	local seq_id="$1"
	
	local seq_id_cleaned=$(echo "$seq_id" | grep -oE "[[:alnum:]]*_*[[:alnum:]]*$")
	local SEQ=$(get_seqs $seq_id)
	local lines="$seq_id""_lines"
	local seqs="$seq_id""_seqs"
	local HMMs="$seq_id""_HMMs"
	local positions="$seq_id""_positions"
	local out="hmm_match_out/""$seq_id_cleaned"".csv"
	
	if [ -e $lines ];then
		rm $lines
	fi
	if [ -e $seqs ];then
	rm $seqs
	fi
	if [ -e $HMMs ];then
	rm $HMMs
	fi
	if [ -e $positions ];then
	rm $positions
	fi

	echo "processing ""$seq_id"
	
	awk -v seq=$seq_id_cleaned -v lines="$lines" '
			$0~seq {print NR > lines}' data/hmm_list.txt

	awk -v lines="$lines" -v seqs="$seqs" -v HMMs="$HMMs" '
			BEGIN {getline L < lines}
			$0~/HMM / {hmm=$0; sub(/^.*[[:space:]]/,"",hmm)}
			NR == L {print $0 > seqs; print hmm > HMMs;getline L < lines}' data/hmm_seqlist.txt
	echo "got HMM matching sequences for ""$seq_id_cleaned"
	
	if (($(grep -c . $HMMs) == $(grep -c . $seqs)));then
	
		local seq_list
		mapfile -t seq_list < "$seqs"

		for hmm_seq in ${seq_list[@]};
		do 
			local PAT=$(echo $hmm_seq | sed s/--*/.*/g | sed s/[[:lower:]][[:lower:]]*/.*/g)
			local REV=$(echo $PAT | rev | sed s/\*\./.*/g)
			local SEQ=$(get_seqs $seq_id)

			START=$( echo "$SEQ" | grep -ob -e "$PAT" | grep -oE [0-9]*)
			END=$( echo "$SEQ" | rev | grep -ob -e "$REV" | grep -oE [0-9]*) 
   			END=$((${#SEQ}-$END))

			if [ ! "$START" ];then
				START="1"
				END=${#SEQ}
			fi
			echo "[" $START "," $END "]" >> $positions
		
		done
		
		echo "completed matching for" ,$seq_id_cleaned
		
		awk -v id=$seq_id_cleaned -v HMMs="$HMMs" -v out="$out" '
				BEGIN {line = id; hmms = "id"}
				{line = line "," $0; getline hmm < HMMs; hmms = hmms "," hmm}
				END {print hmms > out; print line > out}' $positions
			
		echo "created file ""$out"
		
		echo "removing files"
		
	else
		echo '! HMM Sequence Mismatch !'
	fi
	rm $lines
	rm $seqs
	rm $HMMs
	rm $positions
	}

mkdir hmm_match_out

export -f get_seqs
export -f match_hmms

mapfile -t seq_list < data/uniq_seqs.txt

printf '%s\n' "${seq_list[@]}"|xargs -I {} -n 1 -P 16 bash -c 'match_hmms "{}"'
	
