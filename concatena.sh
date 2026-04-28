#!/bin/bash

OUTPUT="combinado.txt"
INCLUDE=()
EXCLUDE=()
IGNORE_HIDDEN=false
MINIMAL_MODE=false
LOGS=false
FORMAT="txt"

EXCLUDE_DEFAULT=(
    ".git"
    "node_modules"
    "dist"
    "build"
    "target"
    ".venv"
    "__pycache__"
)

# -------------------------
# HELP
# -------------------------
show_help() {
cat << EOF
Uso: $(basename "$0") [OPÇÕES]

Concatena arquivos ou gera estrutura do projeto.

OPÇÕES:

  -i, --include <path>     Incluir apenas caminhos específicos
  -e, --exclude <path>     Excluir caminhos específicos
  -nh, --no-hidden         Ignorar arquivos ocultos

  -m, --minimal            Modo leve (ignora diretórios pesados)
  -l, --logs               Mostrar arquivos sendo processados

  -j, --json               Saída em JSON
  -nj, --ndjson            Saída em NDJSON

  -T,  --tree              Estrutura em árvore (tree)
  -Td, --tree-dirs         Apenas diretórios
  -Tj, --tree-json         Árvore em JSON

  -h, --help               Mostrar ajuda

EXCLUSÕES PADRÃO DO -m:

$(for i in "${EXCLUDE_DEFAULT[@]}"; do echo "  - $i"; done)

EXEMPLOS:

  $0 -m
  $0 -m -nj -l
  $0 -T
  $0 -Td
  $0 -Tj -m

EOF
}

# -------------------------
# JSON escape
# -------------------------
escape_json() {
    sed ':a;N;$!ba;s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# -------------------------
# Parse args
# -------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -i|--include) INCLUDE+=("$2"); shift ;;
        -e|--exclude) EXCLUDE+=("$2"); shift ;;
        -nh|--no-hidden) IGNORE_HIDDEN=true ;;
        -m|--minimal) MINIMAL_MODE=true ;;
        -l|--logs) LOGS=true ;;
        -j|--json) FORMAT="json"; OUTPUT="combinado.json" ;;
        -nj|--ndjson) FORMAT="ndjson"; OUTPUT="combinado.ndjson" ;;
        -T|--tree) FORMAT="tree"; OUTPUT="estrutura.txt" ;;
        -Td|--tree-dirs) FORMAT="tree_dirs"; OUTPUT="estrutura_dirs.txt" ;;
        -Tj|--tree-json) FORMAT="tree_json"; OUTPUT="estrutura.json" ;;
        *) echo "Parâmetro desconhecido: $1"; exit 1 ;;
    esac
    shift
done

# -------------------------
# Minimal mode
# -------------------------
if $MINIMAL_MODE; then
    for path in "${EXCLUDE_DEFAULT[@]}"; do
        EXCLUDE+=("$path")
    done
fi

# -------------------------
# TREE MODES
# -------------------------
if [[ "$FORMAT" == "tree" ]]; then
    $LOGS && echo "🌳 Gerando árvore..."

    TREE_CMD=(tree -a -h -p -D)

    $IGNORE_HIDDEN && TREE_CMD=(tree -h -p -D)

    IGNORE_LIST=("${EXCLUDE[@]}")

    if [[ ${#IGNORE_LIST[@]} -gt 0 ]]; then
        TREE_CMD+=( -I "$(IFS='|'; echo "${IGNORE_LIST[*]}")" )
    fi

    "${TREE_CMD[@]}" > "$OUTPUT"
    echo "✔ Estrutura em $OUTPUT"
    exit 0
fi

if [[ "$FORMAT" == "tree_dirs" ]]; then
    $LOGS && echo "🌳 Diretórios..."

    FIND_CMD=(find . -type d)

    $IGNORE_HIDDEN && FIND_CMD+=( ! -path "*/.*" )

    for path in "${EXCLUDE[@]}"; do
        FIND_CMD+=( ! -path "./$path*" )
    done

    "${FIND_CMD[@]}" | sed 's|^\./||' > "$OUTPUT"

    echo "✔ Diretórios em $OUTPUT"
    exit 0
fi

if [[ "$FORMAT" == "tree_json" ]]; then
    $LOGS && echo "🌳 JSON árvore..."

    echo '{ "files": [' > "$OUTPUT"
    FIRST=true

    while IFS= read -r -d '' f; do
        rel="${f#./}"

        if $IGNORE_HIDDEN && [[ "$rel" == .* ]]; then continue; fi

        for e in "${EXCLUDE[@]}"; do
            [[ "$rel" == "$e"* ]] && continue 2
        done

        [[ -d "$f" ]] && tipo="dir" || tipo="file"

        $FIRST || echo ',' >> "$OUTPUT"
        FIRST=false

        printf '{ "path":"%s","type":"%s" }' "$rel" "$tipo" >> "$OUTPUT"

    done < <(find . -print0)

    echo '] }' >> "$OUTPUT"
    echo "✔ JSON árvore em $OUTPUT"
    exit 0
fi

# -------------------------
# CONCAT MODES
# -------------------------
> "$OUTPUT"
[[ "$FORMAT" == "json" ]] && echo '{ "files": [' >> "$OUTPUT"

FIND_CMD=(find . -type f ! -path "./.git/*" ! -name "$OUTPUT")

$IGNORE_HIDDEN && FIND_CMD+=( ! -path "*/.*" )

for path in "${EXCLUDE[@]}"; do
    FIND_CMD+=( ! -path "./$path/*" )
done

COUNT=0
FIRST=true

while IFS= read -r -d '' arquivo; do
    rel="${arquivo#./}"

    if [[ ${#INCLUDE[@]} -gt 0 ]]; then
        match=false
        for inc in "${INCLUDE[@]}"; do
            [[ "$rel" == "$inc"* ]] && match=true && break
        done
        $match || continue
    fi

    # Ignora binários
    if file --mime "$arquivo" | grep -q binary; then
        $LOGS && echo "⏭️ $rel"
        continue
    fi

    $LOGS && echo "📄 $rel"

    case "$FORMAT" in
        txt)
            {
                printf "===== %s =====\n" "$rel"
                cat "$arquivo"
                printf "\n"
            } >> "$OUTPUT"
            ;;
        json)
            $FIRST || echo ',' >> "$OUTPUT"
            FIRST=false
            printf '{ "path":"%s","content":"' "$rel" >> "$OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$OUTPUT"
            printf '" }' >> "$OUTPUT"
            ;;
        ndjson)
            printf '{"path":"%s","content":"' "$rel" >> "$OUTPUT"
            tr -d '\000' < "$arquivo" | escape_json >> "$OUTPUT"
            printf '"}\n' >> "$OUTPUT"
            ;;
    esac

    ((COUNT++))
done < <("${FIND_CMD[@]}" -print0)

[[ "$FORMAT" == "json" ]] && echo '] }' >> "$OUTPUT"

echo "✔ $COUNT arquivos → $OUTPUT"
