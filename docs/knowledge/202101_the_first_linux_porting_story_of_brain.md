# Abstract
This document details the initial journey of porting embedded Linux to the SHARP Brain electronic dictionary. It covers the hardware teardown, circuit analysis, compiling U-Boot, overcoming DRAM and microSD recognition issues, and finally reverse-engineering the undocumented LCD panel to successfully achieve a functional Linux boot.

# Page 01
Title: Do Electronic Dictionaries Dream of Embedded Linux? (電子辞書は組み込み Linux の夢を見るか？)
Author: Takumi Sueda @puhitaku
Event: Bunka no Susume #6 (分解のススメ 第6回)
Date: 2021/01/30
Version: 2.0.0

# Page 02
Self-introduction: Takumi Sueda (@puhitaku). A full-stack engineer with a preference for low-level layers. Freelance (formerly at NICT). First teardown was a PS2. Hobby: hacking including circuit analysis (e-dictionaries, routers), 3D printing, and tool development with Python/Go.

# Page 03
Back in 2010, puhitaku (16 years old at the time) obtained an electronic dictionary at a textbook sale at Tsuyama National College of Technology.

# Page 04
The model was SHARP Brain PW-GC610.

# Page 05
Looking closely at the back of the device...

# Page 06
A sticker reveals: "Windows® Embedded CE 6.0 Core".

# Page 07
Close-up of the Windows CE sticker.

# Page 08
Shocking discovery: "Windows CE is running on an electronic dictionary!?"

# Page 09
Features of the SHARP Brain series:
- Runs Windows CE.
- Can run some CE apps or custom-developed ones.
- A hacking community on 2ch already existed in 2010.
Apps available at the time:
- App launcher
- Offline Wikipedia viewer
- matplotlib
- Ported visual novels, etc.

# Page 10
The young puhitaku was deeply impressed.

# Page 11
However, due to poor software and hardware, the community's activity rapidly declined.

# Page 12
With limited technical skills at the time, puhitaku could only watch from the sidelines.

# Page 13
Time passes to 2019...

# Page 14
Looking at the Brain sleeping in a drawer, a question arose.

# Page 15
"What kind of CPU does Brain have?"

# Page 16
Googled it and was surprised!

# Page 17
It was equipped with the i.MX series, synonymous with SoCs for embedded Linux!

# Page 18
What is the i.MX series?
- SoC by Freescale (now NXP).
- A "living witness" of embedded Linux.
- Source code for Linux and U-Boot (bootloader) is available on GitHub.
- Datasheets and reference manuals are freely available.
- Evaluation boards with the same SoC as Brain can be purchased.
- puhitaku had used it extensively at work.
Photo: i.MX 283 on SHARP Brain PW-SH1.

# Page 19
The SoC was practically saying, "Please run Linux on me."

# Page 20
Wondering: "Maybe Linux can run on Brain...?"

# Page 21
Immediately bought one on Mercari.

# Page 22
A grand journey of porting Linux to SHARP Brain began.

# Page 23
Step 1: Disassemble and look inside.

# Page 24
External view of SHARP Brain PW-SH1.

# Page 25
Turning it over.

# Page 26
Stickers hiding screws.

# Page 27
Removing the stickers.

# Page 28
Removing all stickers and screws.

# Page 29
Removing the back of the hinge area.

# Page 30
Prying up the hinge part.

# Page 31
Progress of disassembly.

# Page 32
Lifting the tabs with a card.

# Page 33
Carefully lifting while watching out for the keyboard flexible cable.

# Page 34
Close-up of the keyboard connector.

# Page 35
Keyboard side separated.

# Page 36
Removing the battery.

# Page 37
Disconnecting the battery connector.

# Page 38
Keyboard side disassembly complete.

# Page 39
Back of the keyboard.

# Page 40
Mainboard analysis.
Components identified:
- NXP i.MX283 (SoC)
- Micron MT46H64M16LFBF-5 (RAM)
- Samsung KLM8G1WE4A (eMMC)
- Freescale MCQE16CLD (Power management?)
- Yamaha YMU818B (Audio)
- Magnetic sensor, Micro SD slot, Earphone jack.

# Page 41
LCD side disassembly.

# Page 42
Back of the LCD panel.

# Page 43
Parts identified through disassembly. Moving towards Linux porting.

# Page 44
The first barrier: "Circuitry" (回路).

# Page 45
Cannot move forward without understanding all peripheral circuits.

# Page 46
Using a heat gun...

# Page 47
Removing the chips.

# Page 48
Removing chips reveals the location of the "key" to inject the bootloader.

# Page 49
Applying voltage to the PSWITCH pin (Row 1, Column 11) allows injecting the bootloader via USB from a PC.

# Page 50
"Let's actually see it."

# Page 51
Further probing SoC pins and peripheral circuits with a tester.

