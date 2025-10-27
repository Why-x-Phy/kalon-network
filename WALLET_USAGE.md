# Kalon Wallet - Benutzeranleitung

## Wallet erstellen

### Interaktiv (empfohlen):
```bash
./build-v2/kalon-wallet create
# → Es wird nach einem Namen gefragt (optional)
# → Dann nach der Passphrase (optional)
# → Wallet wird als wallet-{name}.json gespeichert
```

**Beispiel:**
```bash
$ ./build-v2/kalon-wallet create
Enter wallet name (leave empty for 'wallet.json'): miner
Enter passphrase (optional): 
Wallet created successfully!
Address: kalon1...
Wallet saved to: wallet-miner.json
```

### Mit Flag:
```bash
# Mit Name
./build-v2/kalon-wallet create --name miner

# Mit Ausgabedatei
./build-v2/kalon-wallet create --output my-wallet.json
```

## Alle Wallets auflisten

```bash
./build-v2/kalon-wallet list
```

**Beispiel:**
```
Available wallets:
  📄 wallet-miner.json
     Address: kalon1...
     Public Key: abc123...

  📄 wallet-test1.json
     Address: kalon1...
     Public Key: def456...
```

## Wallets verwenden

### Miner mit bestimmter Wallet starten:
```bash
# Standard Wallet
./build-v2/kalon-miner-v2 -wallet "$(cat wallet.json | jq -r .address)"

# Benannte Wallet
./build-v2/kalon-miner-v2 -wallet "$(cat wallet-miner.json | jq -r .address)"
```

## Weitere Befehle

- Wallet-Info anzeigen:
```bash
./build-v2/kalon-wallet info --input wallet-miner.json
```

- Balance prüfen:
```bash
./build-v2/kalon-wallet balance --address kalon1...
```

- Transaktion senden (Überweisung):
```bash
# Momentan nur über direkte RPC-Calls möglich
# TODO: Wallet send-Befehl implementieren

# Beispiel mit curl:
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"sendTransaction",
    "params":{
      "from":"kalon1...",
      "to":"kalon1...",
      "amount":1000000,
      "fee":10000
    },
    "id":1
  }'
```

**⚠️ HINWEIS:** Die vollständige Transaktions-Funktionalität mit UTXO-Verwaltung ist noch in Entwicklung. Aktuell kann man Transaktionen senden, sie müssen aber noch in Blöcke eingebaut werden.

- Wallet von Mnemonic importieren (wiederherstellen):
```bash
# Interaktiv (empfohlen für Server-Neustart)
./build-v2/kalon-wallet import
# → Eingabe 1: Mnemonic eingeben (24 Wörter)
# → Eingabe 2: Wallet-Name eingeben (optional, wird zu wallet-{name}.json)
# → Eingabe 3: Passphrase eingeben (optional)
# → Wallet wird wiederhergestellt ✓

# Mit Flag (für Scripts)
./build-v2/kalon-wallet import --mnemonic "word1 word2 ... word24" --output wallet-restored.json

# Wiederherstellung nach Server-Neustart - Beispiel:
./build-v2/kalon-wallet import
# Enter mnemonic phrase: word1 word2 word3 ... word24
# Enter wallet name: miner
# Enter passphrase (optional): 
# → Wallet gespeichert als wallet-miner.json
```

**⚠️ WICHTIG:** Nach einem Server-Neustart kannst du deine Wallet mit dem Mnemonic-Passwort (24 Wörter) wiederherstellen! Speichere den Mnemonic sicher!
