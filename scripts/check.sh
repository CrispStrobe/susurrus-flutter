#!/bin/bash

# Local CI Pipeline for CrisperWeaver (Flutter/Dart)
# Equivalents:
# - black  -> dart format
# - ruff   -> flutter analyze
# - mypy   -> flutter analyze (with strict flags)
# - bandit -> dart pub audit

set -e # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting Local CI Pipeline ===${NC}\n"

# 1. Formatting Check (black equivalent)
echo -e "${BLUE}[1/5] Checking formatting (black equivalent)...${NC}"
dart format --set-exit-if-changed . || (echo -e "${RED}Formatting check failed. Run 'dart format .' to fix.${NC}" && exit 1)
echo -e "${GREEN}✓ Formatting is correct.${NC}\n"

# 2. Static Analysis & Linting (ruff/mypy equivalent)
echo -e "${BLUE}[2/5] Running static analysis & lints (ruff/mypy equivalent)...${NC}"
# Match the CI policy: fail on errors only. Infos / warnings from third-
# party API drift (e.g. Material3 deprecations) are noisy but don't block
# a release and are tracked separately in PLAN.md §5.9.
set +e
flutter analyze --no-fatal-infos --no-fatal-warnings
status=$?
set -e
if [ $status -ne 0 ]; then
  echo -e "${RED}✗ flutter analyze reported errors (above).${NC}"
  exit $status
fi
echo -e "${GREEN}✓ Analysis passed (errors = 0).${NC}\n"

# 3. Dependency health (no-op; Dart ecosystem has no `pub audit` subcommand
#    as of 3.10. pub.dev does surface advisories during `pub get`; we rely
#    on that + step 4 `pub outdated` for drift.
echo -e "${BLUE}[3/5] Dependency health — skipping (no pub audit in Dart).${NC}"
echo -e "${GREEN}✓ (skipped).${NC}\n"

# 4. Outdated Packages
echo -e "${BLUE}[4/5] Checking for outdated packages...${NC}"
flutter pub outdated
echo -e "${GREEN}✓ Outdated check complete.${NC}\n"

# 5. Unit Tests (pytest equivalent)
echo -e "${BLUE}[5/5] Running unit tests...${NC}"
flutter test
echo -e "${GREEN}✓ All tests passed.${NC}\n"

echo -e "${GREEN}=== ALL CHECKS PASSED ===${NC}"
