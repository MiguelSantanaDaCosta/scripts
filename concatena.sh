#!/bin/bash

OUTPUT="combinado.txt"
INCLUDE=()
EXCLUDE=()
IGNORE_HIDDEN=false
MINIMAL_MODE=false
LOGS=false
FORMAT="txt"

# -------------------------
# HELP
# -------------------------
show_help() {
cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Concatena arquivos de um diretório em um único arquivo (txt, JSON ou NDJSON).

OPÇÕES:

  -i, --include <path>     Incluir apenas caminhos específicos
  -e, --exclude <path>     Excluir caminhos específicos
  -nh, --no-hidden         Ignorar arquivos ocultos

  -m, --minimal            Modo leve (ignora: .git, node_modules, build, etc.)
  -l, --logs               Mostrar arquivos sendo processados

  -j, --json               Saída em JSON (combinado.json)
  -nj, --ndjson            Saída em NDJSON (combinado.ndjson)

  -h, --help               Mostrar esta ajuda

EXEMPLOS:

  $(basename "$0") -m
  $(basename "$0") -i src/ -e tests/
  $(basename "$0") -m -nh -nj -l
  $(basename "$0") --json

DESCRIÇÃO:

  - TXT (padrão): concatenação simples
  - JSON: estrutura única com array de arquivos
  - NDJSON: um JSON por linha (melhor para IA)

OBS:

  - Binários são ignorados automaticamente
  - -j e -nj: o último definido prevalece
  - -m adiciona exclusões padrão, mas não remove exclusões manuais

EOF
}

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
        --help|-h)
            show_help
            exit 0
            ;;
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
            echo "Use --help para ver as opções."
            exit 1
            ;;
    esac
    shift
done

###### -------------------------
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

    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=false
        for inc in "${INCLUDE[@]}"; do
            [[ "$rel_path" == "$inc"* ]] && match=true && break
        done
        $match || continue
    fi

    # Ignora binários
    if file --mime "$arquivo" | grep -q binary; then
        $LOGS && echo "⏭️  Ignorando binário: $rel_path"
        continue
    fi

    $LOGS && echo "📄 $rel_path"

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
            printf '{ "path": "%s", "content": "' "$rel_path" >> "$OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$OUTPUT"
            printf '" }' >> "$OUTPUT"
            ;;
        ndjson)
            printf '{"path":"%s","content":"' "$rel_path" >> "$OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$OUTPUT"
            printf '"}\n' >> "$OUTPUT"
            ;;
    esac

    ((COUNT++))

done < <("${FIND_CMD[@]}" -print0)

if [[ "$FORMAT" == "json" ]]; then
    echo '] }' >> "$OUTPUT"
fi

echo "✔ $COUNT arquivos → $OUTPUT"
