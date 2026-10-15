#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ "${1:-}" != '--skip-build' ]]; then ./scripts/build.sh; fi
package_dir=$(mktemp -d "$PWD/.build/package.XXXXXX")
trap 'rm -rf "$package_dir"' EXIT
cp -R "$PWD/dist/NumPatch.app" "$package_dir/NumPatch.app"
ln -s /Applications "$package_dir/Applications"
cp "$PWD/README.md" "$package_dir/README.md"
cp "$PWD/README.zh-CN.md" "$package_dir/README.zh-CN.md"
image_path="$PWD/dist/NumPatch-0.3.0.dmg"
rm -f "$image_path"
if diskutil image create from --help >/dev/null 2>&1; then
    diskutil image create from --volumeName 'NumPatch' --format UDZO "$package_dir" "$image_path"
    diskutil image info "$image_path"
else
    hdiutil create -volname 'NumPatch' -srcfolder "$package_dir" -format UDZO "$image_path"
    hdiutil verify "$image_path"
fi
