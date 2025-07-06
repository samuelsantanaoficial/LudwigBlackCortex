#!/bin/bash

# --- Configuração ---
SFZ_FILE="output.sfz"   # Nome do arquivo SFZ de saída

# --- Verificação de argumentos ---
if [ -z "$1" ]; then
    echo "❌ Uso: $0 <caminho_da_pasta> [nome_da_articulação]"
    exit 1
fi

SAMPLES_DIR="$1"
TARGET_ARTICULATION="$2"   # Argumento opcional

# --- Verificação do diretório ---
if [ ! -d "$SAMPLES_DIR" ]; then
    echo "❌ Diretório não encontrado: $SAMPLES_DIR"
    exit 1
fi

if [ -z "$(ls "$SAMPLES_DIR"/*.wav 2>/dev/null)" ]; then
    echo "❌ Nenhum arquivo .wav encontrado em: $SAMPLES_DIR"
    exit 1
fi

# --- Extração de parâmetros ---
ARTICULATIONS=$(ls "$SAMPLES_DIR" | grep -oP '^([^_]+_[^_]+)' | sort -u)
MIC_LIST=$(ls "$SAMPLES_DIR" | grep -oP 'mic-\K[^\.]+' | sort -u)
ROUND_ROBINS=($(ls "$SAMPLES_DIR" | grep -oP '_([A-Z]+)_vel' | cut -d'_' -f2 | sort -u))
NUM_ROUND_ROBINS=${#ROUND_ROBINS[@]}

# Filtro por articulação se especificado
if [ -n "$TARGET_ARTICULATION" ]; then
    ARTICULATIONS=$(echo "$ARTICULATIONS" | grep -w "$TARGET_ARTICULATION")
    if [ -z "$ARTICULATIONS" ]; then
        echo "❌ Articulação não encontrada: $TARGET_ARTICULATION"
        exit 1
    fi
fi

# --- Cabeçalho SFZ ---
cat > "$SFZ_FILE" <<EOF
<control> default_path=$SAMPLES_DIR
EOF

# --- Processamento ---
for artic in $ARTICULATIONS; do
    echo -e "\n// === Articulação: $artic ===\n<master> seq_length=$NUM_ROUND_ROBINS" >> "$SFZ_FILE"

    for mic in $MIC_LIST; do
        echo -e "\n// --- Mic: $mic ---" >> "$SFZ_FILE"

        # Adiciona contador de posição
        rr_position=1
        for rr in "${ROUND_ROBINS[@]}"; do
            # Lista todos os samples para este grupo
            samples=($(ls "$SAMPLES_DIR"/${artic}_${rr}_vel*_mic-${mic}.wav 2>/dev/null))
            total_vel=${#samples[@]}

            [ $total_vel -eq 0 ] && continue

            echo "<group> seq_position=$rr_position // Round-Robin: $rr" >> "$SFZ_FILE"

            # Processa cada velocity
            for ((i=0; i<total_vel; i++)); do
                sample=$(basename "${samples[$i]}")
                vel=$(echo "$sample" | grep -oP '_vel\K\d+')

                lovel=$(( i * (127 / total_vel) ))
                hivel=$(( (i + 1) * (127 / total_vel) - 1 ))
                [ $i -eq $((total_vel - 1)) ] && hivel=127

                echo "<region> sample=$sample lovel=$lovel hivel=$hivel" >> "$SFZ_FILE"
            done

            ((rr_position++))  # Incrementa a posição para o próximo RR
        done
    done
done

echo -e "\n✅ SFZ gerado com sucesso: $SFZ_FILE"
