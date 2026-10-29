#!/usr/bin/env bash
# Sets up a Mac for PropertyOS development: the pinned toolchain from
# .tool-versions, dependencies, and the local Supabase stack.
# Safe to re-run. Run from the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Checking prerequisites =="
if ! command -v brew >/dev/null; then
  echo "Homebrew is required: https://brew.sh"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and re-run."
  exit 1
fi
if [ ! -d "/Applications/Google Chrome.app" ]; then
  echo "Warning: Google Chrome not found; 'flutter run -d chrome' needs it."
fi

echo
echo "== Installing pinned toolchain from .tool-versions =="
command -v mise >/dev/null || brew install mise
mise trust --yes .tool-versions >/dev/null 2>&1 || true
mise install
eval "$(mise activate bash --shims)"

flutter --version | head -1
supabase --version
deno --version | head -1

echo
echo "== Flutter dependencies =="
flutter config --enable-web >/dev/null
flutter pub get

echo
echo "== Local Supabase =="
supabase start
supabase db reset

[ -f .env ] || cp .env.example .env
PUBLISHABLE_KEY=$(supabase status -o env 2>/dev/null \
  | awk -F= '/^(PUBLISHABLE_KEY|ANON_KEY)=/{gsub(/"/, "", $2); print $2; exit}')
if [ -n "${PUBLISHABLE_KEY:-}" ]; then
  sed -i '' "s|^SUPABASE_PUBLISHABLE_KEY=.*|SUPABASE_PUBLISHABLE_KEY=${PUBLISHABLE_KEY}|" .env
  echo "Wrote the local publishable key to .env"
fi

echo
echo "== Done =="
echo "Add mise to your shell once, so the pinned versions are always on PATH:"
echo "  echo 'eval \"\$(mise activate zsh)\"' >> ~/.zshrc"
echo
echo "Run the app:"
echo "  source .env && flutter run -d chrome \\"
echo "    --dart-define=SUPABASE_URL=\"\$SUPABASE_URL\" \\"
echo "    --dart-define=SUPABASE_PUBLISHABLE_KEY=\"\$SUPABASE_PUBLISHABLE_KEY\""
echo
echo "Hosted Supabase (only needed to apply migrations to Alpha):"
echo "  supabase login && supabase link --project-ref <alpha-project-ref>"
