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

- Wallet von Mnemonic importieren (wiederherstellen):
```bash
# Mit Flag (empfohlen für Scripts)
./build-v2/kalon-wallet import --mnemonic "word1 word2 ... word24" --output wallet-restored.json

# Interaktiv
./build-v2/kalon-wallet import
# → Nach Mnemonic fragen
# → Nach Namen fragen
# → Wallet wird wiederhergestellt

# Beispiel Wiederherstellung nach Server-Neustart:
./build-v2/kalon-wallet import --mnemonic "your 24 word mnemonic here" --output wallet.json
```

**⚠️ WICHTIG:** Nach einem Server-Neustart ohne Wallet-JSON-Dateien kannst du deine Wallet mit dem Mnemonic wiederherstellen!