# Page 52
Exhaustively investigating connections.

# Page 53
Reverse engineering the FPC connector pins (LCD signals, backlight, touch panel, etc.).

# Page 54
Electrical connections of the board are clarified. First step achieved.

# Page 55
The second barrier: "Bootloader" (ブートローダ).

# Page 56
U-Boot is on GitHub. There's a config for an evaluation board with the same SoC as Brain.
Hypothesis: Compiling U-Boot for the evaluation board and injecting it into Brain might work.

# Page 57
Compilation succeeded! Serial port connected! Running it...

# Page 58
Output:
HTLLCLLC
Undefined Ins
"What?"

# Page 59
What is happening?
- HTLLCLLC: Output from Boot ROM (Normal).
- Undefined Ins: "Undefined Instruction".
Forum search suggests: DRAM settings are wrong, preventing DRAM R/W.

# Page 60
The third barrier: "DRAM".

# Page 61
- Evaluation board uses DDR2 DRAM.
- Brain uses LPDDR DRAM.
U-Boot implementation for the evaluation board won't work with LPDDR.

# Page 62
"Then just write an implementation for LPDDR."

# Page 63
...It sounds easy, but...

# Page 64
Snippet of DRAM control registers from the datasheet.

# Page 65
There are about 200 DRAM-related registers.

# Page 66
Analysis using:
- Custom Python scripts.
- Register dumps from the actual Brain hardware.
- Mysterious code found on GitHub.
After many trials and errors...

# Page 67
It works! U-Boot logs show successful initialization of mx28 SDRAM controller and DRAM size detection (128 MiB).

# Page 68
Now Linux can be booted from microSD!

# Page 69
"Wait, let's load the Linux kernel from microSD... oh?"

# Page 70
The fourth barrier: "microSD".

# Page 71
U-Boot doesn't recognize the microSD. Oscilloscope shows no signals.

# Page 72
It seemed trivial but was very difficult to solve.

# Page 73
- Sniffing SD signals with an oscilloscope.
- MOSFET control for power supply.
- SoC I/O clock.
- Reviewing I/O multiplexer.
- Massive amount of printf debugging.
After many trials and errors...

# Page 74
Recognized! `mmc info` shows the SD card details.

# Page 75
The fifth barrier: "Linux kernel and Debian".

# Page 76
Conclusion: Linux worked with minor adjustments, and Debian 10 ran smoothly.

# Page 77
Console output showing Debian 10, ARM926EJ-S (v5l) CPU, and Linux kernel 5.1.15.

# Page 78
Linux is cleared! Porting is almost com...

# Page 79
"Wait, the device's LCD isn't showing anything."

# Page 80
Even if Linux boots, the screen stays dark.

# Page 81
The sixth barrier: "LCD".

# Page 82
- Uses a special standard that sends signals only when there's a change on the screen.
- Official drivers in Linux cannot be used.
- LCD model number is unknown, so data format is a mystery.
Honestly, it was very tough.

# Page 83
Found a miraculous line in the Windows boot log:
`Initializing ILI9805 controller 16bit-2`

# Page 84
"ILIxxxx" refers to ILITEK LCD drivers, used in SPI LCDs, etc.
Searching revealed: No datasheet for ILI9805, but found ILI9806.

# Page 85
External view of the ILI9805 chip on the FPC.

# Page 86
Extracting all LCD signals and analyzing with a logic analyzer.

# Page 87
Logic analyzer waveform showing the initialization sequence.

# Page 88
Comparing logic analyzer captures with the ILI9806G datasheet (Rosetta Stone method). Identified the command set.

# Page 89
Success! LCD initialization and pixel transfer in U-Boot. Showing the Tux logo.

# Page 90
Linux implementation also succeeded! Full console output on the Brain screen.

# Page 91
Close-up of the screen showing systemd boot logs.

# Page 92
What is the next barrier?

# Page 93
- Keyboard (Implementation in progress!)
- Sound
- Lid close detection
- Battery management
- Performance tuning
- Stability improvements
Still much more to enjoy.

# Page 94
Recent progress.

# Page 95
Formed the "Brain Hackers" community.

# Page 96
About 70 members on Discord, mostly students. GitHub: https://github.com/brain-hackers

# Page 97
Implementation status:
- Boot Linux without disassembly (Done)
- Boot Linux (U-Boot) from Windows (Done)
- Kernel available via GitHub Actions (Done)
- Keyboard driver implementation (In progress)
- Information gathering on Wiki (In progress)

# Page 98
Planning to provide a distribution that runs Linux just by flashing to an SD card, like Raspberry Pi.

# Page 99
Started live hacking streams on YouTube/Twitter.

# Page 100
Screenshot of a live stream showing code and the device.

# Page 101
Look forward to more hacking from me and Brain Hackers!

# Page 102
Brain Hackers logo.
