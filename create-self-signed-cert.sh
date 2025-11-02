#!/bin/bash
# Script zum Erstellen eines selbst-signierten SSL-Zertifikats für den Node

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# IP-Adresse (oder ändern zu Domain)
NODE_IP="185.133.249.107"
CERT_DIR="./certs"
CERT_FILE="${CERT_DIR}/node-cert.pem"
KEY_FILE="${CERT_DIR}/node-key.pem"

echo "=== SELBST-SIGNIERTES SSL-ZERTIFIKAT ERSTELLEN ==="
echo ""
echo "Node IP: ${NODE_IP}"
echo "Zertifikat-Verzeichnis: ${CERT_DIR}"
echo ""

# Verzeichnis erstellen
mkdir -p "${CERT_DIR}"

# Zertifikat generieren
echo "Generiere SSL-Zertifikat..."
openssl req -x509 \
    -newkey rsa:4096 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -days 365 \
    -nodes \
    -subj "/C=DE/ST=State/L=City/O=Kalon/CN=${NODE_IP}" \
    -addext "subjectAltName=IP:${NODE_IP},DNS:localhost" \
    2>/dev/null

if [ $? -eq 0 ] && [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo -e "${GREEN}✅ Zertifikat erfolgreich erstellt!${NC}"
    echo ""
    echo "Zertifikat: ${CERT_FILE}"
    echo "Key: ${KEY_FILE}"
    echo ""
    
    # Berechtigungen setzen
    chmod 600 "${KEY_FILE}"
    chmod 644 "${CERT_FILE}"
    
    echo "Dateigröße:"
    ls -lh "${CERT_FILE}" "${KEY_FILE}"
    echo ""
    echo -e "${YELLOW}⚠️ HINWEIS:${NC}"
    echo "   → Dies ist ein selbst-signiertes Zertifikat"
    echo "   → Browser zeigt Warnung beim ersten Zugriff"
    echo "   → OK für Test/Development"
    echo "   → Für Production: Let's Encrypt mit Domain verwenden"
    echo ""
else
    echo -e "${RED}❌ Fehler beim Erstellen des Zertifikats!${NC}"
    exit 1
fi

