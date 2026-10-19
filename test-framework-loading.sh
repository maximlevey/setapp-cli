#!/usr/bin/env bash
# this_file: test-framework-loading.sh
# Exercise the production startup helper with transitive @rpath dependencies.
# Requires macOS and Swift; does not require Setapp or an account.
set -euo pipefail
cd "$(dirname "$0")"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
frameworks="$fixture_dir/home with spaces/Frameworks"
mkdir -p "$frameworks/Leaf.framework" "$frameworks/Test.framework"

cat > "$fixture_dir/leaf.c" <<'EOF'
int leaf(void) { return 40; }
EOF
cat > "$fixture_dir/dependency.c" <<'EOF'
extern int leaf(void);
int dependency(void) { return leaf() + 1; }
EOF
cat > "$fixture_dir/test.c" <<'EOF'
extern int dependency(void);
int answer(void) { return dependency() + 1; }
EOF

xcrun clang -dynamiclib "$fixture_dir/leaf.c" \
  -install_name '@rpath/Leaf.framework/Leaf' -o "$frameworks/Leaf.framework/Leaf"
xcrun clang -dynamiclib "$fixture_dir/dependency.c" "$frameworks/Leaf.framework/Leaf" \
  -install_name '@rpath/libFixtureDependency.dylib' -o "$frameworks/libFixtureDependency.dylib"
xcrun clang -dynamiclib "$fixture_dir/test.c" "$frameworks/libFixtureDependency.dylib" \
  -install_name '@rpath/Test.framework/Test' -o "$frameworks/Test.framework/Test"

cat > "$fixture_dir/main.swift" <<'EOF'
import Darwin
import Foundation

let arguments = CommandLine.arguments
precondition(arguments[2] == "argument with spaces", "Relaunch lost arguments")
let counter = URL(fileURLWithPath: arguments[4])
let previous = (try? String(contentsOf: counter, encoding: .utf8)) ?? ""
precondition(previous.count < 2, "Startup entered a relaunch loop")
try (previous + "x").write(to: counter, atomically: true, encoding: .utf8)
if arguments[3] != "--no-bootstrap" {
    try FrameworkEnvironment.prepare(frameworkPath: arguments[1])
}
guard let handle = dlopen(arguments[1], RTLD_NOW | RTLD_GLOBAL) else {
    fputs(String(cString: dlerror()) + "\n", stderr)
    exit(1)
}
guard let symbol = dlsym(handle, "answer") else {
    fatalError("Missing fixture symbol")
}
let answer = unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
precondition(answer() == 42, "Transitive dependencies returned the wrong result")
print("Loaded framework, sibling dylib, and transitive framework")
EOF

swiftc Sources/SetappCLI/Helpers/FrameworkEnvironment.swift \
  Sources/SetappCLI/Model/SetappError.swift "$fixture_dir/main.swift" \
  -o "$fixture_dir/probe"

if "$fixture_dir/probe" "$frameworks/Test.framework/Test" 'argument with spaces' \
  --no-bootstrap "$fixture_dir/baseline-count" > "$fixture_dir/baseline.log" 2>&1; then
  echo 'FAIL: fixture must fail without the startup helper' >&2
  exit 1
fi
grep -q 'Library not loaded: @rpath/' "$fixture_dir/baseline.log"
"$fixture_dir/probe" "$frameworks/Test.framework/Test" 'argument with spaces' \
  --bootstrap "$fixture_dir/relaunch-count"
[[ "$(cat "$fixture_dir/relaunch-count")" == xx ]]
echo 'PASS: portable framework loading, argument preservation, and exactly one relaunch'
