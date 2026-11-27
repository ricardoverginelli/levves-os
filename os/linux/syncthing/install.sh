#!/usr/bin/bash
# Sync ~/.agents with the NAS through Syncthing (see README.md): starts the user service, then
# pairs this machine and the NAS and shares the "agents" folder both ways, over SSH. The NAS is
# an introducer, so every PC paired with it also syncs with the others. Run
# nas/syncthing/install.sh once first. User-level; needs `sudo dnf -y install syncthing`. Safe
# to re-run. Undo: bash install.sh --uninstall (leaves ~/.agents and the NAS alone)
set -e
cd "$(dirname "$(readlink -f "$0")")"
. ../lib/install.sh

nas=${NAS:-nas}
nas_address=tcp://192.168.68.68:22000
folder=$HOME/.agents

if [ "${1:-}" = --uninstall ]; then
    systemctl --user disable --now syncthing.service 2>/dev/null || true
    echo "Uninstalled (Syncthing stopped; ~/.agents and its config are kept)"
    exit 0
fi

need syncthing ssh
here() { syncthing cli "$@"; }
there() { # STGUIADDRESS in the container makes cli want an API key too; without it, cli reads config.xml
    ssh "$nas" docker exec syncthing env -u STGUIADDRESS syncthing cli "$@"
}
has() { grep -qx "$2" <<<"$($1 config "${@:3}" list)"; } # <here|there> <id> <collection…>

mkdir -p "$folder"
cp stignore "$folder/.stignore"
systemctl --user enable --now syncthing.service
for _ in $(seq 20); do
    here show system >/dev/null 2>&1 && break
    sleep 1
done

me=$(syncthing device-id)
nas_id=$(ssh "$nas" docker exec syncthing syncthing device-id) ||
    {
        echo "No Syncthing on $nas yet: run nas/syncthing/install.sh first" >&2
        exit 1
    }

echo "==> Pairing $(uname -n) and the NAS"
here config devices "$me" name set "$(uname -n)"
has here "$nas_id" devices ||
    here config devices add --device-id "$nas_id" --name nas --addresses "$nas_address" --introducer
has there "$me" devices || there config devices add --device-id "$me" --name "$(uname -n)"

echo "==> Sharing ~/.agents"
has here agents folders || here config folders add --id agents --label agents --path "$folder"
has here "$nas_id" folders agents devices || here config folders agents devices add --device-id "$nas_id"
has there agents folders ||
    there config folders add --id agents --label agents --path /var/syncthing/agents
has there "$me" folders agents devices || there config folders agents devices add --device-id "$me"

sleep 5
echo "Done. NAS connected: $(here show connections | python3 -c \
    "import json,sys; print(json.load(sys.stdin)['connections'].get('$nas_id', {}).get('connected', False))")"
