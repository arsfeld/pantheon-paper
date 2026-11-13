#!/bin/sh
# Builds the .deb in elementary OS 8 (ghcr.io/elementary/docker:circe-stable)
# from a checkout at $PWD, and leaves it in ./dist with its version in
# dist/VERSION. Used by .github/workflows/ci.yml; runs the same locally:
#   docker run --rm -v "$PWD:/src" -w /src ghcr.io/elementary/docker:circe-stable \
#     sh -c 'git config --global --add safe.directory /src && ci/build-deb.sh'
set -eu

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  ca-certificates git devscripts equivs lintian >/dev/null

# Every commit sorts after the last: meson version, commit time (UTC, to the
# second, so same-day builds never sort by hash), commit.
upstream=$(sed -n "s/^project(.*, version: *'\([^']*\)'.*/\1/p" meson.build)
[ -n "$upstream" ] || { echo "cannot read the version from meson.build" >&2; exit 1; }
date=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M%S)
sha=$(git rev-parse --short=8 HEAD)
version="$upstream+git$date.$sha"
DEBEMAIL="alex@rosenfeld.one" DEBFULLNAME="Alexandre Rosenfeld" \
  dch --newversion "$version" --distribution noble --force-distribution \
  "Build of $(git rev-parse HEAD)."

mk-build-deps --install --remove --tool 'apt-get -y -qq --no-install-recommends' debian/control >/dev/null
# The unit tests (meson test) run in dh_auto_test.
dpkg-buildpackage -b -us -uc

mkdir -p dist
mv ../*.deb ../*.buildinfo ../*.changes dist/
echo "$version" > dist/VERSION

lintian --allow-root --info dist/*.deb || echo "lintian reported issues (not fatal)"
