#!/bin/bash
# The test suite. There is no XCTest target: each harness compiles the shipped sources it guards,
# so a harness that stops compiling means a decision leaked out of a pure layer. See docs/testing.md.
#
# Never join a compile and its run with `&&`: `set -e` ignores a failure in a non-final AND-OR list
# member, which is how CI reported success over a harness that had not compiled since phase 10.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

BIN="${TMPDIR:-/tmp}/ttyl-harness"
mkdir -p "$BIN"

failed=()
ran=0
only="${1:-}"

# `--index` merges each harness's compile command into .compile instead of running anything.
# xcodebuild never compiles the harnesses, so without this nothing in Tests/ resolves in an editor.
# The source lists below are the only copy, which is why this lives here rather than in its own script.
emit_db=0
DB="${TMPDIR:-/tmp}/ttyl-compile-db.json"
if [ "$only" = "--index" ]; then
    emit_db=1
    only=""
    printf '[' > "$DB"
fi

# run <name> <source...> — compile the harness and run it, recording either kind of failure.
run() {
    local name=$1
    shift
    if [ -n "$only" ] && [ "$name" != "$only" ]; then return 0; fi
    ran=$((ran + 1))

    # Absolute paths throughout: sourcekit-lsp resolves the command itself and does not apply
    # `directory` to relative arguments, so a relative path there silently yields no index.
    if [ "$emit_db" -eq 1 ]; then
        local sources=()
        for source in "$@" "Tests/$name.swift"; do sources+=("$PWD/$source"); done
        [ "$ran" -gt 1 ] && printf ',' >> "$DB"
        printf '{"directory":"%s","command":"swiftc -swift-version 6 -sdk %s' \
            "$PWD" "$(xcrun --show-sdk-path --sdk macosx)" >> "$DB"
        printf ' %s' "${sources[@]}" >> "$DB"
        # Claim only the harness itself. The command still lists every shipped source it compiles, so
        # symbols resolve inside the harness — but claiming those sources here would hand them this
        # 3-file command instead of the app's, and `.compile` is last-wins.
        printf '","files":["%s/Tests/%s.swift"]}' "$PWD" "$name" >> "$DB"
        return 0
    fi

    if ! swiftc -swift-version 6 "$@" "Tests/$name.swift" -o "$BIN/$name" 2>&1; then
        printf '\033[31mFAIL\033[0m  %-22s did not compile\n' "$name"
        failed+=("$name")
        return 0
    fi
    if ! "$BIN/$name"; then
        printf '\033[31mFAIL\033[0m  %-22s assertion failed\n' "$name"
        failed+=("$name")
        return 0
    fi
    printf '\033[32mok\033[0m    %-22s\n' "$name"
}

