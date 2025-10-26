# Server Test Commands für Balance-Bug Fix

## 🚀 Auf dem Ubuntu-Server ausführen:

```bash
# 1. Repository aktualisieren
cd ~/kalon-network
git pull origin master

# 2. Nodes und Miner stoppen
pkill -f kalon-node
pkill -f kalon-miner

# 3. Alte Builds löschen
rm -rf build-v2/

# 4. Neu kompilieren
./scripts/build-v2.sh

# 5. Node starten
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &

# 6. Warten
sleep 5

# 7. Miner starten
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &

# 8. Warten bis Block gemint ist
sleep 60

# 9. Balance prüfen
curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' | jq

# 10. Logs prüfen
tail -100 node-v2.log | grep "UTXO\|Address"
```

## ✅ Erwartetes Ergebnis:

**Balance sollte > 0 sein!** 🎉

Falls Balance weiterhin 0 ist, schau in die Logs:
```bash
grep "Address:" node-v2.log | tail -20
```
