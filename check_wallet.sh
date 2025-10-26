#!/bin/bash
WALLET=$(cat wallet.json 2>/dev/null | jq -r .address)
if [ -z "$WALLET" ]; then
    echo "❌ Keine Wallet gefunden. Bitte wallet.json erstellen."
    exit 1
fi

echo "Wallet: $WALLET"
echo ""

# Check Balance
BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)
echo "💰 Balance: $BALANCE"
echo ""

# Check Block Height
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBestBlock","params":{},"id":1}' | jq -r '.result.number')
echo "📦 Block Height: $HEIGHT"
echo ""

if [ -n "$BALANCE" ] && [ "$BALANCE" != "null" ]; then
    if [ "$BALANCE" -gt "0" ] 2>/dev/null; then
        echo "✅ Wallet hat Balance"
    else
        echo "⚠️  Balance = 0"
    fi
fi
