#!/bin/bash
echo "=== WALLET INFO ==="
if [ -f wallet.json ]; then
    echo "Wallet gefunden:"
    echo ""
    cat wallet.json | jq '.address, .publicKey' 2>/dev/null
    echo ""
    WALLET=$(cat wallet.json | jq -r .address)
    BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)
    echo "Balance: $BALANCE"
else
    echo "Keine wallet.json gefunden"
fi