L=ttyl/Features/Launcher/Model
run fuzz-test              $L/SearchRelevance.swift
run file-search-test       $L/SearchRelevance.swift \
                           ttyl/Features/FileSearch/Model/*.swift
run file-search-session-test ttyl/Platform/Signposts.swift \
                             $L/SearchRelevance.swift \
                             ttyl/Features/FileSearch/Model/*.swift \
                             ttyl/Features/FileSearch/Service/*.swift
run ranking-test           $L/SearchRelevance.swift $L/LauncherRankingStore.swift
run scopes-test            $L/SearchScopes.swift
run calc-test              ttyl/Features/Calculator/Model/*.swift
run clipboard-test         ttyl/Features/Clipboard/Model/ClipboardStore.swift \
                           ttyl/Features/Clipboard/Model/ClipboardFilter.swift
run emoji-test             ttyl/Features/Emoji/Model/EmojiCatalog.swift \
                           ttyl/Features/Emoji/Model/EmojiGridGeometry.swift \
                           ttyl/Features/Emoji/Model/EmojiData.generated.swift
run palette-selection-test ttyl/Features/PaletteRowIndex.swift \
                           ttyl/Features/Emoji/Model/EmojiGridGeometry.swift
run palette-placement-test ttyl/DesignSystem/Theme.swift \
                           ttyl/Palette/PalettePlacement.swift
run scroll-reveal-test     ttyl/DesignSystem/Scrolling/SelectionReveal.swift
run hover-arming-test      ttyl/Palette/HoverArming.swift \
                           ttyl/Palette/PaletteState.swift \
                           ttyl/Palette/PaletteMode.swift \
                           ttyl/Features/Clipboard/Model/ClipboardStore.swift \
                           ttyl/Features/Clipboard/Model/ClipboardFilter.swift \
                           ttyl/Features/Quicklinks/Model/Quicklink.swift
run hotkey-test            ttyl/Features/HotKeys/Model/DoubleTapModifier.swift \
                           ttyl/Features/HotKeys/Model/DoubleTapDetector.swift \
                           ttyl/Features/HotKeys/Model/HyperKey.swift \
                           ttyl/Features/HotKeys/Service/KeyShortcut.swift
run callout-test           ttyl/DesignSystem/Theme.swift \
                           ttyl/Features/HotKeys/UI/CalloutPlacement.swift
run icon-cache-test        ttyl/Platform/Images/IconCache.swift
run system-action-test     ttyl/Features/SystemActions/Model/SystemAction.swift
run volume-test            ttyl/Features/SystemActions/Model/VolumeLevel.swift
run window-command-test    ttyl/Features/WindowManagement/WindowCommand.swift \
                           ttyl/Features/WindowManagement/WindowLayout.swift \
                           ttyl/Features/WindowManagement/WindowActionMemory.swift
run custom-command-test    ttyl/Features/CustomCommands/Model/CustomCommand.swift \
                           ttyl/Features/CustomCommands/Service/ShellCommandRunner.swift
run uninstall-test         ttyl/Features/Uninstall/Model/UninstallTarget.swift \
                           ttyl/Features/Uninstall/Model/UninstallSearchRoot.swift \
                           ttyl/Features/Uninstall/Model/UninstallRules.swift \
                           ttyl/Features/Uninstall/Model/UninstallProtection.swift \
                           ttyl/Features/Uninstall/Model/UninstallPlan.swift
run quicklink-test         ttyl/Features/Quicklinks/Model/Quicklink.swift \
                           ttyl/Features/Quicklinks/Model/QuicklinkDestination.swift \
                           ttyl/Features/Quicklinks/Model/QuicklinkStore.swift \
                           ttyl/Features/Quicklinks/Model/QuicklinkArchive.swift
run snippets-test          ttyl/Platform/NotificationToken.swift \
                           ttyl/Platform/HealthTicker.swift \
                           ttyl/Features/Snippets/Model/*.swift \
                           ttyl/Features/Snippets/Service/*.swift
run raycast-test           ttyl/Features/Backup/Model/RaycastFormat.swift \
                           ttyl/Features/Backup/Model/RaycastV1Decoder.swift \
                           ttyl/Features/Backup/Service/Gunzip.swift \
                           ttyl/Features/Clipboard/Model/ClipboardStore.swift \
                           ttyl/Features/Clipboard/Model/ClipboardFilter.swift
run settings-backup-test   ttyl/Features/Settings/AppSettingsKey.swift \
                           ttyl/Features/Backup/Model/SettingsBackupCoverage.swift
run settings-history-test  ttyl/Features/Settings/SettingsTab.swift \
                           ttyl/Features/Settings/SettingsHistory.swift

if [ "$emit_db" -eq 1 ]; then
    printf ']\n' >> "$DB"
    [ -f .compile ] || echo '[]' > .compile
    python3 - .compile "$DB" <<'PY'
import json, sys

compile_path, harness_path = sys.argv[1], sys.argv[2]
existing = json.load(open(compile_path))
harnesses = json.load(open(harness_path))
kept = [e for e in existing if not any("/Tests/" in f for f in e.get("files") or [])]
json.dump(kept + harnesses, open(compile_path, "w"), indent=1)
print(f"{len(harnesses)} harness entries indexed into .compile")
PY
    exit 0
fi

if [ "$ran" -eq 0 ]; then
    echo "No harness named '$only'." >&2
    exit 2
fi

if [ ${#failed[@]} -gt 0 ]; then
    printf '\n%d harness(es) failed: %s\n' "${#failed[@]}" "${failed[*]}" >&2
    exit 1
fi
echo
if [ -n "$only" ]; then echo "$only passed."; else echo "All $ran harnesses passed."; fi
