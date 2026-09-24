#!/bin/sh
set -xe

if [ ! -d /opt/python ]; then
  echo "ERROR: run inside manylinux (via ./build.sh)"
  exit 1
fi

LIBMAUDE_PKG="${LIBMAUDE_PKG:-/work/libmaude.tar.xz}"
AUXFILES_PKG="${AUXFILES_PKG:-https://github.com/fadoss/maude-bindings/releases/download/0.1/manylinux_2_28-auxfiles.tar.xz}"

[ -f "$LIBMAUDE_PKG" ] || { echo "ERROR: missing $LIBMAUDE_PKG"; exit 1; }

yum install -y xz swig

curl -fsSL "$AUXFILES_PKG" -o /tmp/auxfiles.tar.xz
xz -cd /tmp/auxfiles.tar.xz | tar -xC /

rm -rf libmaude-pkg
mkdir -p libmaude-pkg
if tar -tJf "$LIBMAUDE_PKG" | head -1 | grep -q '^libmaude-pkg/'; then
  xz -cd "$LIBMAUDE_PKG" | tar -xC .
else
  xz -cd "$LIBMAUDE_PKG" | tar -xC libmaude-pkg
fi

mkdir -p subprojects/maudesmc/build
mkdir -p subprojects/maudesmc/installdir/lib
cp -f libmaude-pkg/config.h    subprojects/maudesmc/build/

if [ -d libmaude-pkg/cvc5-include ]; then
  mkdir -p /usr/local/include/cvc5
  cp -r libmaude-pkg/cvc5-include/. /usr/local/include/cvc5/
fi

cp -f libmaude-pkg/libmaude.so subprojects/maudesmc/installdir/lib/
ls -la subprojects/maudesmc/build/config.h
ls -la subprojects/maudesmc/installdir/lib/libmaude.so

export LD_LIBRARY_PATH="/work/subprojects/maudesmc/installdir/lib:${LD_LIBRARY_PATH:-}"

refversion=cp311-cp311
/opt/python/${refversion}/bin/python -m pip install --upgrade pip wheel auditwheel

versions="cp310-cp310 cp311-cp311 cp312-cp312 cp313-cp313 cp314-cp314"
mkdir -p dist

for version in $versions; do
  [ -x "/opt/python/${version}/bin/python" ] || continue
  /opt/python/${version}/bin/python -m pip install --upgrade \
    scikit-build-core build ninja wheel swig
  CMAKE_ARGS="-DBUILD_LIBMAUDE=OFF" \
    /opt/python/${version}/bin/python -m build --wheel --no-isolation
done

mkdir -p /work/dist
for whl in dist/*-linux_*.whl; do
  [ -f "$whl" ] || continue
  /opt/python/${refversion}/bin/auditwheel repair "$whl" -w /work/dist/
done

cd /tmp
cat > test.py <<'EOF'
import maude
maude.init()
print(maude.getCurrentModule())
EOF
echo CONVERSION > test.expected

for version in $versions; do
  [ -x "/opt/python/${version}/bin/python" ] || continue
  whl=$(ls /work/dist/maude*${version}*manylinux*.whl 2>/dev/null | head -1) || true
  [ -n "$whl" ] || continue
  /opt/python/${version}/bin/python -m pip install --force-reinstall "$whl"
  MAUDE_LIB=$(/opt/python/${version}/bin/python -c "import maude, os; print(os.path.dirname(maude.__file__))") \
  /opt/python/${version}/bin/python test.py > test.out
  cmp test.out test.expected && echo "OK $version"
done

ls -lh /work/dist/