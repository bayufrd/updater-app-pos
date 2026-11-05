#!/usr/bin/env bash
set -euo pipefail

# Path konfigurasi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../gaspol-repo/dastrevas-gaspoll-pos-app-desktop" ]; then
    APP_REPO_DIR="$(cd "$SCRIPT_DIR/../gaspol-repo/dastrevas-gaspoll-pos-app-desktop" && pwd)"
elif [ -d "$SCRIPT_DIR/../dastrevas-gaspoll-pos-app-desktop" ]; then
    APP_REPO_DIR="$(cd "$SCRIPT_DIR/../dastrevas-gaspoll-pos-app-desktop" && pwd)"
else
    APP_REPO_DIR="$HOME/Desktop/project-repo/gaspol-repo/dastrevas-gaspoll-pos-app-desktop"
fi
CSPROJ_PATH="$APP_REPO_DIR/KASIR.csproj"
DESKTOP_BUILD_DIR="$HOME/Desktop/kasir-build"
WINE_BIN="/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine"

increment_version() {
    local ver="$1"
    IFS='.' read -r v1 v2 v3 v4 <<< "$ver"
    v1=${v1:-1}
    v2=${v2:-0}
    v3=${v3:-0}
    v4=${v4:-0}

    # Hitung kenaikan versi dengan carry base-10 (contoh: 1.2.9.9 -> 1.3.0.0 -> 1.3.0.1)
    v4=$((v4 + 1))
    if [ "$v4" -ge 10 ]; then
        v4=0
        v3=$((v3 + 1))
    fi
    if [ "$v3" -ge 10 ]; then
        v3=0
        v2=$((v2 + 1))
    fi
    if [ "$v2" -ge 10 ]; then
        v2=0
        v1=$((v1 + 1))
    fi

    printf "%d.%d.%d.%d" "$v1" "$v2" "$v3" "$v4"
}

run_app() {
    echo "===================================================="
    echo " [1/2] Mem-build KASIR ke $DESKTOP_BUILD_DIR..."
    echo "===================================================="
    mkdir -p "$DESKTOP_BUILD_DIR"
    dotnet publish "$CSPROJ_PATH" -c Debug -r win-x64 --self-contained true -o "$DESKTOP_BUILD_DIR"

    cat > "$DESKTOP_BUILD_DIR/Jalankan-KASIR.command" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
"/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine" KASIR.exe
EOF
    chmod +x "$DESKTOP_BUILD_DIR/Jalankan-KASIR.command"

    if [ ! -x "$WINE_BIN" ]; then
        echo "Error: Wine Staging tidak ditemukan di $WINE_BIN"
        exit 1
    fi

    echo "===================================================="
    echo " [2/2] Menjalankan KASIR.exe dengan Wine Staging..."
    echo "===================================================="
    cd "$DESKTOP_BUILD_DIR"
    "$WINE_BIN" KASIR.exe
}

deploy_app() {
    local custom_version="${1:-}"
    local tmp_build_dir
    tmp_build_dir="$(mktemp -d /tmp/kasir-win-x86-build.XXXXXX)"
    local update_dir="$SCRIPT_DIR/update"

    cd "$SCRIPT_DIR"

    if [ ! -f "$SCRIPT_DIR/update.zip" ]; then
        echo "Error: File update.zip tidak ditemukan di $SCRIPT_DIR"
        rm -rf "$tmp_build_dir"
        exit 1
    fi

    echo "===================================================="
    echo " [1/5] Mengekstrak update.zip ke folder update/..."
    echo "===================================================="
    rm -rf "$update_dir"
    mkdir -p "$update_dir"
    unzip -q "$SCRIPT_DIR/update.zip" -d "$update_dir"

    echo "===================================================="
    echo " [2/5] Mem-build KASIR (Release, win-x86)..."
    echo "===================================================="
    dotnet publish "$CSPROJ_PATH" -c Release -r win-x86 --self-contained false -o "$tmp_build_dir"

    echo "===================================================="
    echo " [3/5] Menyalin hasil build ke update/ (tanpa KASIR.dll.config & tanpa folder)..."
    echo "===================================================="
    rm -f "$tmp_build_dir/KASIR.dll.config"
    find "$tmp_build_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    cp -f "$tmp_build_dir"/* "$update_dir"/

    echo "===================================================="
    echo " [4/5] Membuat ulang update.zip & menghapus folder update/..."
    echo "===================================================="
    rm -f "$SCRIPT_DIR/update.zip"
    (
        cd "$update_dir"
        zip -r -q "$SCRIPT_DIR/update.zip" . -x "*.DS_Store"
    )
    rm -rf "$update_dir" "$tmp_build_dir"

    echo "===================================================="
    echo " [5/5] Mengupdate version.txt, Git Commit & Push..."
    echo "===================================================="
    local current_version="1.3.0.0"
    if [ -f "$SCRIPT_DIR/version.txt" ]; then
        current_version="$(tr -d '[:space:]' < "$SCRIPT_DIR/version.txt")"
    fi

    local next_version
    if [ -n "$custom_version" ]; then
        next_version="$custom_version"
    else
        next_version="$(increment_version "$current_version")"
    fi

    printf "%s" "$next_version" > "$SCRIPT_DIR/version.txt"
    echo "Versi diupdate: $current_version -> $next_version"

    git add update.zip version.txt
    git commit -m "$next_version"
    git push origin HEAD
    echo "Deploy selesai! Versi terbaru: $next_version"
}

usage() {
    echo "Penggunaan:"
    echo "  ./setup.sh --run                Build KASIR ke ~/Desktop/kasir-build dan jalankan di Mac"
    echo "  ./setup.sh --deploy [versi]     Build win-x86, update update.zip, naikkan version.txt, lalu git commit & push"
}

case "${1:-}" in
    --run)
        run_app
        ;;
    --deploy)
        deploy_app "${2:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
