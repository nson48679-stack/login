# Cach build bang GitHub repo

## Cach nhanh nhat tren GitHub web

1. Vao GitHub va tao repo moi, vi du `DarkCheatKeyGateTheos`.
2. Giai nen `DarkCheatKeyGateTheos.zip`.
3. Upload toan bo file/folder ben trong `DarkCheatKeyGateTheos` len repo.
4. Dam bao repo co file nay:

```text
.github/workflows/build.yml
Makefile
Tweak.xm
README.md
```

5. Vao tab `Actions`.
6. Chon workflow `Build DarkCheatKeyGate`.
7. Bam `Run workflow`.
8. Doi build xong, vao run vua chay.
9. Tai artifact `DarkCheatKeyGate-dylib`.

File can lay trong artifact:

```text
DarkCheatKeyGate.dylib
```

## Neu GitHub Actions bi loi

Neu loi o buoc `brew install ldid xz`, sua `.github/workflows/build.yml`:

```yaml
brew install xz
```

roi chay lai workflow.

Neu loi SDK/iOS target, doi dong nay trong `Makefile`:

```make
TARGET := iphone:clang:latest:14.0
```

thanh:

```make
TARGET := iphone:clang:latest:15.0
```

roi push/chay lai.
