function mac-menu() {
    # Ajuda com --help
    if [[ "$1" == "--help" ]]; then
        echo "Gerenciador de MAC - ASUS Vivobook"
        echo "Uso: mac-menu"
        echo ""
        echo "Opções:"
        echo "  Aleatório - Gera um novo MAC aleatório"
        echo "  Celular   - Clona o MAC 68:87:1c:5f:0d:89 (Perfil UMC)"
        echo "  Original  - Restaura o MAC de fábrica"
        return 0
    fi

    # Interface visual com fzf
    local choice=$(echo -e "Aleatório\nCelular (68:87:1c:5f:0d:89)\nOriginal" | fzf --header "Escolha a Identidade de Rede")

    [[ -z "$choice" ]] && return 0

    # Procedimento para evitar o erro 'Device or resource busy'
    echo "Reiniciando interface wlp1s0 para troca de MAC..."
    sudo ip link set dev wlp1s0 down

    case "$choice" in
        "Aleatório") 
            sudo macchanger -r wlp1s0 ;;
        "Celular (68:87:1c:5f:0d:89)") 
            sudo macchanger -m 68:87:1c:5f:0d:89 wlp1s0 ;;
        "Original") 
            sudo macchanger -p wlp1s0 ;;
    esac

    sudo ip link set dev wlp1s0 up
    echo "Interface wlp1s0 ativa com novo endereço."
}
