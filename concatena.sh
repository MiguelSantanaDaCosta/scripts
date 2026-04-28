#!/bin/bash

OUTPUT="combinado.txt"
INCLUDE=()
EXCLUDE=()
IGNORE_HIDDEN=false
MINIMAL_MODE=false
LOGS=false
FORMAT="txt"   # txt | json | ndjson

# -------------------------
# Função para escapar JSON
# -------------------------
escape_json() {
    sed ':a;N;$!ba;s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# -------------------------
# Parse de argumentos
# -------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --include|-i)
            [[ -z "$2" ]] && { echo "Erro: -i precisa de argumento"; exit 1; }
            INCLUDE+=("$2")
            shift
            ;;
        --exclude|-e)
            [[ -z "$2" ]] && { echo "Erro: -e precisa de argumento"; exit 1; }
            EXCLUDE+=("$2")
            shift
            ;;
        --no-hidden|-nh)
            IGNORE_HIDDEN=true
            ;;
        --minimal|-m)
            MINIMAL_MODE=true
            ;;
        --logs|-l)
            LOGS=true
            ;;
        --json|-j)
            FORMAT="json"
            OUTPUT="combinado.json"
            ;;
        --ndjson|-nj)
            FORMAT="ndjson"
            OUTPUT="combinado.ndjson"
            ;;
        *)
            echo "Parâmetro desconhecido: $1"
            exit 1
            ;;
    esac
    shift
done

# -------------------------
# Modo minimal
# -------------------------
if $MINIMAL_MODE; then
    EXCLUDE_DEFAULT=(
        ".git"
        "node_modules"
        "dist"
        "build"
        "target"
        ".venv"
        "__pycache__"
    )
    for path in "${EXCLUDE_DEFAULT[@]}"; do
        EXCLUDE+=("$path")
    done
fi

# -------------------------
# Preparação saída
# -------------------------
> "$OUTPUT"

if [[ "$FORMAT" == "json" ]]; then
    echo '{ "files": [' >> "$OUTPUT"
fi

$LOGS && echo "🔎 Iniciando ($FORMAT)..."

# -------------------------
# Monta find
# -------------------------
FIND_CMD=(find . -type f ! -path "./.git/*" ! -name "$OUTPUT")

$IGNORE_HIDDEN && FIND_CMD+=( ! -path "*/.*" )

for path in "${EXCLUDE[@]}"; do
    FIND_CMD+=( ! -path "./$path/*" )
done

COUNT=0
FIRST=true

# -------------------------
# Execução
# -------------------------
while IFS= read -r -d '' arquivo; do
    rel_path="${arquivo#./}"

    # INCLUDE filter
    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=false
        for inc in "${INCLUDE[@]}"; do
            [[ "$rel_path" == "$inc"* ]] && match=true && break
        done
        $match || continue
    fi

    $LOGS && echo "📄 $rel_path"

    content=$(escape_json < "$arquivo")

    case "$FORMAT" in
        txt)
            {
                printf "===== %s =====\n" "$rel_path"
                cat "$arquivo"
                printf "\n"
            } >> "$OUTPUT"
            ;;
        json)
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ',' >> "$OUTPUT"
            fi
            printf '{ "path": "%s", "content": "%s" }' "$rel_path" "$content" >> "$OUTPUT"
            ;;
        ndjson)
            printf '{"path":"%s","content":"%s"}\n' "$rel_path" "$content" >> "$OUTPUT"
            ;;
    esac

    ((COUNT++))

done < <("${FIND_CMD[@]}" -print0)

# -------------------------
# Finalização JSON
# -------------------------
if [[ "$FORMAT" == "json" ]]; then
    echo '] }' >> "$OUTPUT"
fi

echo "✔ $COUNT arquivos → $OUTPUT"
