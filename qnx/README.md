# ewftools for QNX 6.5.0 (armle-v7)

Static `ewfacquire`, `ewfacquirestream`, `ewfexport`, `ewfinfo` and `ewfverify`
for QNX Neutrino 6.5.0 on 32-bit ARM, built from a libewf release tarball.

```sh
qnx/build.sh                 # libewf 20260924, tuned for Cortex-A8
qnx/build.sh 20260924 cortex-a9
```

The toolchain image comes from
[Nachtalb/qnx65-armv7-toolchain](https://github.com/Nachtalb/qnx65-armv7-toolchain/tree/fix/debian-mirrors);
`build.sh` lists the `docker build` line.

On the device:

- Put options before the source. QNX `getopt` stops at the first non-option,
  so `ewfacquire /dev/hd0 -t out` treats `-t` and `out` as extra inputs.
- Run it on the node that owns the disk (`on -f <node> ...`); acquiring over
  Qnet is many times slower.
- On small or busy systems use a low priority (`on -p 1`) and
  `-c empty-block`, so the acquisition does not starve the rest of the system.
