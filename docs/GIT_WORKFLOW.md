# Kalon Network - Git Workflow Anleitung

## 🔄 **Git Grundlagen**

### **Repository Setup:**
```bash
# Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Aktueller Branch prüfen
git branch

# Alle Branches anzeigen
git branch -a

# Remote Repository prüfen
git remote -v
```

---

## 📋 **Täglicher Workflow**

### **1. Updates von Master Branch holen:**
```bash
# Aktuelle Änderungen committen (falls vorhanden)
git add .
git commit -m "Beschreibung der Änderungen"

# Master Branch holen
git fetch origin

# Auf Master Branch wechseln
git checkout master

# Neueste Änderungen pullen
git pull origin master

# Binaries neu bauen
make build
# oder für Windows:
go build -o build/kalon-node.exe cmd/kalon-node/main.go
go build -o build/kalon-miner.exe cmd/kalon-miner/main.go
go build -o build/kalon-wallet.exe cmd/kalon-wallet/main.go
```

### **2. Änderungen committen:**
```bash
# Status prüfen
git status

# Dateien hinzufügen
git add .
# oder spezifische Dateien:
git add cmd/kalon-node/main.go

# Committen
git commit -m "Kurze Beschreibung der Änderungen"

# Pushen
git push origin master
```

---

## 🌿 **Branch Management**

### **Feature Branch erstellen:**
```bash
# Neuen Branch erstellen und wechseln
git checkout -b feature/neue-funktion

# Änderungen machen und committen
git add .
git commit -m "Neue Funktion implementiert"

# Branch pushen
git push origin feature/neue-funktion
```

### **Branch wechseln:**
```bash
# Zu anderem Branch wechseln
git checkout branch-name

# Branch erstellen und wechseln
git checkout -b neuer-branch-name

# Zurück zu Master
git checkout master
```

### **Branch löschen:**
```bash
# Branch löschen (lokal)
git branch -d branch-name

# Branch löschen (remote)
git push origin --delete branch-name

# Alle gelöschten remote branches aufräumen
git remote prune origin
```

---

## 🔀 **Merge & Pull Requests**

### **Merge Konflikte lösen:**
```bash
# Merge Konflikte anzeigen
git status

# Konflikte in Dateien manuell lösen
# Dann:
git add .
git commit -m "Merge Konflikte gelöst"
```

### **Pull Request Workflow:**
```bash
# 1. Feature Branch erstellen
git checkout -b feature/neue-funktion

# 2. Änderungen machen und committen
git add .
git commit -m "Neue Funktion implementiert"

# 3. Branch pushen
git push origin feature/neue-funktion

# 4. Pull Request auf GitHub erstellen
# 5. Nach Merge: Branch löschen
git branch -d feature/neue-funktion
git push origin --delete feature/neue-funktion
```

---

## 🔧 **Hilfreiche Git Befehle**

### **Status und Logs:**
```bash
# Status anzeigen
git status

# Commit History
git log --oneline

# Letzte Commits
git log -5

# Unterschiede anzeigen
git diff

# Staged Änderungen anzeigen
git diff --cached
```

### **Stashing (Temporäres Speichern):**
```bash
# Änderungen stashen
git stash

# Stash Liste anzeigen
git stash list

# Stash anwenden
git stash apply

# Stash anwenden und löschen
git stash pop

# Stash löschen
git stash drop
```

### **Reset und Revert:**
```bash
# Letzten Commit rückgängig machen (nicht gepusht)
git reset --soft HEAD~1

# Dateien zum letzten Commit zurücksetzen
git checkout -- filename

# Commit rückgängig machen (gepusht)
git revert HEAD
```

---

## 🚀 **Release Workflow**

### **Version Tag erstellen:**
```bash
# Version Tag erstellen
git tag -a v1.0.2 -m "Release version 1.0.2"

# Tag pushen
git push origin v1.0.2

# Alle Tags anzeigen
git tag

# Tag löschen (lokal)
git tag -d v1.0.2

# Tag löschen (remote)
git push origin --delete v1.0.2
```

### **Release Branch erstellen:**
```bash
# Release Branch erstellen
git checkout -b release/v1.0.3

# Version in Dateien aktualisieren
# z.B. in cmd/kalon-node/main.go: version = "1.0.3"

# Committen
git add .
git commit -m "Version 1.0.3 Release"

# Pushen
git push origin release/v1.0.3

# Tag erstellen
git tag -a v1.0.3 -m "Release version 1.0.3"
git push origin v1.0.3
```

