{
  outputs = {
    self,
    ...
  }: {
    overlays.default = final: prev: {
      pkg-config-support = final.makeSetupHook {
        name = "pkg-config-support";
      } (final.writeScript "pkg-config-support.sh" ''
_autoPkgConfigGen() {
  local devdir="''${dev:-$out}"
  local libdir="$out/lib"

  [ -d "$libdir" ] || return 0

  local libs="$(
    find -L "$libdir" -maxdepth 1 -type f \( -name 'lib*.so' -o -name 'lib*.so.*' -o -name 'lib*.a' \) |
    sed 's|.*/lib||; s|\.so.*$||; s|\.a$||' |
    sort -u
  )"

  [ -n "$libs" ] || return 0

  local includedir=""
  local cflags=""
  if [ -d "$devdir/include" ]; then
    includedir="$devdir/include"
    cflags="-I\''${includedir}"
  fi

  local defaultver="''${version:-1.0.0}"

  for lib in $libs; do
    local libver="$defaultver"
    local libfile="$(find "$libdir" -maxdepth 1 \( -name "lib$lib.so.*" -o -name "lib$lib.so" -o -name "lib$lib.a" \) | head -1)"

    if [ -n "$libfile" ] && command -v objdump >/dev/null 2>&1; then
      local soname="$(objdump -p "$libfile" 2>/dev/null | grep 'SONAME' | awk '{print $2}')" || true
      if [ -n "$soname" ]; then
        libver="$(echo "$soname" | sed -n 's/.*\.so\.\([0-9][0-9.]*\).*/\1/p')" || libver="$defaultver"
      fi
    fi

    mkdir -p "$devdir/lib/pkgconfig"
    cat > "$devdir/lib/pkgconfig/$lib.pc" << EOF
prefix=$out
exec_prefix=\''${prefix}
libdir=$libdir
''${includedir:+includedir=$includedir}

Name: $lib
Description: Library $lib (auto-generated)
Version: $libver
Libs: -L\''${libdir} -l$lib
''${cflags:+Cflags: $cflags}
EOF
  done
}

preFixupHooks+=(_autoPkgConfigGen)
      '')
      ;
    };
  };
}
