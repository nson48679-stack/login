# DarkCheatKeyGate Theos Project

Day la source dylib/tweak de chen key gate vao app iOS. Khi app mo, overlay `DarkCheatVn` se hien len, goi KeyAuth `init` + `license`, key dung thi moi dong overlay.

## Build tren iPhone co Theos

```sh
cd DarkCheatKeyGateTheos
make clean
make
```

Dylib thuong nam o:

```sh
.theos/obj/debug/DarkCheatKeyGate.dylib
```

Neu build release:

```sh
make FINALPACKAGE=1
```

## KeyAuth da cau hinh

```objc
API: https://keyauth.win/api/1.2/
Application Name: Nson48679's Application
Owner ID: 3OffCALgVd
Version: 1.1
```

`Application Secret` khong duoc nhung vao dylib vi client binary co the bi dump/strings va lo secret.

## Chen vao IPA

Sau khi build ra `DarkCheatKeyGate.dylib`, chen dylib vao IPA bang tool inject cua ban, vi du `insert_dylib`, `optool`, `Azule`, `Sideloadly inject dylib`, hoac workflow rieng tren TrollStore.

Can dam bao dylib duoc load luc app khoi dong va IPA duoc sign lai phu hop voi cach cai cua ban.

## Build bang GitHub Actions

1. Tao repo moi tren GitHub.
2. Upload toan bo noi dung thu muc `DarkCheatKeyGateTheos` len repo.
3. Vao tab `Actions`.
4. Chon workflow `Build DarkCheatKeyGate`.
5. Bam `Run workflow`.
6. Sau khi build xong, mo run do va tai artifact `DarkCheatKeyGate-dylib`.

File can lay trong artifact:

```sh
DarkCheatKeyGate.dylib
```

Neu workflow loi o buoc `brew install ldid`, xoa `ldid` khoi dong do va chay lai. Buoc build dylib thuong khong can package `.deb`.

Xem them file `GITHUB_REPO_STEPS.md` neu ban upload bang GitHub web.
