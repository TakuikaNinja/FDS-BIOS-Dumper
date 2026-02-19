# FDS BIOS Dumper

This program dumps the Famicom Disk System's BIOS ROM (8KiB) onto a disk.
Now you can legally obtain a dump from original hardware!

## Usage

1. Load the program. Drive emulators such as the [FDSKey](https://github.com/ClusterM/fdskey) are recommended for easy access after dumping. Physical disks will work, but dumping capabilities may be limited by write protection measures added to later disk drives.
2. A menu will appear after calculating the CRC32 checksum of the BIOS. Use the Select button to pick between 2 dumping modes:
    1. Fast - 1x 8KiB file (recommended for drive emulators, or drives with write protections disabled)
    2. Slow - 8x 1KiB files (recommended for drives with write protections present)
3. Press the Start button to begin dumping the BIOS.
4. Keep the disk inserted until the "OK!" message appears.
    1. Should any issues occur, an error message/code will be displayed. Make a note of the error number and reinsert the disk. The program will automatically retry from the file it failed on.
5. Eject the disk and extract the dumped BIOS. The extraction/reconstruction process is outside the scope of this project.
    1. Fast - `DISKSYS0` contains the entire 8KiB.
    2. Slow - `DISKSYS0` through `DISKSYS7` contain 1KiB each.

### BIOS Versions

Original RAM adapters and the Sharp Twin Famicom:

| Origin             | Rev. | CRC32    | Bootup Logo | Drop Shadows?   | Hidden Credits                 |
| :----------------- | :--- | :------: | :---------: | :-------------: | :----------------------------: |
| Older RAM adapter  | 01   | 1C7AE5D5 | "Nintendo"  | Yes             | Programmer credit only         |
| Later RAM adapter  | 01A  | 5E607DCF | "Nintendo"  | No              | "2C33", "DEV.NO.2" lines added |
| Sharp Twin Famicom | 02   | 4DF24A6C | "FAMICOM"   | Only on logo    | "2C33", "DEV.NO.2" lines added |

To access the hidden credits (P1 controller):
1. Hold Start + Select at power-on/reset. (Easier with no disk inserted)
2. Release Start + Select, then hold Right + A. This must be done before the RAM check screen appears.

See https://tcrf.net/Family_Computer_Disk_System for more details.

Here are some known aftermarket variations, for completeness (not guaranteed or useful to run on):

| Origin                        | CRC32    |
| :---------------------------- | :------: |
| Animal Crossing, Wii/Wii U VC | 0BA8D953 |
| Famicom Mini (GBA)            | 6C1BCC70 |
| 3DS VC                        | 17E30673 |
| 3DS VC (Nazo no Murasamejou)  | 34E2B2C7 |
| Game & Watch: SMB             | 7D8F0C3C |
| PowerPak                      | 93B3BD15 |
| Everdrive N8(?), N8 Pro       | CE3A3A3D |

### Error Numbers

TODO: Print messages for common errors?

Please refer to the error list on [NESdev Wiki](https://www.nesdev.org/wiki/FDS_BIOS#Error_list). The displayed error number is already in Binary-Coded Decimal (BCD) format.

## Building

The CC65 toolchain is required to build the program: https://cc65.github.io/
A simple `make` should then work.

## Acknowledgements

- `Jroatch-chr-sheet.chr` was converted from the following placeholder CHR sheet: https://www.nesdev.org/wiki/File:Jroatch-chr-sheet.chr.png
  - It contains tiles from Generitiles by Drag, Cavewoman by Sik, and Chase by shiru.
- Hardware testing was done using a Sharp Twin Famicom + [FDSKey](https://github.com/ClusterM/fdskey).
- The NESdev Wiki, Forums, and Discord have been a massive help. Kudos to everyone keeping this console generation alive!
