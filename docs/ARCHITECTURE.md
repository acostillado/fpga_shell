# MEEP FPGA Shell Architecture

## Introduction

The MEEP FPGA Shell utilizes a data-driven compiler pipeline to dynamically generate the top-level SystemVerilog (`system_top.sv`) Block Design wrapper. This architecture represents a modernization from legacy TCL string-concatenation methods, prioritizing robustness, testability, and developer ergonomics.

## Data-Driven Compiler Pipeline

The shell generation process operates entirely in Python, utilizing an Abstract Syntax Tree (AST) compilation strategy powered by Jinja2 templates.

The pipeline comprises four sequential stages:

1. **Definition Parsing (`accelerator_def.csv`)**: The entry point is the CSV definition file. The shell reads this file to ascertain which Intellectual Property (IP) cores are requested by the Emulated Accelerator (EA), such as PCIe, HBM, or Ethernet.
2. **Module Inspection (`accelerator_mod.sv`)**: The Python generator (`scripts/gen_top.py`) parses the EA's system wrapper to dynamically extract the exact port signatures (names, widths, and directions) required by the target accelerator.
3. **Context Construction (Python Dictionary)**: The parsed configuration flags (from step 1) and the dynamically discovered port geometries (from step 2) are aggregated into a massive context dictionary.
4. **Jinja2 AST Rendering (`system_top.sv.j2`)**: The context dictionary is passed into the Jinja2 templating engine, which evaluates conditional logic (e.g., `{% if pcie %}...{% endif %}`) and loops to render the final `src/system_top.sv` file.

## The `accelerator_def.csv` Schema

The `accelerator_def.csv` is the declarative truth for the entire generation process.

### Interface Extension Process

To request an interface in the Shell, developers must ensure the following format on a newline:

```csv
INTERFACE_TYPE, yes_or_no, mapping_type, channels, clk_domain, rst_domain, [optional metadata]
```

**Example (PCIe):**
```csv
PCIE,yes,pcie_axi,1,PCIE_CLK,pcie_clk,pcie_rstn,dma,0
```
- `PCIE`: The interface type identifier. The Python parser looks for this string.
- `yes`: The boolean toggle to engage the module. Set to `no` to gracefully exclude the IP without deleting the structural row.

## Jinja2 Context Mapping

The core of the RTL generation logic sits inside `templates/system_top.sv.j2`.

When extending the Shell to support a newly defined interface in `accelerator_def.csv`, developers must execute a two-step context mapping:

### 1. Exposing New Capabilities in Python

Modify `scripts/gen_top.py` to extract your new feature and pass it to the Jinja2 `template.render()` dictionary:

```python
# Parse the config
config['my_new_ip_enabled'] = "MY_NEW_IP" in intf_type and "yes" in ...

# Pass to Jinja context
rendered = template.render(
    pcie=sys_config['pcie'],
    hbm_used=sys_config['hbm_used'],
    my_new_ip_enabled=sys_config['my_new_ip_enabled'], # <--- New Context Map
    # ...
)
```

### 2. Consuming Context in Jinja2

Leverage the injected config within `templates/system_top.sv.j2` using Jinja2 AST control flow blocks:

```jinja2
{% if my_new_ip_enabled %}
  // SystemVerilog structural instantiation logic for the new IP goes here
  my_new_ip_core #(
    .DATA_WIDTH (512)
  ) core_inst (
    .clk (sys_clk),
    .rst_n (sys_rst_n)
  );
{% endif %}
```

By decoupling the high-level configuration definition (`.csv`), the extraction and routing logic (`.py`), and the Verilog structural semantics (`.j2`), the MEEP FPGA Shell architecture remains maximally extensible while avoiding string-escaping vulnerabilities common in TCL-only workflows.