---

## 🔍 **Debugging & Troubleshooting**

### **Häufige Probleme:**

#### **"Your branch is ahead of origin":**
```bash
# Einfach pushen
git push origin master
```

#### **"Your branch is behind origin":**
```bash
# Pullen
git pull origin master
```

#### **"Merge conflict":**
```bash
# Konflikte anzeigen
git status

# Konflikte in Dateien lösen
# Dann:
git add .
git commit -m "Merge conflict resolved"
```

#### **"Untracked files":**
```bash
# Alle Dateien hinzufügen
git add .

# Oder spezifische Dateien
git add filename

# Oder .gitignore erweitern
echo "filename" >> .gitignore
```

#### **"Remote URL ändern":**
```bash
# Aktuelle URL prüfen
git remote -v

# URL ändern
git remote set-url origin https://github.com/Why-x-Phy/kalon-network.git

# Prüfen
git remote -v
```

---

## 📁 **Datei Management**

### **.gitignore erweitern:**
```bash
# .gitignore bearbeiten
nano .gitignore

# Beispiel Einträge:
# build/
# *.exe
# data-*/
# .env
# logs/
```

### **Große Dateien:**
```bash
# Git LFS installieren (für große Dateien)
git lfs install

# Datei zu LFS hinzufügen
git lfs track "*.bin"
git add .gitattributes
```

---

## 🔐 **Sicherheit & Backup**

### **Backup erstellen:**
```bash
# Repository klonen als Backup
git clone --mirror https://github.com/Why-x-Phy/kalon-network.git kalon-backup.git

# Lokales Backup
tar -czf kalon-backup-$(date +%Y%m%d).tar.gz kalon-network/
```

### **SSH Keys:**
```bash
# SSH Key generieren
ssh-keygen -t ed25519 -C "your-email@example.com"

# Key zu GitHub hinzufügen
cat ~/.ssh/id_ed25519.pub
# In GitHub Settings > SSH Keys einfügen
```

---

## 📊 **Git Statistics**

### **Repository Statistiken:**
```bash
# Commits pro Autor
git shortlog -sn

# Commits pro Tag
git log --pretty=format:"%h %an %s" --since="2024-01-01"

# Datei Änderungen
git log --stat

# Branch Graph
git log --graph --oneline --all
```

---

## 🎯 **Best Practices**

### **Commit Messages:**
```bash
# Gute Commit Messages:
git commit -m "Fix: Proof of Work validation for difficulty 1"
git commit -m "Add: Ubuntu installation scripts"
git commit -m "Update: Version to 1.0.2"
git commit -m "Remove: Debug logging from consensus"

# Schlechte Commit Messages:
git commit -m "fix"
git commit -m "update"
git commit -m "changes"
```

### **Branch Naming:**
```bash
# Gute Branch Namen:
feature/user-authentication
bugfix/mining-difficulty
hotfix/critical-security-issue
release/v1.0.3

# Schlechte Branch Namen:
new-feature
fix
test
branch1
```

### **Workflow:**
1. **Immer** vor dem Arbeiten: `git pull origin master`
2. **Feature Branches** für neue Features verwenden
3. **Kleine, häufige Commits** statt große Commits
4. **Aussagekräftige Commit Messages** schreiben
5. **Pull Requests** für Code Reviews verwenden
6. **Regelmäßig pushen** um Backups zu haben

---

## 🚀 **Schnellstart Git Workflow**

### **Täglicher Start:**
```bash
# 1. Repository updaten
git pull origin master

# 2. Binaries bauen
make build

# 3. Arbeiten...
# 4. Änderungen committen
git add .
git commit -m "Beschreibung"
git push origin master
```

### **Neue Funktion:**
```bash
# 1. Feature Branch erstellen
git checkout -b feature/neue-funktion

# 2. Arbeiten und committen
git add .
git commit -m "Neue Funktion implementiert"

# 3. Pushen
git push origin feature/neue-funktion

# 4. Pull Request erstellen
# 5. Nach Merge: Branch löschen
git checkout master
git branch -d feature/neue-funktion
```

---

**Das Kalon Network Git Workflow ist jetzt vollständig dokumentiert! 🚀**
