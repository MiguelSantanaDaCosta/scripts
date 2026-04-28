#!/bin/bash

OUTPUT="combinado.txt"
INCLUDE=()
EXCLUDE=()
IGNORE_HIDDEN=false
MINIMAL_MODE=false
LOGS=false

# -------------------------
# Parse de argumentos
# -------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --include|-i)
            [[ -z "$2" ]] && { echo "Erro: --include/-i precisa de argumento"; exit 1; }
            INCLUDE+=("$2")
            shift
            ;;
        --exclude|-e)
            [[ -z "$2" ]] && { echo "Erro: --exclude/-e precisa de argumento"; exit 1; }
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
# Limpa saída
# -------------------------
> "$OUTPUT"

$LOGS && echo "🔎 Iniciando concatenação..."
$MINIMAL_MODE && $LOGS && echo "⚡ Modo minimal ativado"

# -------------------------
# Monta comando find
# -------------------------
FIND_CMD=(find . -type f ! -path "./.git/*" ! -name "$OUTPUT")

# Ignorar ocultos
if $IGNORE_HIDDEN; then
    FIND_CMD+=( ! -path "*/.*" )
fi

# Excluir caminhos
for path in "${EXCLUDE[@]}"; do
    FIND_CMD+=( ! -path "./$path/*" )
done

COUNT=0

# -------------------------
# Execução
# -------------------------
while IFS= read -r -d '' arquivo; do
    rel_path="${arquivo#./}"

    # Filtro INCLUDE
    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=false
        for inc in "${INCLUDE[@]}"; do
            [[ "$rel_path" == "$inc"* ]] && match=true && break
        done
        $match || continue
    fi

    # 👉 LOG opcional
    $LOGS && echo "📄 $rel_path"

    {
        printf "===== %s =====\n" "$rel_path"
        cat "$arquivo"
        printf "\n"
    } >> "$OUTPUT"

    ((COUNT++))

done < <("${FIND_CMD[@]}" -print0)

$LOGS && echo
echo "✔ Concluído: $COUNT arquivos em $OUTPUT"
