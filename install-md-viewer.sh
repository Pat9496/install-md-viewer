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
font_dir="${data_dir}/fonts/md-viewer"
noto_font_url="https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf"
dejavu_font_url="https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2"
mode="install"
default_choice=""

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 was not found."
}

latest_tag() {
    local url token response http_code
    local -a curl_args

    url="https://api.github.com/repos/${repo}/releases/latest"
    printf 'Fetching latest release info from %s...\n' "$url" >&2

    token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    curl_args=(-sSL --retry 3 --retry-delay 2)
    if [[ -n "$token" ]]; then
        curl_args+=(-H "Authorization: Bearer ${token}")
    fi

    if ! response="$(curl "${curl_args[@]}" -w $'\n%{http_code}' "$url")"; then
        fail "Could not reach the GitHub API at ${url}."
    fi

    http_code="${response##*$'\n'}"
    response="${response%$'\n'*}"

    case "$http_code" in
        200) ;;
        403) fail "GitHub API request to ${url} failed with HTTP 403 (likely rate limited). Set GITHUB_TOKEN (or GH_TOKEN) to a personal access token to raise the rate limit and try again." ;;
        *) fail "GitHub API request to ${url} failed with HTTP ${http_code}." ;;
    esac

    printf '%s' "$response" \
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

    printf 'Checking for md-viewer updates...\n'

    [[ "$(uname -s)" == "Linux" ]] || fail "This script only supports Linux."
    [[ "$(uname -m)" == "x86_64" ]] || fail "This script only supports Linux on x86_64."

    local tag version current asset work_dir asset_url checksum_url binary_tmp version_tmp
    binary_tmp=""
    version_tmp=""
    tag="$(latest_tag)"
    [[ -n "$tag" ]] || fail "Could not determine the latest md-viewer version."
    version="${tag#v}"
    printf 'Latest available version: %s\n' "$version"
    current="$(cat "$version_path" 2>/dev/null || true)"

    if [[ -x "$binary_path" && "$current" == "$tag" ]]; then
        printf 'md-viewer %s is up to date.\n' "$version"
        return
    fi

    asset="md-viewer-${version}-linux-x86_64.tar.gz"
    asset_url="https://github.com/${repo}/releases/download/${tag}/${asset}"
    checksum_url="${asset_url}.sha256"
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"; [[ -n "$binary_tmp" ]] && rm -f "$binary_tmp"; [[ -n "$version_tmp" ]] && rm -f "$version_tmp"' EXIT

    printf 'Downloading %s from %s...\n' "$asset" "$asset_url"
    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/${asset}" \
        "$asset_url"
    printf 'Downloading checksum from %s...\n' "$checksum_url"
    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/${asset}.sha256" \
        "$checksum_url"

    printf 'Verifying checksum...\n'
    (
        cd "$work_dir"
        sha256sum -c "${asset}.sha256"
    )

    printf 'Extracting archive...\n'
    tar --no-same-owner -xzf "${work_dir}/${asset}" -C "$work_dir"
    [[ -x "${work_dir}/md-viewer" ]] || fail "The release does not contain an executable md-viewer binary."
    [[ -f "${work_dir}/LICENSE" ]] || fail "The release does not contain a LICENSE file."
    [[ -f "${work_dir}/THIRD_PARTY_NOTICES" ]] || fail "The release does not contain a THIRD_PARTY_NOTICES file."

    install -d "$bin_dir"
    binary_tmp="$(mktemp "${bin_dir}/md-viewer.XXXXXX")"
    install -m755 "${work_dir}/md-viewer" "$binary_tmp"
    mv -f "$binary_tmp" "$binary_path"
    binary_tmp=""

    install -Dm644 "${work_dir}/LICENSE" "${data_dir}/licenses/md-viewer/LICENSE"
    install -Dm644 "${work_dir}/THIRD_PARTY_NOTICES" "${data_dir}/licenses/md-viewer/THIRD_PARTY_NOTICES"

    install -d "$(dirname "$version_path")"
    version_tmp="$(mktemp "$(dirname "$version_path")/version.XXXXXX")"
    printf '%s\n' "$tag" > "$version_tmp"
    mv -f "$version_tmp" "$version_path"
    version_tmp=""

    printf 'md-viewer %s was installed.\n' "$version"
)

