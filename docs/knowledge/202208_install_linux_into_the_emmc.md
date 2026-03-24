# Abstract
This document explains the process of analyzing the SHARP Brain's boot sequence to install and boot Linux directly from the internal eMMC. It details the reverse engineering of the i.MX28 Boot Mode selection via OTP ROM, extracting the I2C EEPROM configurations, and overwriting the eMMC's boot stream to replace Windows CE completely with U-Boot and Linux.

# Page 01
Title: How to Erase the Identity of an Electronic Dictionary (電子辞書のアイデンティティを消す方法)
Author: Takumi Sueda @puhitaku
Event: 54th Information Science Young Researchers Workshop (#wakate2022)
Date: 2022/08

# Page 02
Self-introduction: Takumi Sueda (@puhitaku). Freelance developer. Developed for HOMMA Inc., etc. Likes: all layers of technology, reverse engineering, 3D printing, and music. Past event participation: 2020 Linux porting to Brain, 2021 TEPRA Lite BLE reverse engineering.

# Page 03
Introduction.

# Page 04
The electronic dictionary introduced today is...

# Page 05
SHARP Brain. Photo of it running Debian Linux.

# Page 06
Recap: Presented "Do Electronic Dictionaries Dream of Embedded Linux?" at the 53rd workshop in 2020.

# Page 07
Slides and articles of previous presentations are available on the author's blog.

# Page 08
What is SHARP Brain?

# Page 09
Features:
- Electronic dictionary brand launched by SHARP in 2008.
- Equipped with Windows CE (until 2020 models).
- Can run custom-compiled .exe files.
- Hacking community established on 2ch shortly after launch.
Apps: App launcher, Offline Wikipedia, matplotlib, visual novels, etc.

# Page 10
Hardware:
- CPU: NXP i.MX283 (ARM926EJ-S, armv5tej) at 454 MHz.
- DRAM: LPDDR 128MB.
- LCD: 800x480, etc.
- SD: SDXC slot available.
- eMMC: 8GB (internal, non-removable).
- Others: Battery, touch panel, magnetic sensor (lid detection).
Composition-wise, it's like a very old and simple first-generation Raspberry Pi with a keyboard, LCD, and battery.

# Page 11
Recent Achievements:
- Succeeded in booting Linux in 2020.
- Founded "Brain Hackers" community, expanded support to more models.
- Released "Brainux", a custom Debian-based distribution.
- Just download the OS image and flash it to an SD card to run Linux.

# Page 12
Even with porting success, many things remained to be done. One of them: "Overwriting Windows with Linux."

# Page 13
SD vs eMMC: Booting from SD card was established, but installing directly to the internal 8GB eMMC was not yet achieved.

# Page 14
Why install Linux to eMMC?
- Better storage performance than SD.
- Free up the SD slot for other uses.
Example SD slot uses:
- Connect Wi-Fi dongles via SDIO (Linux has mainline drivers for some modules).
- Connect custom circuits via GPIO.
- It becomes essentially a development board.

# Page 15
Install Linux into the Brain itself and make it a pure Linux machine! "Good-bye, Windows!! Good-bye, Electronic Dictionary!!"

# Page 16
What is needed to boot Linux from eMMC?

# Page 17
A powered-on computer goes through a process called "Boot" to initialize hardware and prepare to run software.

# Page 18
When Brain's power is turned on, several "bootloaders" perform the boot process, eventually starting Windows CE.

# Page 19
The flow from the moment power is applied until the system finishes booting is called the "Boot Sequence."

# Page 20
To achieve eMMC boot, one must trace the connection between the SoC behavior and bootloaders from power-on and appropriately overwrite that sequence.

# Page 21
Explanation and Analysis of the Boot Sequence: Reset ~ Boot ROM.

# Page 22
Photo of the i.MX28 SoC. What does it execute immediately after power-on?

# Page 23
A. Boot ROM.

# Page 24
A. Boot ROM (called On-chip ROM in i.MX28).

# Page 25
Immediately after reset, external peripherals are uninitialized and unusable. The CPU can generally only access locations directly connected by the bus. eMMC, DRAM, I2C, and SPI are inaccessible.

# Page 26
On-chip ROM and On-chip RAM (SRAM) are accessible via the bus immediately after reset. The CPU executes the instruction sequence in On-chip ROM using On-chip RAM as its workspace.

# Page 27
The CPU uses the Boot ROM (the first bootloader) to select the boot device, initialize peripherals, and read the next bootloader. Devices include USB recovery, I2C, SPI, SSP (eMMC/SD), GPMI (NAND), and JTAG.

# Page 28
The Boot ROM decides which external device to read the next bootloader from by looking at the "Boot Mode" written in the "One-Time Programmable (OTP) ROM".

# Page 29
One-Time Programmable (OTP) ROM:
- Non-erasable ROM implemented in the SoC's semiconductor, programmable only once.
- The first area used to convey the developer's intent to the CPU.
- Device-specific settings for boot devices are also written here.
"Let's look inside the OTP to find the first boot device!"

# Page 30
Analysis of the OTP settings.

# Page 31
Recap: Brain allows running custom exe files.

# Page 32
Using a "divine tool" called Scalpel that can see the entire memory space from Windows CE.

# Page 33
According to the datasheet, the 8 MSB bits of the 32-bit value at address 0x8002C1A0 is the BOOT_MODE. Reading it with Scalpel results in 0x01 (0b00000001).

# Page 34
Referring to the i.MX28 "Boot Mode Selection Map" table in the datasheet: BOOT_MODE 0bXXX00001 corresponds to I2C0 master, 3.3 V.

# Page 35
Conclusion: The CPU is configured to read from an EEPROM connected via I2C first.

# Page 36
Extracting and reading the EEPROM content.

# Page 37
Question: "Where is the EEPROM on the Brain board?" (Photo of the mainboard).

# Page 38
Answer: Located at U502 (highlighted in a pink box).

# Page 39
Identifying the EEPROM: Probing pins with an oscilloscope while cycling power. Found 100kHz/400kHz clocks characteristic of I2C. Narrowed down the part number via Digi-Key footprint search: VSON package, 2mm x 3mm, 0.5mm thick (Rohm). Marking "4G3" identifies it as Rohm BR24G32 (4KB).

# Page 40
Reading it: Soldered 0.2mm polyurethane wires under a stereomicroscope and read with a Saleae logic analyzer.

# Page 41
EEPROM Content: Contains a "Boot Stream" (SB) structure. These are commands sequentially executed by the Boot ROM. Using `sbtoelf` tool from the Rockbox repository and Ghidra to disassemble the binary. Example commands: LOAD, FILL, CALL, MODE.

# Page 42
Flow of binary deployment in SRAM after executing SB commands: CALL command -> Jump to entry point 0xE61C (Instructions armv5tej) -> Return.

# Page 43
What the Boot ROM does after reading EEPROM:
- Writes specific settings to eMMC peripherals.
- Transitions to eMMC boot mode (MODE command to 0x09).
- Once in eMMC boot mode, it parses the SB found on the eMMC (similar to the process with EEPROM).

# Page 44
Summary: The CPU reads the I2C EEPROM to configure eMMC settings before transitioning to eMMC boot.

# Page 45
Extracting and reading the eMMC content.

# Page 46
Dumping eMMC is easy: Boot Linux from SD and use `dd` on `/dev/mmcblk0`. Looking at the Master Boot Record (MBR) for an entry with i.MX28 specific partition type 0x53. The beginning of that partition contains a pointer (sector number) to the SB.

# Page 47
Structure of data related to boot on eMMC: Sector 0 (MBR) -> Sector 256 (SB) -> Sector 2304 (?) -> Sector 198912 (FAT32 partition with Windows CE). Flow: 1. Read MBR, 2. Read & run SB, 3. Run EBOOT.

# Page 48
Summary: The CPU reads eMMC to execute EBOOT (Windows CE bootloader).

# Page 49
Transition to Windows: EBOOT extracts the "NK image" (packaged Windows system) from eMMC to DRAM and jumps to it.

# Page 50
The boot sequence from reset to Windows CE is completely clarified! Reset -> On-chip ROM -> I2C EEPROM -> eMMC -> Windows CE.

# Page 51
Deciding which part of the boot sequence to overwrite.

# Page 52
Where to put the custom binary to boot Linux?
- I2C EEPROM SB: OS-independent (only does hardware adjustments).
- eMMC SB: Contains Windows CE's EBOOT (OS-dependent).
Strategy: Overwrite the content of eMMC with custom data.

# Page 53
Experiment: Use USB boot mode to transition to eMMC boot and start Windows.

# Page 54
"USB boot mode" allows booting from a PC without involving the EEPROM. If a PC-injected SB that merely transitions to eMMC boot succeeds in starting Windows CE, then the EEPROM content is confirmed to be OS-independent. (Using U-Boot's `mkimage` to generate SB).

# Page 55
Forcing USB boot mode by shorting the pads (JP501) next to the eMMC while connecting USB.

# Page 56
Result: Success. Decided to keep the EEPROM as is and overwrite the eMMC content.

# Page 57
Creating an eMMC image containing the bootloader.

# Page 58
Using U-Boot (Das U-Boot), commonly used in embedded Linux. Modified it to read from eMMC instead of SD. Modified the OS image generation script to include SB and U-Boot.

# Page 59
Structure of the OS image for eMMC: MBR (Entry 0: FAT32, Entry 1: SB, Entry 2: Ext4) -> Sector 2048 (FAT32 partition with Tux logo) -> Sector 20800 (SB with U-Boot) -> Sector 24800 (Ext4 rootfs). Flow: 1. Read MBR, 2. Read & run SB, 3. Run U-Boot.

# Page 60
Writing the eMMC image and booting.

# Page 61
Flashing eMMC: Just use `dd` on the actual device using an eMMC image hidden on a Linux-bootable SD card. Don't forget backups! If flashing fails, it can be recovered via USB boot + serial (UART) if you can do fine soldering.

# Page 62
Connecting UART (serial) to the development PC. Photo of the tiny wires soldered to test points and connected to a USB-Serial adapter.

# Page 63
Success! Console output shows Linux 5.4.149 booting. `mount | grep mmcblk0` shows `/dev/mmcblk0p3` mounted as rootfs (ext4).

# Page 64
SHARP Brain has stepped into its new life as a Linux machine, leaving its identity as an electronic dictionary behind.

# Page 65
Summary.

# Page 66
Summary: Even if implementation varies by SoC or architecture, the concept of bootloaders and boot sequences is common to all computers. If you want to fundamentally change the behavior of your hardware, grab a soldering iron and dig into the boot sequence.
