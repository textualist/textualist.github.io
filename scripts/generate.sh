#!/usr/bin/env bash
#
# Generate brand mark PNGs from brand-marks.html
# Usage: bash scripts/generate.sh
#
# Requires: python3, playwright-cli
# Renders at 4x device pixel ratio for retina-quality output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$REPO_DIR/assets"
PORT=8791
DPR=4

echo "Starting local server on port $PORT..."
python3 -m http.server "$PORT" -d "$REPO_DIR" &>/dev/null &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null" EXIT
sleep 1

mkdir -p "$OUT_DIR"

echo "Opening browser..."
playwright-cli open "http://localhost:$PORT/scripts/brand-marks.html" 2>/dev/null

PAGE_URL="http://localhost:$PORT/scripts/brand-marks.html"

echo "Rendering marks at ${DPR}x..."
playwright-cli run-code "
  async page => {
    const url = '${PAGE_URL}';
    const outDir = '${OUT_DIR}';
    const dpr = ${DPR};
    const browser = page.context().browser();

    // Light mode at high DPR
    const light = await browser.newContext({ deviceScaleFactor: dpr });
    const lp = await light.newPage();
    await lp.goto(url);
    await lp.waitForTimeout(2000);

    const marks = [
      'display', 'nav',
      'name-gutenbit', 'name-literary-agent', 'name-marginalia', 'name-style-guide',
      'abbr-gb', 'abbr-la', 'abbr-mg', 'abbr-style',
      'breadcrumb-gutenbit', 'breadcrumb-gb',
      'asterisk-lg', 'asterisk-md', 'asterisk-sm'
    ];

    for (const id of marks) {
      await lp.locator('#' + id).screenshot({
        path: outDir + '/' + id + '.png',
        omitBackground: true
      });
    }

    // Dark mode at high DPR
    const dark = await browser.newContext({
      deviceScaleFactor: dpr,
      colorScheme: 'dark'
    });
    const dp = await dark.newPage();
    await dp.goto(url);
    await dp.waitForTimeout(2000);

    const darkMarks = ['display', 'nav'];
    for (const id of darkMarks) {
      await dp.locator('#' + id).screenshot({
        path: outDir + '/' + id + '-dark.png',
        omitBackground: true
      });
    }

    await light.close();
    await dark.close();
  }
" 2>/dev/null

echo "Closing browser..."
playwright-cli close 2>/dev/null

echo ""
echo "Done. Generated $(ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ') PNGs at ${DPR}x in assets/"