install_fonts() (
    require curl
    require tar
    require install
    require mktemp

    printf 'Setting up fallback fonts...\n'

    local marker_path="${font_dir}/.installed"
    if [[ -f "$marker_path" ]]; then
        printf 'Fallback fonts are already installed.\n'
        return
    fi

    local work_dir
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    printf 'Downloading Noto Sans font from %s...\n' "$noto_font_url"
    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/NotoSans[wdth,wght].ttf" \
        "$noto_font_url"

    printf 'Downloading DejaVu fonts from %s...\n' "$dejavu_font_url"
    curl -fL --retry 3 --retry-delay 2 \
        -o "${work_dir}/dejavu-fonts-ttf.tar.bz2" \
        "$dejavu_font_url"
    printf 'Extracting DejaVu fonts...\n'
    tar -xjf "${work_dir}/dejavu-fonts-ttf.tar.bz2" -C "$work_dir"

    install -Dm644 "${work_dir}/NotoSans[wdth,wght].ttf" "${font_dir}/NotoSans[wdth,wght].ttf"
    install -Dm644 -t "$font_dir" "${work_dir}"/dejavu-fonts-ttf-2.37/ttf/*.ttf

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi

    : > "$marker_path"
    printf 'Fallback fonts were installed to %s.\n' "$font_dir"
)

install_desktop_integration() (
    printf 'Setting up desktop integration...\n'
    local desktop_source
    desktop_source="$(mktemp)"
    trap 'rm -f "$desktop_source"' EXIT
    cat > "$desktop_source" <<EOF
[Desktop Entry]
Name=Markdown Viewer
Comment=View Markdown files with live reload
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
                read -r -p 'Set Markdown Viewer as the default handler for Markdown files? [Y/n] ' answer || answer="n"
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
            printf 'Markdown Viewer was set as the default handler for Markdown files.\n'
        else
            printf 'Markdown Viewer was not set as the default handler for Markdown files.\n'
        fi
    fi
)

install_topgrade_integration() (
    printf 'Setting up topgrade integration...\n'
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
            printf 'The topgrade integration was verified.\n'
        else
            printf 'The topgrade integration was set up; the check with topgrade failed.\n'
        fi
    else
        printf 'The topgrade integration was set up; topgrade was not available for testing.\n'
    fi
)

install_chezmoi_integration() {
    local chezmoi_source

    printf 'Setting up chezmoi integration...\n'

    if ! command -v chezmoi >/dev/null 2>&1; then
        printf 'Chezmoi was not found; skipping chezmoi integration.\n'
        return
    fi

    chezmoi_source="$(chezmoi source-path 2>/dev/null || true)"
    if [[ -z "$chezmoi_source" || ! -d "$chezmoi_source" || -z "$(ls -A "$chezmoi_source" 2>/dev/null)" ]]; then
        printf 'Chezmoi is not initialized; skipping chezmoi integration.\n'
        return
    fi

    chezmoi add "$topgrade_path"
    printf 'The topgrade configuration was added to chezmoi.\n'
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
            fail "Usage: $0 [install|--update] [--set-default|--no-default]"
            ;;
    esac
done

if [[ "$mode" == "--update" && -n "$default_choice" ]]; then
    fail "--set-default/--no-default are only valid together with install."
fi

if [[ "$EUID" -eq 0 && "${MD_VIEWER_ALLOW_ROOT:-0}" != "1" ]]; then
    fail "Run this script without sudo."
fi

case "$mode" in
    install)
        update_viewer
        if ! install_fonts; then
            printf 'Warning: could not install fallback fonts; continuing.\n' >&2
        fi
        install_desktop_integration
        install_topgrade_integration
        install_chezmoi_integration
        printf 'md-viewer was installed and set up.\n'
        ;;
    --update)
        update_viewer
        ;;
esac
