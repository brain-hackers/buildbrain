# Abstract
This document provides a technical deep dive into Linux suspend mechanisms, focusing on the implementation of Suspend-to-RAM for the SHARP Brain electronic dictionary. It explains the transition and resume flows, the required power management and wakeup interrupt handler implementations, and the specific challenges faced, such as handling I2C-based key events and device tree configurations for power regulators.

# Page 01
Title: Learning Linux Suspend with an Electronic Dictionary (電子辞書で学ぶ Linux のサスペンド)
Author: Takumi Sueda aka @puhitaku
Event: Information Science Young Researchers Workshop Spring Edition 2023 (#wakate2023s)
Date: 2023/04

# Page 02
Self-introduction: Takumi Sueda (@puhitaku). Freelance developer. Working for HOMMA Inc. Author, Security Camp instructor, OSS license consultant, etc. Likes: low-level technology, reverse engineering, 3D printing, music. Attending the workshop almost every year since 2014.

# Page 03
Writing a series "Let's Run Linux on an Electronic Dictionary" for Nikkei Linux magazine. Part 3 will be in the May issue.

# Page 04
The target device: SHARP Brain. Photo showing it running Debian Linux.

# Page 05
Features of SHARP Brain:
- Electronic dictionary brand launched in 2008.
- Equipped with Windows CE (up to 2020 models).
- Community established since launch.
- Users can run custom exe files.

# Page 06
Hardware:
- CPU: NXP i.MX283 (ARM926EJ-S, 454MHz).
- DRAM: LPDDR 128MB.
- LCD: 800x480, etc.
- SDXC slot.
- eMMC: 8GB internal.
- Battery, touch panel, magnetic sensor.
Similar to a primitive Raspberry Pi with a keyboard, LCD, and battery.

# Page 07
U-Boot and Linux porting:
- Success in 2020.
- Released "Brainux" distribution (bootable from SD card).
Implemented drivers/features:
- LCD (newly implemented).
- Keyboard (newly implemented).
- Touch panel.
- SD / eMMC R/W.
- Beep sounds via piezo element.

# Page 08
Unimplemented features:
- Power management (Sleep, cpufreq).
- Sound.

# Page 09
Focus of today's talk: Power management, specifically "Sleep".

# Page 10
What is "Sleep"?

# Page 11
There are several types of "Sleep" (system-wide sleep) in Linux:
- Suspend-to-Idle.
- Standby.
- Suspend-to-RAM.
- Hibernation.
Generally, lower items consume less power.

# Page 12
1. Suspend-to-Idle: Purely software-based sleep that just idles the CPU. Stops userspace, timekeeping, and I/O.
2. Standby: Powers off unused CPUs during boot to save more power.
3. Suspend-to-RAM: Saves CPU and device state to DRAM and powers off almost all hardware except DRAM and resume logic.
4. Hibernation: Saves state to persistent storage and shuts down. Saves all hardware.

# Page 13
For an electronic dictionary, Suspend-to-RAM is the target to balance power reduction and resume time.

# Page 14
Flow of Suspend-to-RAM transition and resume.

# Page 15
Flow of transitioning to Suspend-to-RAM:
1. Notify the whole system, preparing kernel subsystems for sleep.
2. Freeze tasks.
3. Configure devices to not handle interrupts except those for suspend/resume.
4. Stop non-boot CPUs (tasks/IRQs migrate to Boot CPU).
5. Disable scheduler tick and stop context switching.
6. Hand control to platform-specific firmware to transition to low-power state or cut power (except for RAM).
7. Sleep until an interrupt from a resume device (e.g., keyboard) arrives.

# Page 16
Flow of resuming from Suspend-to-RAM:
1. Interrupt from a resume device arrives.
2. CPU resumes and handles the interrupt (platform-dependent process).
3. Control returns to the kernel.
4. Resume kernel core, tick, and scheduling.
5. Wake up non-boot CPUs.
6. Wake up devices and restore IRQs.
7. Thaw tasks.
8. Send resume notifications to the whole system.

# Page 17
What is needed to implement Suspend-to-RAM on new hardware?

# Page 18
Two essential elements for Suspend-to-RAM:
1. Power Management: Implement functions in the driver's `dev_pm_ops` structure to gracefully cut power upon suspend notification. Describe device-regulator (power) relationships in the Device Tree. (e.g., SoC internal regulators, MOSFETs for external hardware, SPI/I2C peripherals).
2. Wakeup Interrupt Handler: Implement procedures in the Interrupt Service Routine (ISR) to instruct the Power Management Subsystem to resume when a valid wakeup input arrives. (e.g., magnetic sensor for lid, GPIO for power button).

# Page 19
Side responsible for executing Suspend-to-RAM:
- Call stack overview starting from writing to `/sys/power/state`.
- Device Tree example: Describing the relationship between the LCD panel and its DVDD/AVDD power supplies. The kernel uses this info to toggle power.

# Page 20
Communication between the wakeup ISR and the suspend execution code:
1. Driver's ISR calls `pm_wakeup_event()` to increment a counter in the PM subsystem.
2. `suspend_enter` checks the counter after the CPU PC returns. If incremented, it exits the loop; otherwise, it puts the CPU back to sleep.
Conclusion: Interrupts unrelated to resume are ignored.

# Page 21
Implementation status on SHARP Brain.

# Page 22
Suspend-to-RAM is partially achieved but still a work in progress:
- [Check] Execution of Suspend-to-RAM.
- [Check] Resume via power button (on models where key matrix is directly read via GPIO).
- [WIP] Resume via power button (on models where key events are read from MCU via I2C).
  - Problem: I2C peripheral-level interrupt wakes the device for any key press. Most peripherals are sleeping, so ISR capabilities are limited.
  - Might need reverse engineering of how Windows handles this.
- [WIP] Power control for LCD, etc. (Describe GPIOs connected to FET gates/ENABLE pins as regulators in Device Tree).
- [WIP] Verifying power consumption reduction.
- [WIP] Release as OS image.

# Page 23
Q&A Log:
Q: In what order do kthread and userspace processes freeze?
A: `suspend_prepare` -> `suspend_freeze_processes`. Userspace freezes first.
Q: What is the difference in power saving between the 4 methods?
A: Depends on the system. On Brain (small SoC), the difference between Suspend-to-Idle and Standby is small (115mA -> 86mA). Suspend-to-RAM's impact will be measured after implementing LCD power control.

# Page 24
References: Bootlin Elixir (Linux source browser), Mainline Linux documentation (suspend-flows.rst, sleep-states.rst).
Diagram showing the interaction between Brain and a development PC.
