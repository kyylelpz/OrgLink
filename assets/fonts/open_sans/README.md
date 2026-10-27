# Open Sans

Bundled unchanged from the official Google Fonts repository on 27 October 2026:

- Font: https://github.com/google/fonts/blob/main/ofl/opensans/OpenSans%5Bwdth%2Cwght%5D.ttf
- License: https://github.com/google/fonts/blob/main/ofl/opensans/OFL.txt
- Copyright: 2020 The Open Sans Project Authors.
- License: SIL Open Font License 1.1; the complete notice is in OFL.txt.

The upstream variable TrueType file is named OpenSans-Variable.ttf locally. It is
registered as Open Sans in pubspec.yaml. The application bundles the license as
an asset and registers it with Flutter's LicenseRegistry when the theme initializes.
No runtime download or google_fonts dependency is used. Flutter 3.44 supports
selecting the variable weight axis through FontWeight.

SHA-256:

```text
OpenSans-Variable.ttf 36643644f318a812aab2d2ed3bb98f8cf0872527f835fe9398d95fe6b9adb878
OFL.txt               fbbbcfef55318de350562559b671360de6d597112ecc5c73881b05092db89602
```
