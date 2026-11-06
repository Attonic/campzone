#!/usr/bin/env bash
# Setup do CampZone no Fedora.
# Uso: deixe este script na mesma pasta dos arquivos abaixo e rode:
#   bash setup-fedora.sh
#
# Arquivos esperados ao lado do script:
#   CLAUDE.md  CLAUDE-backend.md  CLAUDE-frontend.md
#   dev-back.md  dev-front.md  reviewer.md  prompt-inicial.md
#
# O script também se copia para <projeto>/scripts/setup-fedora.sh (fica versionado no repo).
set -euo pipefail

GH_USER="Attonic"
REPO="campzone"
PROJ_DIR="${PROJ_DIR:-$HOME/dev/campzone}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FILES=(CLAUDE.md CLAUDE-backend.md CLAUDE-frontend.md dev-back.md dev-front.md reviewer.md prompt-inicial.md)
for f in "${FILES[@]}"; do
  [ -f "$SRC_DIR/$f" ] || { echo "Faltando $f ao lado do script."; exit 1; }
done

echo "==> Instalando dependências (Fedora)"
sudo dnf install -y git gh curl java-21-openjdk-devel nodejs npm moby-engine docker-compose

echo "==> Docker"
sudo systemctl enable --now docker
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "   Você foi adicionado ao grupo docker. Faça logout/login (ou 'newgrp docker') antes de rodar o docker-compose."
fi

echo "==> Versões"
java -version 2>&1 | head -n 1
node --version
npm --version

NODE_MAJOR="$(node --version | sed 's/v\([0-9]*\).*/\1/')"
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Node $NODE_MAJOR é antigo para o Vite. Instale Node 20.19+ ou 22+ e rode de novo."
  exit 1
fi

echo "==> Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi
claude --version || echo "   Se 'claude' não for encontrado, abra um novo terminal (PATH) e rode de novo."

echo "==> GitHub CLI"
gh auth status >/dev/null 2>&1 || gh auth login

echo "==> Projeto em $PROJ_DIR"
mkdir -p "$PROJ_DIR/backend" "$PROJ_DIR/frontend" "$PROJ_DIR/scripts" \
         "$PROJ_DIR/.claude/agents" "$PROJ_DIR/docs/specs" "$PROJ_DIR/docs/adr"

cp "$SRC_DIR/CLAUDE.md"          "$PROJ_DIR/CLAUDE.md"
cp "$SRC_DIR/CLAUDE-backend.md"  "$PROJ_DIR/backend/CLAUDE.md"
cp "$SRC_DIR/CLAUDE-frontend.md" "$PROJ_DIR/frontend/CLAUDE.md"
cp "$SRC_DIR/dev-back.md"        "$PROJ_DIR/.claude/agents/dev-back.md"
cp "$SRC_DIR/dev-front.md"       "$PROJ_DIR/.claude/agents/dev-front.md"
cp "$SRC_DIR/reviewer.md"        "$PROJ_DIR/.claude/agents/reviewer.md"
cp "$SRC_DIR/prompt-inicial.md"  "$PROJ_DIR/docs/prompt-inicial.md"

# Guarda o próprio script no repositório (scripts/), se ainda não estiver lá.
SELF="$SRC_DIR/$(basename "${BASH_SOURCE[0]}")"
DEST="$PROJ_DIR/scripts/setup-fedora.sh"
if [ "$(readlink -f "$SELF")" != "$(readlink -f "$DEST")" ]; then
  cp "$SELF" "$DEST"
fi
chmod +x "$DEST"

cd "$PROJ_DIR"

cat > .gitignore <<'EOF'
# Backend
backend/target/
*.class
application-local.yml
application-local.properties
# Frontend
frontend/node_modules/
frontend/dist/
# Segredos e ambiente
.env
.env.*
!.env.example
# IDE / SO
.idea/
.vscode/
*.iml
.DS_Store
# Claude Code (estado local)
.claude/settings.local.json
EOF

if [ ! -d .git ]; then
  git init -b main
fi
git add -A
git commit -m "chore: estrutura inicial, CLAUDE.md (raiz, backend, frontend) e agentes dev-back/dev-front/reviewer" || true

echo "==> Repositório remoto"
if gh repo view "$GH_USER/$REPO" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$GH_USER/$REPO.git"
  git push -u origin main
else
  gh repo create "$GH_USER/$REPO" --private --source=. --remote=origin --push
fi

cat <<EOF

Pronto. Para começar o MVP:

  cd $PROJ_DIR
  claude "\$(cat docs/prompt-inicial.md)"

O Claude vai ler os CLAUDE.md, criar o docs/BACKLOG.md e iniciar a tarefa 00
com os agentes dev-back, dev-front e reviewer.

O script fica em $PROJ_DIR/scripts/setup-fedora.sh
EOF
