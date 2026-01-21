# Automatic Swap Detection

## Overview

ArchInstaller automatically determines the optimal swap configuration based on your hardware and installation profile. You no longer need to manually choose between ZRAM, swapfile, or both.

## Detection Logic

The script analyzes:
- **RAM size** - Determines swap needs and sizing
- **Storage type** (SSD/HDD) - Affects performance strategy
- **Installation type** (SERVER/DESKTOP/MINIMAL) - Tailors to use case
- **Virtual machine detection** - Optimizes for VPS/cloud environments
- **Laptop detection** - Enables hibernation support when needed

## Decision Priority

1. **VPS/Cloud** - Overrides all other considerations
2. **Laptop** - Enables hibernation support
3. **Installation Type** - SERVER/DESKTOP/MINIMAL optimization

## Configuration Matrix

### VPS/Cloud (Highest Priority)

| RAM | Strategy | ZRAM | Swapfile | Reason |
|-----|----------|------|----------|--------|
| < 4GB | VPS_LOW_RAM | 2x RAM | RAM/2GB | Prevents OOM, saves I/O |
| ≥ 4GB | VPS_OPTIMAL | 1x RAM | None | Saves I/O costs |

**Rationale**: VPS/Cloud providers typically charge for I/O operations. ZRAM provides fast swap without disk I/O costs. Small swapfile is only added for low-RAM systems as a safety net.

---

### Laptop (Second Priority)

| RAM | Strategy | ZRAM | Swapfile | Reason |
|-----|----------|------|----------|--------|
| Any | LAPTOP_HIBERNATION | 1.5x RAM | RAM size | Hibernation support |

**Rationale**: Laptops require swapfile for hibernation (suspend to disk). ZRAM provides performance during daily use, while swapfile (sized equal to RAM) enables hibernation.

---

### Server

| RAM | Storage | Strategy | ZRAM | Swapfile | Reason |
|-----|---------|----------|------|----------|--------|
| < 4GB | Any | SERVER_CRITICAL | 2x RAM | 4GB | Avoids OOM |
| 4-16GB | SSD | SERVER_SSD_OPTIMAL | 2x RAM | None | Optimal performance |
| 4-16GB | HDD | SERVER_HDD_BACKUP | 2x RAM | 4GB | HDD too slow |
| ≥ 16GB | Any | SERVER_HIGH_RAM | 1x RAM | None | Sufficient RAM |

**Rationale**: Performance is critical for servers. ZRAM on SSD provides superior performance over disk swap. Swapfile is only used for low-RAM systems or HDD as backup.

---

### Desktop / Full

| RAM | Storage | Strategy | ZRAM | Swapfile | Reason |
|-----|---------|----------|------|----------|--------|
| < 8GB | Any | DESKTOP_HIBERNATION | 1x RAM | RAM + 2GB | Hibernation + safety |
| 8-32GB | Any | DESKTOP_HIBERNATION | 1x RAM | RAM size | Hibernation support |
| > 32GB | Any | DESKTOP_HIBERNATION | 1x RAM | 8GB | Partial hibernation |

**Rationale**: Desktops benefit from both ZRAM (performance) and swapfile (hibernation). Swapfile sized to RAM allows full hibernation. On HDD, ZRAM multiplier is increased (1.5x) due to slow disk.

---

### Minimal

| RAM | Storage | Strategy | ZRAM | Swapfile | Reason |
|-----|---------|----------|------|----------|--------|
| < 4GB | Any | MINIMAL_LOW_RAM | 2x RAM | 2GB | Avoids OOM |
| 4-16GB | SSD | MINIMAL_OPTIMAL | 1x RAM | None | Saves disk space |
| 4-16GB | HDD | MINIMAL_HDD | 1x RAM | 2GB | HDD backup |
| ≥ 16GB | Any | MINIMAL_HIGH_RAM | 0.5x RAM | None | RAM sufficient |

**Rationale**: Minimal installations prioritize resource efficiency. ZRAM provides efficient swap with minimal disk usage. Swapfile only for HDD or low-RAM systems.

---

## Technical Details

### Detection Methods

**VM/VPS Detection**:
```bash
systemd-detect-virt
```
- Returns `kvm`, `vmware`, `qemu`, etc. if running in VM
- Returns `none` if bare metal

**Laptop Detection**:
```bash
ls /sys/class/power_supply/ | grep -q "BAT"
```
- Returns true if battery detected
- Enables hibernation support

**Storage Type**:
```bash
lsblk -n --output TYPE,ROTA <disk>
```
- Returns `0` for SSD (non-rotational)
- Returns `1` for HDD (rotational)

**RAM Size**:
```bash
grep -i 'memtotal' /proc/meminfo
```
- Returns total RAM in KB
- Converted to GB for calculations

---

### ZRAM Configuration

**ZRAM Generator Config** (`/mnt/etc/systemd/zram-generator.conf`):
```ini
[zram0]
zram-size = ram * <multiplier>
swap-priority = 100
compression-algorithm = zstd
```

**Multipliers**:
- VPS low RAM: 2x
- Laptop: 1.5x
- Server low RAM: 2x
- Server high RAM: 1x
- Desktop: 1x (1.5x on HDD)
- Minimal: 1x (0.5x for high RAM, 2x for low RAM)

**Priority**: 100 (highest priority over swapfile)

---

### Swapfile Configuration

