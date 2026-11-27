#!/usr/bin/env bash
# Fail when the unit tests cover less than 80% of the lines of non-UI code.
# Usage: scripts/check-coverage.sh <unit-tests.xcresult> [minimum-percent]
#
# Views hold no logic (there are no UI tests), so they are left out of the measure: the app entry point
# (MonicaApp.swift), screens (*Screen.swift), shared views (*View.swift) and the theme (Theme/).
# Keep logic out of those files: a pure function a screen needs goes in its own file, with its
# own unit test.
set -euo pipefail

result="${1:?usage: $0 <unit-tests.xcresult> [minimum-percent]}"
minimum="${2:-80}"

xcrun xccov view --report --json "$result" | jq -r --argjson minimum "$minimum" '
  [.targets[] | select(.name == "Monica.app") | .files[]
    | select(.path | test("/MonicaApp\\.swift$|Screen\\.swift$|View\\.swift$|/Theme/") | not)]
  | (map(.coveredLines) | add // 0) as $covered
  | (map(.executableLines) | add // 0) as $executable
  | (if $executable == 0 then 100 else ($covered * 10000 / $executable | floor) / 100 end) as $percent
  | (map("  \(.coveredLines)/\(.executableLines)  \(.path | sub(".*/Monica/"; "Monica/"))") | join("\n")),
    "Non-UI line coverage: \($percent)% (\($covered)/\($executable) lines, minimum \($minimum)%)",
    (if $percent < $minimum then "FAIL: coverage is below \($minimum)%.\n" | halt_error(1) else "OK" end)
'
