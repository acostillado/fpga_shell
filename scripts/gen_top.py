#!/usr/bin/env python3
import os
import re
import csv
import argparse
from jinja2 import Environment, FileSystemLoader

def parse_system_ports(system_file):
    """ Parses interfaces/system.sv or similar to extract port definitions """
    ports = []
    if not os.path.exists(system_file):
        return ports
        
    with open(system_file, 'r') as f:
        # Simple extraction looking for input/output
        for line in f:
            line = line.split('//')[0].strip()
            match = re.match(r'(input|output|inout)\s+(wire|reg)?\s*(\[[^\]]+\])?\s*([a-zA-Z0-9_]+)', line)
            if match:
                ports.append({
                    'direction': match.group(1),
                    'width_expr': match.group(3) if match.group(3) else '',
                    'name': match.group(4)
                })
    return ports

def parse_ea_module(ea_file):
    """
    Replicates the parse_module TCL procedure.
    Extracts the module name and its ports, converting them to wire declarations.
    """
    module_name = "ea_demo"
    ports = []
    
    if not os.path.exists(ea_file):
        print(f"Warning: EA file {ea_file} not found.")
        return module_name, ports

    with open(ea_file, 'r') as f:
        in_module = False
        for line in f:
            line_stripped = line.split('//')[0].strip()
            if not line_stripped:
                continue
                
            if not in_module:
                m = re.match(r'module\s+([a-zA-Z0-9_]+)', line_stripped)
                if m:
                    module_name = m.group(1)
                    in_module = True
            else:
                if re.match(r'^\s*endmodule\b', line_stripped):
                    break
                
                # Match port definitions e.g., input [31:0] my_sig,
                match = re.match(r'(input|output|inout)\s+(wire|reg)?\s*(\[[^\]]+\])?\s*([a-zA-Z0-9_]+)', line_stripped)
                if match:
                    ports.append({
                        'width_expr': match.group(3) if match.group(3) else '',
                        'name': match.group(4)
                    })
                    
    return module_name, ports

def parse_accelerator_def(csv_path):
    """ Parses accelerator_def.csv to detect features """
    config = {
        'pcie': False,
        'hbm_used': False
        # Add others as needed depending on the parsed keys
    }
    
    if not os.path.exists(csv_path):
        return config
        
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            if not row or row[0].startswith('#'):
                continue
            intf_type = row[0].strip().upper()
            if "PCIE" in intf_type:
                config['pcie'] = {'rx_lanes': 16, 'tx_lanes': 16} # Hardcoded for now based on system_top.sv
            if "HBM" in intf_type:
                config['hbm_used'] = True
    return config

def main():
    parser = argparse.ArgumentParser(description="Generate system_top.sv via Jinja2")
    parser.add_argument('--accel_dir', required=True, help="Path to accelerator directory")
    parser.add_argument('--shell_dir', required=True, help="Path to fpga_shell root")
    parser.add_argument('--out_file', required=True, help="Output file path (system_top.sv)")
    args = parser.parse_args()

    # 1. Parse EA Module
    ea_mod_file = os.path.join(args.accel_dir, "meep_shell", "accelerator_mod.sv")
    ea_name, ea_ports = parse_ea_module(ea_mod_file)

    # 2. Parse EA Definition CSV
    csv_file = os.path.join(args.accel_dir, "accelerator_def.csv")
    sys_config = parse_accelerator_def(csv_file)

    # 3. Gather interfaces enabled (Dynamic Ports)
    # The pure TCL implementation parsed system.sv, pcie.sv, ddr4.sv etc.
    # For now, we will simulate this by parsing all files in interfaces/ based on csv features.
    dynamic_ports = []
    intf_dir = os.path.join(args.shell_dir, "interfaces")
    files_to_parse = ["system.sv"]
    if sys_config['pcie']:
        # The Jinja template handles standard PCIe explicitly, but if there's an interface file:
        if os.path.exists(os.path.join(intf_dir, "pcie.sv")):
            files_to_parse.append("pcie.sv")
    # ... more logic for DDR4, Ethernet based on parsing accelerator_def
    
    for f in files_to_parse:
        full_path = os.path.join(intf_dir, f)
        dynamic_ports.extend(parse_system_ports(full_path))

    # 4. Generate with Jinja2
    template_dir = os.path.join(args.shell_dir, "templates")
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template("system_top.sv.j2")
    
    # We will pass the exact shell ports we have (from EA properties and others)
    shell_ports = ea_ports # EA ports wire exactly to Shell Instance

    rendered = template.render(
        pcie=sys_config['pcie'],
        hbm_used=sys_config['hbm_used'],
        dynamic_ports=dynamic_ports,
        ea_wires=ea_ports,
        ea_module_name=ea_name,
        ea_ports=ea_ports,
        shell_ports=shell_ports
    )

    os.makedirs(os.path.dirname(args.out_file), exist_ok=True)
    with open(args.out_file, 'w') as f:
        f.write(rendered)
        
    print(f"Generated {args.out_file} successfully.")

if __name__ == "__main__":
    main()
