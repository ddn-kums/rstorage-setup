#!/usr/bin/env python3
"""
Core Mask Generator Tool
Generates proper core masks for various tasks on systems with 32c/64t and above
"""

import subprocess
import re
import json
from collections import defaultdict
from typing import List, Dict, Tuple, Set
import argparse
import sys


class SystemTopology:
    """Class to parse and store system topology information"""
    
    def __init__(self):
        self.numa_nodes = {}
        self.total_cores = 0
        self.total_threads = 0
        self.nvme_devices = []
        self.mellanox_adapters = []
        self.filesystem_nvme = set()
        
    def parse_lscpu(self):
        """Parse lscpu output to get NUMA topology"""
        try:
            output = subprocess.check_output(['lscpu'], text=True)
            
            # Parse total CPUs
            cpu_match = re.search(r'CPU\(s\):\s+(\d+)', output)
            if cpu_match:
                self.total_threads = int(cpu_match.group(1))
            
            # Parse cores per socket
            cores_match = re.search(r'Core\(s\) per socket:\s+(\d+)', output)
            sockets_match = re.search(r'Socket\(s\):\s+(\d+)', output)
            if cores_match and sockets_match:
                self.total_cores = int(cores_match.group(1)) * int(sockets_match.group(1))
            
            # Parse NUMA nodes
            numa_pattern = re.compile(r'NUMA node(\d+) CPU\(s\):\s+([\d,\-]+)')
            for match in numa_pattern.finditer(output):
                numa_id = int(match.group(1))
                cpu_list = self._parse_cpu_list(match.group(2))
                self.numa_nodes[numa_id] = cpu_list
                
        except subprocess.CalledProcessError as e:
            print(f"Error running lscpu: {e}")
            sys.exit(1)
    
    def parse_lstopo(self):
        """Parse lstopo to find NVMe devices and Mellanox adapters"""
        # Get filesystem-used NVMe devices first
        self._get_filesystem_nvme_devices()
        
        # Parse NVMe devices using lspci (more comprehensive)
        self._parse_nvme_devices_lspci()
        
        # Parse for Mellanox adapters
        self._parse_mellanox_adapters_lspci()
    
    def _get_filesystem_nvme_devices(self):
        """Get list of NVMe devices used by filesystems"""
        self.filesystem_nvme = set()
        try:
            # Get mounted filesystems
            df_output = subprocess.check_output(['df'], text=True)
            for line in df_output.strip().split('\n')[1:]:  # Skip header
                parts = line.split()
                if parts and parts[0].startswith('/dev/nvme'):
                    # Extract nvme device name (e.g., nvme7 from /dev/nvme7n1p2)
                    match = re.match(r'/dev/(nvme\d+)', parts[0])
                    if match:
                        self.filesystem_nvme.add(match.group(1))
                        print(f"Excluding {match.group(1)} - used by filesystem {parts[5]}")
        except subprocess.CalledProcessError:
            pass
    
    def _parse_nvme_devices_lspci(self):
        """Parse NVMe devices using lspci for comprehensive detection"""
        try:
            # Get all NVMe controllers using lspci
            lspci_output = subprocess.check_output(['lspci'], text=True)
            nvme_pattern = re.compile(r'([0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f])\s+Non-Volatile memory controller:')
            
            device_count = 0
            for match in nvme_pattern.finditer(lspci_output):
                pci_addr = match.group(1)
                
                # Get detailed info including NUMA node
                try:
                    detailed_output = subprocess.check_output(['lspci', '-vvv', '-s', pci_addr], text=True)
                    
                    # Extract NUMA node
                    numa_match = re.search(r'NUMA node:\s+(\d+)', detailed_output)
                    if numa_match:
                        numa_node = int(numa_match.group(1))
                        
                        # Try to find corresponding nvme device name
                        nvme_name = None
                        driver_match = re.search(r'Kernel driver in use:\s+(\w+)', detailed_output)
                        
                        if driver_match and driver_match.group(1) == 'nvme':
                            # Find nvme device by PCI address
                            try:
                                # Check /sys/class/nvme/*/device link
                                nvme_dirs = subprocess.check_output(['ls', '/sys/class/nvme/'], text=True).strip().split()
                                for nvme_dir in nvme_dirs:
                                    if nvme_dir.startswith('nvme'):
                                        device_link = f'/sys/class/nvme/{nvme_dir}/device'
                                        if os.path.exists(device_link):
                                            real_path = os.readlink(device_link)
                                            if pci_addr in real_path:
                                                nvme_name = nvme_dir
                                                break
                            except:
                                pass
                        
                        # If no name found, create a placeholder
                        if not nvme_name:
                            nvme_name = f"nvme_pci_{pci_addr.replace(':', '_').replace('.', '_')}"
                        
                        # Check if this device is used by filesystem
                        if nvme_name in self.filesystem_nvme:
                            continue  # Skip filesystem devices
                        
                        self.nvme_devices.append({
                            'name': nvme_name,
                            'pci': pci_addr,
                            'numa_node': numa_node
                        })
                        device_count += 1
                        
                except subprocess.CalledProcessError:
                    pass
            
            print(f"Found {device_count} NVMe devices available for allocation")
            
        except subprocess.CalledProcessError as e:
            print(f"Error running lspci: {e}")
    
    def _parse_mellanox_adapters_lspci(self):
        """Parse Mellanox adapters using lspci"""
        try:
            lspci_output = subprocess.check_output(['lspci'], text=True)
            mellanox_pattern = re.compile(r'([0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f])\s+.*Mellanox.*')
            
            for match in mellanox_pattern.finditer(lspci_output):
                pci_addr = match.group(1)
                
                # Get NUMA node for this PCI device
                try:
                    numa_path = f'/sys/bus/pci/devices/0000:{pci_addr}/numa_node'
                    with open(numa_path, 'r') as f:
                        numa_node = int(f.read().strip())
                        if numa_node >= 0:
                            self.mellanox_adapters.append({
                                'pci': pci_addr,
                                'numa_node': numa_node
                            })
                except:
                    pass
        except:
            pass
    
    def _parse_cpu_list(self, cpu_str):
        """Parse CPU list string like '0-15,128-143' into list of integers"""
        cpus = []
        for part in cpu_str.split(','):
            if '-' in part:
                start, end = map(int, part.split('-'))
                cpus.extend(range(start, end + 1))
            else:
                cpus.append(int(part))
        return sorted(cpus)


