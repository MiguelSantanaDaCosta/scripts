function mac-menu() {
    # Ajuda
    if [[ "$1" == "--help" ]]; then
     echo "Gerenciador de MAC - ASUS Vivobook"
        echo "Uso: mac-menu"
        echo ""
        echo "Opções:"
        echo "  Aleatório      - Gera um novo MAC aleatório"
        echo "  Celular        - Usa o MAC fixo do Perfil UMC"
        echo "  Manual (Input) - Permite digitar um MAC específico"
        echo "  Original       - Restaura o MAC de fábrica"
        echo "Uso: mac-menu"
        return 0
    fi

    # Interface visual
    local choice=$(echo -e "Aleatório\nCelular (68:87:1c:5f:0d:89)\nManual (Digitar MAC)\nOriginal" | fzf --header "Escolha a Identidade de Rede")
    [[ -z "$choice" ]] && return 0

    # Procedimento de troca
    echo "Reiniciando interface wlp1s0..."
    sudo ip link set dev wlp1s0 down

    case "$choice" in
        "Aleatório") sudo macchanger -r wlp1s0 ;;
        "Celular (68:87:1c:5f:0d:89)") sudo macchanger -m 68:87:1c:5f:0d:89 wlp1s0 ;;
        "Manual (Digitar MAC)")
            echo -n "Digite o novo MAC: "
            read manual_mac
            sudo macchanger -m "$manual_mac" wlp1s0 ;;
        "Original") sudo macchanger -p wlp1s0 ;;
    esac

    sudo ip link set dev wlp1s0 up
    echo -e "\nInterface wlp1s0 reativada. Aguardando 5s para IP..."
    sleep 5

    # --- BATERIA DE TESTES DE CONEXÃO ---
    echo -e "\n--- Iniciando Validação de Rede ---"

    # 1. Teste de Gateway (Roteador Local)
    echo -n "[1/4] Ping Gateway (10.0.0.1): "
    ping -c 2 -W 2 10.0.0.1 > /dev/null && echo "OK" || echo "FALHOU"

    # 2. Teste de DNS Externo (Google)
    echo -n "[2/4] Ping DNS Externo (8.8.8.8): "
    ping -c 2 -W 2 8.8.8.8 > /dev/null && echo "OK" || echo "FALHOU"

    # 3. Teste de Resolução de Nome (NSLOOKUP)
    echo -n "[3/4] Resolvendo archlinux.org: "
    nslookup archlinux.org > /dev/null 2>&1 && echo "OK" || echo "FALHOU"

    # 4. Teste de Conexão Web (Site do Arch)
    echo -n "[4/4] HTTP Request Arch Linux: "
    curl -Lis https://www.archlinux.org | grep -q "OK" && echo "CONECTADO" || echo "PORTAL BLOQUEADO"
curl -LIs https://archlinux.org | grep -q "200"
    echo -e "-----------------------------------\n"
}
