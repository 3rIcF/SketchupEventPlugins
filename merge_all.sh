#!/bin/bash

# --- Konfiguration ---
# Name Ihres Haupt-Branches (meist "main" oder "master")
MAIN_BRANCH="main"

# --- Skript-Logik (bitte ab hier nichts ändern) ---

# Stellt sicher, dass das Skript bei einem Fehler sofort abbricht
set -e

# 1. Zum Haupt-Branch wechseln und ihn aktualisieren
echo "Wechsle zum Branch '$MAIN_BRANCH' und aktualisiere ihn..."
git checkout $MAIN_BRANCH
git pull origin $MAIN_BRANCH
echo ""

# 2. Alle veralteten Referenzen zu gelöschten Branches entfernen
echo "Räume lokale Branch-Referenzen auf..."
git fetch --prune
echo ""

# 3. Alle Remote-Branches holen (ohne den Haupt-Branch und HEAD)
echo "Suche nach allen zu mergenden Branches..."
BRANCHES_TO_MERGE=$(git branch -r | grep 'origin/' | grep -v "HEAD" | grep -v "origin/$MAIN_BRANCH" | sed 's/origin\///')

if [ -z "$BRANCHES_TO_MERGE" ]; then
  echo "Keine Branches zum Mergen gefunden. Alles ist bereits auf dem neuesten Stand."
  exit 0
fi

echo "Folgende Branches werden zusammengeführt: "
echo "$BRANCHES_TO_MERGE"
echo ""

# 4. Schleife durch jeden Branch und führe ihn zusammen
for branch in $BRANCHES_TO_MERGE; do
  echo "--- Starte Merge für Branch: $branch ---"
  
  # Führe den Merge durch
  echo "Führe 'git merge' aus..."
  git merge --no-ff "origin/$branch" -m "Merge branch '$branch' into $MAIN_BRANCH"
  
  # Pushe den zusammengeführten Stand zum Server
  echo "Pushe die Änderungen nach GitHub..."
  git push origin $MAIN_BRANCH
  
  # Lösche den Branch auf dem Server
  echo "Lösche den Branch '$branch' auf GitHub..."
  git push origin --delete "$branch"
  
  echo "--- Erfolgreich abgeschlossen für Branch: $branch ---"
  echo ""
done

echo "*****************************************************"
echo "Alle Branches wurden erfolgreich zusammengeführt!"
echo "*****************************************************"