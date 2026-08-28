#!/usr/bin/env bash
set -Eeuo pipefail

repo="aydiler/md-viewer"
bin_dir="${HOME}/.local/bin"
data_dir="${XDG_DATA_HOME:-${HOME}/.local/share}"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}"
libexec_dir="${HOME}/.local/libexec"
binary_path="${bin_dir}/md-viewer"
maintain_path="${libexec_dir}/md-viewer-maintain"
version_path="${data_dir}/md-viewer/version"
desktop_path="${data_dir}/applications/md-viewer.desktop"
topgrade_path="${config_dir}/topgrade.d/md-viewer.toml"
mode="install"
default_choice=""

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 wurde nicht gefunden."
}

latest_tag() {
    curl -fsSL --retry 3 --retry-delay 2 "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o '"tag_name": *"[^"]*"' \
        | head -n 1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

update_viewer() (
    require curl
    require grep
    require head
    require sed
    require tar
    require install
    require mktemp
    require sha256sum

    [[ "$(uname -s)" == "Linux" ]] || fail "Dieses Skript unterstützt nur Linux."
    [[ "$(uname -m)" == "x86_64" ]] || fail "Dieses Skript unterstützt nur Linux auf x86_64."

    local tag version current asset work_dir
    tag="$(latest_tag)"
    [[ -n "$tag" ]] || fail "Die aktuelle md-viewer-Version konnte nicht ermittelt werden."
    version="${tag#v}"
    current="$(cat "$version_path" 2>/dev/null || true)"

    if [[ -x "$binary_path" && "$current" == "$tag" ]]; then
        printf 'md-viewer %s ist aktuell.\n' "$version"
        return
    fi

    asset="md-viewer-${version}-linux-x86_64.tar.gz"
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/${asset}" \
        "https://github.com/${repo}/releases/download/${tag}/${asset}"
    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/${asset}.sha256" \
        "https://github.com/${repo}/releases/download/${tag}/${asset}.sha256"

    (
        cd "$work_dir"
        sha256sum -c "${asset}.sha256"
    )

    tar --no-same-owner -xzf "${work_dir}/${asset}" -C "$work_dir"
    [[ -x "${work_dir}/md-viewer" ]] || fail "Das Release enthält kein ausführbares md-viewer-Programm."
    [[ -f "${work_dir}/LICENSE" ]] || fail "Das Release enthält keine LICENSE-Datei."
    [[ -f "${work_dir}/THIRD_PARTY_NOTICES" ]] || fail "Das Release enthält keine THIRD_PARTY_NOTICES-Datei."

    install -Dm755 "${work_dir}/md-viewer" "$binary_path"
    install -Dm644 "${work_dir}/LICENSE" "${data_dir}/licenses/md-viewer/LICENSE"
    install -Dm644 "${work_dir}/THIRD_PARTY_NOTICES" "${data_dir}/licenses/md-viewer/THIRD_PARTY_NOTICES"
    install -d "$(dirname "$version_path")"
    printf '%s\n' "$tag" > "$version_path"
    printf 'md-viewer %s wurde installiert.\n' "$version"
)

install_desktop_integration() (
    local desktop_source
    desktop_source="$(mktemp)"
    trap 'rm -f "$desktop_source"' EXIT
    cat > "$desktop_source" <<EOF
[Desktop Entry]
Name=Markdown Viewer
Comment=Markdown-Dateien mit Live Reload anzeigen
Exec=${binary_path} %f
Icon=text-markdown
Terminal=false
Type=Application
Categories=Utility;Viewer;
MimeType=text/markdown;text/x-markdown;
StartupNotify=false
StartupWMClass=md-viewer
EOF
    install -Dm644 "$desktop_source" "$desktop_path"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$(dirname "$desktop_path")" >/dev/null 2>&1 || true
    fi

    if command -v xdg-mime >/dev/null 2>&1; then
        local make_default="$default_choice"
        if [[ -z "$make_default" ]]; then
            if [[ -t 0 ]]; then
                local answer
                read -r -p 'Markdown Viewer als Standardprogramm für Markdown-Dateien festlegen? [J/n] ' answer || answer="n"
                case "$answer" in
                    [nN]*) make_default="0" ;;
                    *) make_default="1" ;;
                esac
            else
                make_default="0"
            fi
        fi

        if [[ "$make_default" == "1" ]]; then
            xdg-mime default md-viewer.desktop text/markdown
            xdg-mime default md-viewer.desktop text/x-markdown
            printf 'Markdown Viewer wurde als Standardprogramm für Markdown-Dateien festgelegt.\n'
        else
            printf 'Markdown Viewer wurde nicht als Standardprogramm für Markdown-Dateien festgelegt.\n'
        fi
    fi
)

install_topgrade_integration() (
    local topgrade_source escaped_path
    install -Dm755 "${BASH_SOURCE[0]}" "$maintain_path"
    escaped_path="${maintain_path//\\/\\\\}"
    escaped_path="${escaped_path//\"/\\\"}"
    topgrade_source="$(mktemp)"
    trap 'rm -f "$topgrade_source"' EXIT
    printf '[commands]\n"md-viewer" = "\\"%s\\" --update"\n' "$escaped_path" > "$topgrade_source"
    install -Dm644 "$topgrade_source" "$topgrade_path"

    if command -v topgrade >/dev/null 2>&1; then
        if topgrade --dry-run --only custom_commands --custom-commands md-viewer --no-self-update --notify-end never >/dev/null; then
            printf 'Die Topgrade-Integration wurde geprüft.\n'
        else
            printf 'Die Topgrade-Integration wurde eingerichtet; die Prüfung mit Topgrade ist fehlgeschlagen.\n'
        fi
    else
        printf 'Die Topgrade-Integration wurde eingerichtet; Topgrade war für den Test nicht verfügbar.\n'
    fi
)

install_chezmoi_integration() {
    local chezmoi_source

    if ! command -v chezmoi >/dev/null 2>&1; then
        printf 'Chezmoi wurde nicht gefunden; die Chezmoi-Integration wird übersprungen.\n'
        return
    fi

    chezmoi_source="$(chezmoi source-path 2>/dev/null || true)"
    if [[ -z "$chezmoi_source" || ! -d "$chezmoi_source" || -z "$(ls -A "$chezmoi_source" 2>/dev/null)" ]]; then
        printf 'Chezmoi ist nicht initialisiert; die Chezmoi-Integration wird übersprungen.\n'
        return
    fi

    chezmoi add "$topgrade_path"
    printf 'Die Topgrade-Konfiguration wurde zu Chezmoi hinzugefügt.\n'
}

for arg in "$@"; do
    case "$arg" in
        install)
            mode="install"
            ;;
        --update)
            mode="--update"
            ;;
        --set-default)
            default_choice="1"
            ;;
        --no-default)
            default_choice="0"
            ;;
        *)
            fail "Aufruf: $0 [install|--update] [--set-default|--no-default]"
            ;;
    esac
done

if [[ "$mode" == "--update" && -n "$default_choice" ]]; then
    fail "--set-default/--no-default sind nur zusammen mit install gültig."
fi

if [[ "$EUID" -eq 0 && "${MD_VIEWER_ALLOW_ROOT:-0}" != "1" ]]; then
    fail "Führe das Skript ohne sudo aus."
fi

case "$mode" in
    install)
        update_viewer
        install_desktop_integration
        install_topgrade_integration
        install_chezmoi_integration
        printf 'md-viewer wurde installiert und eingerichtet.\n'
        ;;
    --update)
        update_viewer
        ;;
esac
