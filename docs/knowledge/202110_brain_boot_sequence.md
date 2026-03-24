# Abstract
This document provides a detailed technical breakdown of the SHARP Brain's boot sequence. It explains the process from the initial Boot ROM execution to the transition from the native Windows CE environment to Linux, detailing methods like using a custom application (BrainLILO) to chain-load U-Boot and exploring theoretical direct Boot ROM execution for deeper integration.

# Page 01
Title: Detailed Explanation - Until Linux Boots on an Electronic Dictionary (詳解・電子辞書で Linux がブートするまで)
Author: Takumi Sueda @puhitaku
Event: Brain Hackers Meetup #1
Date: 2021/10

# Page 02
Self-introduction: Takumi Sueda (@puhitaku). Freelance developer. Announced Linux porting to SHARP Brain in September 2020, founded Brain Hackers in October. Likes: all layers of technology (especially low-level), reverse engineering, beef bowls, and music.

# Page 03
Intro: A photograph of a disassembled SHARP Brain running Debian Linux, showing the console output on the built-in screen.

# Page 04
Recap: What is SHARP Brain?
- Electronic dictionary sold by SHARP running Windows CE.
- Users can add apps built for CE (.exe PE files).
Models:
- Up to 2011: TOSHIBA TMPA910CRAXBG (armv4l) + 64 MiB DRAM, Windows CE.
- 2012-2020: NXP i.MX28 (armv5tej) + 128 MiB DRAM, Windows CE.
- 2021 onwards: NXP i.MX7ULP (armv7-a, armv7e-m) + 128 MiB DRAM, µITRON based RTOS.

# Page 05
Recap: Linux Porting to Brain
- puhitaku succeeded in booting Linux on PW-SH1.
- Brain Hackers community expanded porting to all i.MX28 models.
- Released "Brainux", a custom Debian-based distribution that makes running Linux on Brain as easy as on a Raspberry Pi.
- Current work: Analysis and porting for the new PW-x1 (i.MX7ULP) models.

# Page 06
Main Topic: The Boot Sequence.

# Page 07
Windows → Linux: How it works. Diagram showing the transition from Windows CE to Linux.

# Page 08
Before moving to Linux, let's understand how Windows CE boots. It all starts immediately after reset.

# Page 09
1. Before Windows (Windows 以前).

# Page 10
What does the ARM SoC execute immediately after power-on? Photo of the i.MX28 SoC on the board.

# Page 11
A. Boot ROM.

# Page 12
A. Boot ROM (For i.MX28: On-chip ROM).

# Page 13
Peripheral Access: Immediately after power-on, the ARM core can only access things directly connected to the bus. eMMC, I2C, DRAM (requires init), and SPI are initially inaccessible.

# Page 14
On-chip ROM and On-chip RAM (SRAM) are accessible immediately after reset. The first code is read from On-chip ROM, using On-chip RAM as the workspace.

# Page 15
Boot Selection: The first bootloader in On-chip ROM selects the boot device, initializes peripherals, and loads the next bootloader. Options include USB slave (recovery), I2C, SPI, SSP (eMMC/SD), GPMI (NAND), and JTAG.

# Page 16
On Brain, the One-Time-Programmable ROM is configured to "boot from eMMC". Some models might boot from I2C EEPROM first and then transition to eMMC.

# Page 17
Program Image: The Boot ROM sequentially executes commands described in the "Program Image" located on the eMMC. These commands initialize the DRAM and load/jump to the next bootloader (EBOOT).

# Page 18
EBOOT execution: EBOOT loads the "NK image" (the packaged Windows system) into the previously initialized DRAM and jumps to it.

# Page 19
Result: Windows CE boots successfully.

# Page 20
Summary of the flow before Windows: Reset -> Boot ROM -> Program Image -> EBOOT -> Windows CE.

# Page 21
2. After Windows (Windows 以降).

# Page 22
How to make Linux work "nicely".

# Page 23
Recap: Brain runs Windows CE and allows adding custom .exe (PE) files.

# Page 24
Chain-loading: Executing a mysterious app called "BrainLILO" placed in the "App" folder on the eMMC.

# Page 25
BrainLILO loads the bootloader U-Boot (`u-boot.bin`) into DRAM.

# Page 26
Preparation: BrainLILO disables the MMU (Memory Management Unit) and performs other low-level tasks.

# Page 27
The Jump: Execution jumps to U-Boot. "Goodbye Windows..."

# Page 28
Linux Boot: U-Boot re-initializes the hardware, loads the Linux Image into memory, and jumps to it.

# Page 29
Result: Linux boots successfully.

# Page 30
Summary of the flow after Windows: Windows CE -> BrainLILO -> U-Boot -> Linux.

# Page 31
3. Various Linux Boot Methods (Linux ブートのさまざまな方法).

# Page 32
Pathways to Linux: There isn't just one way to boot Linux. Diagram showing different paths from Boot ROM/Program Image/EBOOT.

# Page 33
3.1. EBOOT → U-Boot.

# Page 34
EBOOT log from PW-SH1: It shows EBOOT trying to open `EDSA1CFG.BIN`. Some models check the external SD for an NK image before reading from internal eMMC (likely for factory testing).

# Page 35
EBOOT chain-boot: By placing a U-Boot image disguised as an NK image (`EDSA1EXE.BIN`) on an external SD card, EBOOT will load and run it.

# Page 36
3.2. Boot ROM → Custom Program Image → U-Boot.

# Page 37
Deep integration: Overwriting the "Program Image" area on the internal eMMC (where EBOOT normally resides) with a custom Program Image containing U-Boot SPL and U-Boot.

# Page 38
Status: Currently, only the EBOOT chain-load and BrainLILO methods are implemented. Custom Program Image is yet to be tackled.

# Page 39
4. Prospects for Custom Program Image (Program Image 自作の展望).

# Page 40
Why do it?
- Install Linux directly to internal eMMC (faster I/O than SD).
- Use SD card purely as external storage.
- Connect Wi-Fi dongles via SDIO (Linux has drivers for many modules).
- Use data pins as general GPIO for custom circuits.
- Essentially turns the Brain into a development board.

# Page 41
5. Summary (まとめ).

# Page 42
Summary:
- Multiple ways to boot Linux on SHARP Brain.
- From Windows via BrainLILO.
- From EBOOT (Windows bootloader).
- Directly from Boot ROM (Theoretical).
- Successfully booting from Boot ROM will open up even more possibilities.

# Page 43
Brain Hackers logo.
