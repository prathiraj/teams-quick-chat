#!/usr/bin/env bash
# Interactive local helper to create a Developer ID Application certificate (even without Xcode)
# and upload the signing + notarization secrets to GitHub Actions.
set -euo pipefail

WORK_DIR="${SIGNING_WORK_DIR:-$HOME/.teams-quick-chat-signing}"
KEY_PATH="$WORK_DIR/developerID_application.key"
CSR_PATH="$WORK_DIR/developerID_application.certSigningRequest"
CER_PATH="$WORK_DIR/developerID_application.cer"
PEM_PATH="$WORK_DIR/developerID_application.pem"
P12_PATH="$WORK_DIR/developerID_application.p12"

usage() {
    cat <<EOF
Usage:
  1) Generate CSR (if you don't already have a Developer ID Application .p12):
       ./macos/scripts/setup_apple_signing.sh csr "Your Name" "you@example.com"

     Then open:
       https://developer.apple.com/account/resources/certificates/add
     -> Select "Developer ID Application" (under Software)
     -> Upload: $CSR_PATH
     -> Download the issued certificate to: $CER_PATH

  2) Export .p12 and upload secrets to GitHub Actions:
       ./macos/scripts/setup_apple_signing.sh github-secrets [path/to/developerID_application.cer]

All private files stay in $WORK_DIR (chmod 700, outside the git repository).
EOF
}

cmd="${1:-help}"

case "$cmd" in
    csr)
        NAME="${2:-}"
        EMAIL="${3:-}"
        if [[ -z "$NAME" || -z "$EMAIL" ]]; then
            usage
            exit 1
        fi
        mkdir -p "$WORK_DIR"
        chmod 700 "$WORK_DIR"
        if [[ ! -f "$KEY_PATH" ]]; then
            openssl genrsa -out "$KEY_PATH" 2048
            chmod 600 "$KEY_PATH"
        fi
        openssl req -new -key "$KEY_PATH" -out "$CSR_PATH" \
            -subj "/emailAddress=$EMAIL/CN=$NAME/C=US"
        echo ""
        echo "✅ Created CSR at:"
        echo "   $CSR_PATH"
        echo ""
        echo "Next steps:"
        echo "1. Open https://developer.apple.com/account/resources/certificates/add"
        echo "2. Choose 'Developer ID Application' and click Continue."
        echo "3. Upload '$CSR_PATH' and download the resulting certificate to:"
        echo "   $CER_PATH"
        echo "4. Run: ./macos/scripts/setup_apple_signing.sh github-secrets \"$CER_PATH\""
        ;;

    github-secrets)
        mkdir -p "$WORK_DIR"
        chmod 700 "$WORK_DIR"
        INPUT_FILE="${2:-$CER_PATH}"
        if [[ ! -f "$INPUT_FILE" ]]; then
            echo "Error: Certificate file not found at '$INPUT_FILE'." >&2
            echo "Pass your downloaded developerID_application.cer or an exported .p12 file." >&2
            exit 1
        fi

        DETECTED_TEAM_ID=""
        if [[ "$INPUT_FILE" == *.p12 || "$INPUT_FILE" == *.pfx ]]; then
            P12_SOURCE="$INPUT_FILE"
            echo "Enter the password for '$P12_SOURCE':"
            read -r -s P12_PASS
            echo ""
        else
            if [[ ! -f "$KEY_PATH" ]]; then
                echo "Error: Private key not found at '$KEY_PATH'. Run the 'csr' step first (or pass an exported .p12 file)." >&2
                exit 1
            fi

            if grep -q "BEGIN CERTIFICATE" "$INPUT_FILE"; then
                cp "$INPUT_FILE" "$PEM_PATH"
            else
                openssl x509 -inform DER -in "$INPUT_FILE" -out "$PEM_PATH"
            fi

            DETECTED_TEAM_ID="$(openssl x509 -in "$PEM_PATH" -noout -subject -nameopt RFC2253 \
                | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p' | head -n 1 || true)"

            echo "Enter a strong password to encrypt the temporary .p12 bundle:"
            read -r -s P12_PASS
            echo ""
            if [[ -z "$P12_PASS" ]]; then
                echo "Error: Password cannot be empty." >&2
                exit 1
            fi

            LEGACY_FLAG=()
            if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
                LEGACY_FLAG=(-legacy)
            fi

            openssl pkcs12 -export "${LEGACY_FLAG[@]}" \
                -inkey "$KEY_PATH" \
                -in "$PEM_PATH" \
                -out "$P12_PATH" \
                -passout "pass:$P12_PASS"
            chmod 600 "$P12_PATH"
            P12_SOURCE="$P12_PATH"
        fi

        read -r -p "Apple ID email (for notarytool): " APPLE_ID_INPUT
        read -r -p "Apple Team ID [${DETECTED_TEAM_ID}]: " TEAM_ID_INPUT
        TEAM_ID_FINAL="${TEAM_ID_INPUT:-$DETECTED_TEAM_ID}"
        echo "App-Specific Password (create at https://account.apple.com -> Sign-In and Security -> App-Specific Passwords):"
        read -r -s APP_PASS_INPUT
        echo ""

        GH_BIN="gh"
        if ! command -v gh >/dev/null 2>&1 && [[ -x "$HOME/Library/Caches/copilot-desktop-gh-2.103.3/gh" ]]; then
            GH_BIN="$HOME/Library/Caches/copilot-desktop-gh-2.103.3/gh"
        fi

        REPO="${GITHUB_REPOSITORY:-prathiraj/teams-quick-chat}"
        echo "==> Uploading encrypted secrets to $REPO ..."
        base64 < "$P12_SOURCE" | tr -d '\n' | "$GH_BIN" secret set APPLE_CERTIFICATE_P12_BASE64 --repo "$REPO"
        printf '%s' "$P12_PASS" | "$GH_BIN" secret set APPLE_CERTIFICATE_PASSWORD --repo "$REPO"
        printf '%s' "$APPLE_ID_INPUT" | "$GH_BIN" secret set APPLE_ID --repo "$REPO"
        printf '%s' "$TEAM_ID_FINAL" | "$GH_BIN" secret set APPLE_TEAM_ID --repo "$REPO"
        printf '%s' "$APP_PASS_INPUT" | "$GH_BIN" secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$REPO"

        echo ""
        echo "✅ GitHub Actions secrets configured for $REPO!"
        echo "Trigger a signed + notarized release now with:"
        echo "  $GH_BIN workflow run release.yml --repo $REPO"
        ;;

    *)
        usage
        ;;
esac
