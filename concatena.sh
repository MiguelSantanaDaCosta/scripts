#!/bin/bash
shopt -s globstar nullglob

OUTPUT="combinado.txt"
rm -f "$OUTPUT"

for arquivo in **/*; do
    # Verifica se é um arquivo regular, não é o próprio arquivo de saída,
    # e não está dentro do diretório .git
    if [[ -f "$arquivo" && "$arquivo" != "$OUTPUT" && "$arquivo" != .git/* ]]; then
        echo "===== $arquivo =====" >> "$OUTPUT"
        cat "$arquivo" >> "$OUTPUT"
        echo -e "\n" >> "$OUTPUT"
    fi
done

echo "Todos os arquivos foram concatenados em $OUTPUT"