class CoreMaskGenerator:
    """Main class for generating core masks"""
    
    def __init__(self, topology: SystemTopology, max_pairs: int = 32):
        self.topology = topology
        self.max_pairs = max_pairs
        
        # CPU sets to be generated
        self.others_cpuset = []
        self.others_reserved = set()  # Track cores reserved for others_cpuset
        self.cat_cpuset = []
        self.cat_affine_cpuset = []
        self.nvmf_cpuset = []
        self.net_cpuset = []
        self.handler_cpuset = []
        self.redfs_cpuset = []
        self.reds3_cpuset = []
        self.reds3_sibling_cpuset = []
        self.posix_cpuset = []
        self.auxiliary_cpuset = []
        self.spdk_main_cpuset = []
        self.etcd_cpuset = []
        
        # Track used cores
        self.used_cores = set()
        
    def generate_masks(self):
        """Generate all core masks according to specifications"""
        # Step 1: Identify thread pairs and initialize others_cpuset
        self._initialize_others_cpuset()
        
        # Step 2: Allocate CAT cores
        self._allocate_cat_cores()
        
        # Step 3: Allocate network poller cores
        self._allocate_network_cores()
        
        # Step 4: Create handler cpuset
        self._create_handler_cpuset()
        
        # Step 5: Allocate redfs/reds3 cores
        self._allocate_storage_cores()
        
        # Step 6: Allocate special function cores
        self._allocate_special_cores()
        
    def _initialize_others_cpuset(self):
        """Initialize others_cpuset with second thread of first core from each NUMA (except core 0)"""
        # Based on the example:
        # "First we always ignore first thread pair on all cores, it can never be assigned to anybody.
        # This means 0,128 , 16,144 , 32,160,48,176,64,192,80,208,96,224,112,240 will not be used first
        # We ignore core 0 completely but put the rest of the cores into a others_cpuset variable"
        
        for numa_id, cpus in sorted(self.topology.numa_nodes.items()):
            if not cpus:
                continue
                
            # Assuming SMT/HT, split CPUs into two groups
            mid = len(cpus) // 2
            first_threads = cpus[:mid]
            second_threads = cpus[mid:]
            
            # Get first core of this NUMA
            if len(first_threads) > 0 and len(second_threads) > 0:
                first_core_t1 = first_threads[0]
                first_core_t2 = second_threads[0]
                
                if first_core_t1 == 0:
                    # This is core 0, skip it completely
                    self.used_cores.add(first_core_t1)
                    self.used_cores.add(first_core_t2)
                else:
                    # Add second thread of first core to others_cpuset
                    self.others_cpuset.append(first_core_t2)
        
        print(f"Initial others_cpuset: {sorted(self.others_cpuset)}")
        print(f"Initial others_cpuset has {len(self.others_cpuset)} cores available")
        
        # Reserve all others_cpuset cores so they won't be used elsewhere
        self.others_reserved = set(self.others_cpuset)
        
        # If we don't have enough cores in others_cpuset, we need to add more
        # We need at least 8 cores (2 posix + 1 auxiliary + 1 spdk_main + 4 etcd)
        min_required = 8
        if len(self.others_cpuset) < min_required:
            print(f"Warning: Only {len(self.others_cpuset)} cores in others_cpuset, need {min_required}")
            print("Adding additional cores from unused cores...")
            
            # Try to add more cores from first threads of unused pairs
            # Start from the last cores which are less likely to be needed
            for numa_id, cpus in sorted(self.topology.numa_nodes.items(), reverse=True):
                if len(self.others_cpuset) >= min_required:
                    break
                    
                mid = len(cpus) // 2
                first_threads = cpus[:mid]
                second_threads = cpus[mid:]
                
                # Try cores starting from the end
                for i in range(len(first_threads) - 1, 0, -1):  # Skip first core
                    if len(self.others_cpuset) >= min_required:
                        break
                        
                    t1 = first_threads[i]
                    t2 = second_threads[i]
                    
                    # Check if either thread is already reserved
                    if (t1 not in self.used_cores and t2 not in self.used_cores and 
                        t1 not in self.others_reserved and t2 not in self.others_reserved):
                        # Add first thread to others_cpuset and reserve both
                        self.others_cpuset.append(t1)
                        self.others_reserved.add(t1)
                        self.others_reserved.add(t2)  # Reserve the pair
                        print(f"Added core {t1} from NUMA {numa_id} to others_cpuset (reserving pair {t1},{t2})")
            
            print(f"Updated others_cpuset: {sorted(self.others_cpuset)}")
            print(f"Updated others_cpuset has {len(self.others_cpuset)} cores available")
    
    def _allocate_cat_cores(self):
        """Allocate cores for CAT devices"""
        # Group CATs by NUMA node
        cats_by_numa = defaultdict(list)
        for i, device in enumerate(self.topology.nvme_devices):
            cats_by_numa[device['numa_node']].append(f"Cat{i}: {device['name']}")
        
        # Check 1/3 core limit
        max_cat_cores = self.topology.total_cores // 3
        total_cats = len(self.topology.nvme_devices)
        
        if total_cats > max_cat_cores:
            print(f"Warning: {total_cats} CATs exceed 1/3 core limit ({max_cat_cores})")
        
        # Allocate cores for each NUMA domain
        for numa_id, cats in sorted(cats_by_numa.items()):
            cpus = self.topology.numa_nodes.get(numa_id, [])
            if not cpus:
                continue
                
            # Get thread pairs for this NUMA
            mid = len(cpus) // 2
            first_threads = cpus[:mid]
            second_threads = cpus[mid:]
            
            # Skip first pair and already used cores
            core_idx = 1  # Start from second core
            for cat in cats:
                while core_idx < len(first_threads):
                    t1 = first_threads[core_idx]
                    t2 = second_threads[core_idx]
                    
                    if (t1 not in self.used_cores and t2 not in self.used_cores and
                        t1 not in self.others_reserved and t2 not in self.others_reserved):
                        self.cat_cpuset.append(t1)
                        self.cat_affine_cpuset.append(t2)
                        self.used_cores.add(t1)
                        self.used_cores.add(t2)
                        break
                    
                    core_idx += 1
                
        # nvmf_cpuset equals cat_affine_cpuset
        self.nvmf_cpuset = self.cat_affine_cpuset.copy()
    
    def _allocate_network_cores(self):
        """Allocate cores for network pollers (2 per Mellanox adapter)"""
        for adapter in self.topology.mellanox_adapters:
            numa_id = adapter['numa_node']
            cpus = self.topology.numa_nodes.get(numa_id, [])
            if not cpus:
                continue
                
            # Get thread pairs for this NUMA
            mid = len(cpus) // 2
            first_threads = cpus[:mid]
            second_threads = cpus[mid:]
            
            # Allocate 2 pollers per adapter
            allocated = 0
            core_idx = 1  # Start from second core
            
            while allocated < 2 and core_idx < len(first_threads):
                t1 = first_threads[core_idx]
                t2 = second_threads[core_idx]
                
                if (t1 not in self.used_cores and t2 not in self.used_cores and
                    t1 not in self.others_reserved and t2 not in self.others_reserved):
                    # Use both threads of the pair for network polling
                    self.net_cpuset.extend([t1, t2])
                    self.used_cores.add(t1)
                    self.used_cores.add(t2)
                    allocated += 1
                
                core_idx += 1
    
    def _create_handler_cpuset(self):
        """Create handler cpuset from cat, cat_affine, and net cpusets"""
        self.handler_cpuset = sorted(set(
            self.cat_cpuset + self.cat_affine_cpuset + self.net_cpuset
        ))
    
    def _allocate_storage_cores(self):
        """Allocate cores for redfs and reds3"""
        # Create free pair list for each NUMA domain
        free_pairs_by_numa = defaultdict(list)
        
        for numa_id, cpus in sorted(self.topology.numa_nodes.items()):
            if not cpus:
                continue
                
            mid = len(cpus) // 2
            first_threads = cpus[:mid]
            second_threads = cpus[mid:]
            
            # Find free pairs (skip first pair)
            for i in range(1, len(first_threads)):
                t1 = first_threads[i]
                t2 = second_threads[i]
                
                if (t1 not in self.used_cores and t2 not in self.used_cores and
                    t1 not in self.others_reserved and t2 not in self.others_reserved):
                    free_pairs_by_numa[numa_id].append((t1, t2))
        
        # Balance pairs across NUMA domains
        allocated_pairs = []
        
        while len(allocated_pairs) < self.max_pairs:
            # Find NUMA domains with most free pairs
            numa_counts = [(numa, len(pairs)) for numa, pairs in free_pairs_by_numa.items() if pairs]
            if not numa_counts:
                break
                
            # Sort by number of free pairs (descending)
            numa_counts.sort(key=lambda x: x[1], reverse=True)
            
            # Take from NUMA domains with most pairs
            for numa_id, _ in numa_counts:
                if len(allocated_pairs) >= self.max_pairs:
                    break
                    
                if free_pairs_by_numa[numa_id]:
                    pair = free_pairs_by_numa[numa_id].pop(0)
                    allocated_pairs.append(pair)
                    self.used_cores.add(pair[0])
                    self.used_cores.add(pair[1])
        
        # Assign to redfs and reds3
        for t1, t2 in allocated_pairs:
            self.reds3_cpuset.append(t1)
            self.redfs_cpuset.append(t2)
            self.reds3_sibling_cpuset.append(f"{t1}:{t2}")
    
    def _allocate_special_cores(self):
        """Allocate cores for special functions from others_cpuset"""
        available_others = [c for c in self.others_cpuset if c not in self.used_cores]
        
        print(f"Available cores in others_cpuset for special functions: {len(available_others)}")
        
        # Allocate in order
        if len(available_others) >= 2:
            self.posix_cpuset = available_others[:2]
            available_others = available_others[2:]
            for c in self.posix_cpuset:
                self.used_cores.add(c)
        else:
            print("Warning: Not enough cores for posix_cpuset")
        
        if len(available_others) >= 1:
            self.auxiliary_cpuset = available_others[:1]
            available_others = available_others[1:]
            for c in self.auxiliary_cpuset:
                self.used_cores.add(c)
        else:
            print("Warning: Not enough cores for auxiliary_cpuset")
        
        if len(available_others) >= 1:
            self.spdk_main_cpuset = available_others[:1]
            available_others = available_others[1:]
            for c in self.spdk_main_cpuset:
                self.used_cores.add(c)
        else:
            print("Warning: Not enough cores for spdk_main_cpuset")
        
        if len(available_others) >= 4:
            self.etcd_cpuset = available_others[:4]
            available_others = available_others[4:]
            for c in self.etcd_cpuset:
                self.used_cores.add(c)
        else:
            print(f"Warning: Not enough cores for etcd_cpuset (need 4, have {len(available_others)})")
            if available_others:
                self.etcd_cpuset = available_others
                available_others = []
                for c in self.etcd_cpuset:
                    self.used_cores.add(c)
        
        # Update others_cpuset with remaining unused cores
        self.others_cpuset = available_others
    
    def print_results(self):
        """Print all generated CPU sets"""
        print("\n=== SYSTEM TOPOLOGY ===")
        print(f"Total cores: {self.topology.total_cores}")
        print(f"Total threads: {self.topology.total_threads}")
        print(f"NUMA nodes: {len(self.topology.numa_nodes)}")
        
        print("\n=== NUMA TOPOLOGY ===")
        for numa_id, cpus in sorted(self.topology.numa_nodes.items()):
            print(f"NUMA node{numa_id} CPU(s): {self._format_cpu_list(cpus)}")
        
        print("\n=== DEVICES ===")
        print(f"NVMe devices found: {len(self.topology.nvme_devices)}")
        for device in self.topology.nvme_devices:
            print(f"  {device['name']}: NUMA node {device['numa_node']}")
        
        print(f"\nMellanox adapters found: {len(self.topology.mellanox_adapters)}")
        for adapter in self.topology.mellanox_adapters:
            print(f"  PCI {adapter['pci']}: NUMA node {adapter['numa_node']}")
        
        print("\n=== GENERATED CPU SETS ===")
        print(f"cat_cpuset: {self._format_cpu_list(self.cat_cpuset)}")
        print(f"cat_affine_cpuset: {self._format_cpu_list(self.cat_affine_cpuset)}")
        print(f"nvmf_cpuset: {self._format_cpu_list(self.nvmf_cpuset)}")
        print(f"net_cpuset: {self._format_cpu_list(self.net_cpuset)}")
        print(f"handler_cpuset: {self._format_cpu_list(self.handler_cpuset)}")
        print(f"redfs_cpuset: {self._format_cpu_list(self.redfs_cpuset)}")
        print(f"reds3_cpuset: {self._format_cpu_list(self.reds3_cpuset)}")
        print(f"reds3_sibling_cpuset: {','.join(self.reds3_sibling_cpuset)}")
        print(f"posix_cpuset: {self._format_cpu_list(self.posix_cpuset)}")
        print(f"auxiliary_cpuset: {self._format_cpu_list(self.auxiliary_cpuset)}")
        print(f"spdk_main_cpuset: {self._format_cpu_list(self.spdk_main_cpuset)}")
        print(f"etcd_cpuset: {self._format_cpu_list(self.etcd_cpuset)}")
        print(f"others_cpuset (remaining): {self._format_cpu_list(self.others_cpuset)}")
    
    def export_json(self, filename):
        """Export results to JSON file"""
        results = {
            'topology': {
                'total_cores': self.topology.total_cores,
                'total_threads': self.topology.total_threads,
                'numa_nodes': {str(k): v for k, v in self.topology.numa_nodes.items()},
                'nvme_devices': self.topology.nvme_devices,
                'mellanox_adapters': self.topology.mellanox_adapters
            },
            'cpu_sets': {
                'cat_cpuset': self.cat_cpuset,
                'cat_affine_cpuset': self.cat_affine_cpuset,
                'nvmf_cpuset': self.nvmf_cpuset,
                'net_cpuset': self.net_cpuset,
                'handler_cpuset': self.handler_cpuset,
                'redfs_cpuset': self.redfs_cpuset,
                'reds3_cpuset': self.reds3_cpuset,
                'reds3_sibling_cpuset': self.reds3_sibling_cpuset,
                'posix_cpuset': self.posix_cpuset,
                'auxiliary_cpuset': self.auxiliary_cpuset,
                'spdk_main_cpuset': self.spdk_main_cpuset,
                'etcd_cpuset': self.etcd_cpuset,
                'others_cpuset': self.others_cpuset
            }
        }
        
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"\nResults exported to {filename}")
    
    def _format_cpu_list(self, cpus):
        """Format CPU list for display"""
        if not cpus:
            return ""
        
        # Group consecutive CPUs
        result = []
        i = 0
        while i < len(cpus):
            start = cpus[i]
            end = start
            
            while i + 1 < len(cpus) and cpus[i + 1] == cpus[i] + 1:
                i += 1
                end = cpus[i]
            
            if start == end:
                result.append(str(start))
            else:
                result.append(f"{start}-{end}")
            
            i += 1
        
        return ",".join(result)


def main():
    parser = argparse.ArgumentParser(
        description='Generate core masks for high-performance storage systems'
    )
    parser.add_argument(
        '--max-pairs', 
        type=int, 
        default=32,
        help='Maximum number of thread pairs for storage (default: 32)'
    )
    parser.add_argument(
        '--export-json',
        type=str,
        help='Export results to JSON file'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    
    args = parser.parse_args()
    
    # Check if running as root (might be needed for some /sys access)
    if not args.dry_run and os.geteuid() != 0:
        print("Warning: Running without root privileges. Some information may be unavailable.")
    
    # Parse system topology
    print("Parsing system topology...")
    topology = SystemTopology()
    topology.parse_lscpu()
    topology.parse_lstopo()
    
    # Check minimum requirements
    if topology.total_cores < 32:
        print(f"Error: System has only {topology.total_cores} cores. Minimum 32 cores required.")
        sys.exit(1)
    
    # Generate core masks
    print("Generating core masks...")
    generator = CoreMaskGenerator(topology, args.max_pairs)
    generator.generate_masks()
    
    # Display results
    generator.print_results()
    
    # Export if requested
    if args.export_json:
        generator.export_json(args.export_json)


if __name__ == "__main__":
    import os
    main()
