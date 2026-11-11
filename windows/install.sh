#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
install_deps=false
check_only=false
for option in "$@"; do
  case "$option" in
    --install-dependencies) install_deps=true ;;
    --check) check_only=true ;;
    *) printf 'Unknown option: %s\n' "$option" >&2; exit 2 ;;
  esac
done
if [[ -z ${WSL_DISTRO_NAME:-} ]]; then
  printf 'Run this installer inside the WSL distro you want to use.\n' >&2
  exit 1
fi
if ! $check_only; then
  args=()
  $install_deps && args+=(--install-dependencies)
  "$script_dir/install-wsl.sh" "${args[@]}"
fi
powershell_path="$(command -v powershell.exe || true)"
if [[ -z $powershell_path ]]; then
  powershell_path="$(wslpath -u 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')"
fi
args=(-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(wslpath -w "$script_dir/Install.ps1")"
  -Distro "$WSL_DISTRO_NAME" -WslUser "$(id -un)" -WslHome "$HOME")
$check_only && args+=(-Check)
$install_deps && args+=(-InstallDependencies)
# A Windows executable must start from a Windows-readable working directory.
cd "$(wslpath -u 'C:\Windows')"
"$powershell_path" "${args[@]}"
