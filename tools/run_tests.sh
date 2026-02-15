#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

echo -e "${YELLOW}=== NovoJogo Test Suite ===${NC}"
echo ""

# --- GUT Tests (GDScript) ---
echo -e "${YELLOW}[1/2] Running GUT tests...${NC}"
cd "$PROJECT_DIR/godot"
if godot-4 --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit 2>&1; then
    echo -e "${GREEN}GUT tests passed!${NC}"
else
    echo -e "${RED}GUT tests FAILED!${NC}"
    FAILED=1
fi

echo ""

# --- Foundry Tests (Solidity) ---
echo -e "${YELLOW}[2/2] Running Foundry tests...${NC}"
cd "$PROJECT_DIR/contracts"
if forge test -vvv 2>&1; then
    echo -e "${GREEN}Foundry tests passed!${NC}"
else
    echo -e "${RED}Foundry tests FAILED!${NC}"
    FAILED=1
fi

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}=== All tests passed! ===${NC}"
    exit 0
else
    echo -e "${RED}=== Some tests FAILED! ===${NC}"
    exit 1
fi