**Btrfs Swapfile**:
- Location: `/swap/swapfile`
- Dedicated @swap subvolume (prevents snapshot conflicts)
- Mount options: `nodatacow` (required for swap)
- Entry added to `/etc/fstab`:
  ```
  UUID=<root_uuid>	/swap	btrfs	<options>,subvol=/@swap,nodatacow	0	0
  ```

**Standard Swapfile** (ext4/others):
- Location: `/swapfile`
- Permissions: 600
- Entry added to `/etc/fstab`:
  ```
  /swapfile	none	swap	defaults	0	0
  ```

**Priority**:
- ZRAM + Swapfile: Swapfile priority 50
- Swapfile only: Default priority

---

### Swappiness Configuration

**ZRAM Systems**:
```bash
vm.swappiness=10
```
- Lower swappiness prefers RAM over swap
- ZRAM is fast enough that aggressive swapping is acceptable

**Swapfile Only Systems**:
```bash
vm.swappiness=60
```
- Moderate swappiness balances performance
- Avoids excessive slow disk swapping

---

## Examples

### Example 1: VPS with 2GB RAM

```
System Hardware Analysis:
  RAM: 2GB
  Storage: SSD
  Filesystem: ext4
  Installation Type: SERVER
  Available Disk Space: 19GB
  Virtual Machine: Yes (kvm)
  Laptop: No

Analyzing optimal swap configuration...

Strategy: VPS with low RAM (2GB) - ZRAM + small swapfile
  - ZRAM: 2x RAM (4GB) for performance
  - Swapfile: 1GB as safety net (saves I/O costs)
```

---

### Example 2: Desktop with 16GB RAM, SSD

```
System Hardware Analysis:
  RAM: 16GB
  Storage: SSD
  Filesystem: btrfs
  Installation Type: FULL
  Available Disk Space: 120GB
  Virtual Machine: No
  Laptop: No

Analyzing optimal swap configuration...

Strategy: Desktop - ZRAM + Swapfile (hibernation support)
  - ZRAM: 1x RAM (16GB) for daily performance
  - Swapfile: 16GB for hibernation support
```

---

### Example 3: Server with 8GB RAM, HDD

```
System Hardware Analysis:
  RAM: 8GB
  Storage: HDD
  Filesystem: btrfs
  Installation Type: SERVER
  Available Disk Space: 45GB
  Virtual Machine: No
  Laptop: No

Analyzing optimal swap configuration...

Strategy: Server with HDD (8GB RAM) - ZRAM + Swapfile
  - ZRAM: 2x RAM (16GB) for performance
  - Swapfile: 4GB as HDD backup (HDD is too slow for daily swap)
```

---

### Example 4: Laptop with 8GB RAM, SSD

```
System Hardware Analysis:
  RAM: 8GB
  Storage: SSD
  Filesystem: btrfs
  Installation Type: FULL
  Available Disk Space: 250GB
  Virtual Machine: No
  Laptop: Yes

Analyzing optimal swap configuration...

Strategy: Laptop detected - ZRAM + Swapfile (hibernation support)
  - ZRAM: 1.5x RAM (12GB) for daily performance
  - Swapfile: 8GB (equals RAM size) for hibernation
```

---

## Performance Comparison

| Configuration | Latency | Throughput | CPU Usage |
|---------------|----------|-------------|-----------|
| ZRAM | ~0.001µs | 10-30 GB/s | Low (compression) |
| SSD Swap | 10-100µs | 200-500 MB/s | None |
| HDD Swap | 10-20ms | 100-200 MB/s | None |

**Conclusion**: ZRAM is 10,000x faster than SSD and 10,000,000x faster than HDD.

---

## Troubleshooting

### Swapfile Not Working After Boot

1. Check if @swap subvolume is mounted:
   ```bash
   findmnt /swap
   ```
   Expected: Should show @swap subvolume

2. Check if swapfile exists:
   ```bash
   ls -lh /swap/swapfile
   ```

3. Check fstab entries:
   ```bash
   grep -E "(swap|@swap)" /etc/fstab
   ```
   Expected: Both @swap mount and swapfile activation entries

---

### ZRAM Not Active

1. Check if ZRAM module is loaded:
   ```bash
   lsmod | grep zram
   ```

2. Check ZRAM configuration:
   ```bash
   cat /etc/systemd/zram-generator.conf
   ```

3. Check systemd service:
   ```bash
   systemctl status systemd-zram-setup@zram0.service
   ```

---

### Need Different Configuration

If you want to manually adjust swap after installation:

**Adjust ZRAM size**: Edit `/etc/systemd/zram-generator.conf`
```ini
[zram0]
zram-size = ram * 2  # Change multiplier
```

**Adjust swapfile size**: Recreate swapfile with different size
```bash
sudo swapoff /swap/swapfile
sudo rm /swap/swapfile
sudo fallocate -l 8G /swap/swapfile
sudo chmod 600 /swap/swapfile
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
```

**Disable ZRAM**:
```bash
sudo systemctl disable systemd-zram-setup@zram0.service
sudo swapoff /dev/zram0
```

---

## Summary

The automatic swap detection eliminates the need for manual configuration while ensuring optimal performance for each system type:

- **VPS/Cloud**: Minimizes I/O costs
- **Laptops**: Enables hibernation
- **Servers**: Maximizes performance
- **Desktops**: Balances performance with hibernation
- **Minimal**: Efficient resource usage

The system detects hardware and use case, then applies the best configuration automatically.
