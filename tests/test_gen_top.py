import os
import tempfile
import pytest
from scripts.gen_top import parse_system_ports, parse_ea_module, parse_accelerator_def

# Simple parametrization testing for regex extraction
@pytest.mark.parametrize("file_content, expected_ports", [
    (
        "module ea_demo(\n  input wire [31:0] sys_clk,\n  output reg [7:0] led\n);\nendmodule",
        [{'width_expr': '[31:0]', 'name': 'sys_clk'}, {'width_expr': '[7:0]', 'name': 'led'}]
    ),
    (
        "module complex_ea(\n  input rst_n,\n  inout [15:0] data_bus\n);\nendmodule",
        [{'width_expr': '', 'name': 'rst_n'}, {'width_expr': '[15:0]', 'name': 'data_bus'}]
    )
])
def test_parse_ea_module(file_content, expected_ports):
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tf:
        tf.write(file_content)
        temp_path = tf.name
        
    try:
        module_name, ports = parse_ea_module(temp_path)
        assert len(ports) == len(expected_ports)
        for i, p in enumerate(expected_ports):
            assert ports[i]['name'] == p['name']
            assert ports[i]['width_expr'] == p['width_expr']
    finally:
        os.remove(temp_path)


@pytest.mark.parametrize("csv_content, expected_config", [
    (
        "PCIE, yes, x16\nHBM, yes, 8GB\n",
        {'pcie': {'rx_lanes': 16, 'tx_lanes': 16}, 'hbm_used': True}
    ),
    (
        "# Comment\nETHERNET, no\n",
        {'pcie': False, 'hbm_used': False}
    )
])
def test_parse_accelerator_def(csv_content, expected_config):
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tf:
        tf.write(csv_content)
        temp_path = tf.name
        
    try:
        config = parse_accelerator_def(temp_path)
        assert config['pcie'] == expected_config['pcie']
        assert config['hbm_used'] == expected_config['hbm_used']
    finally:
        os.remove(temp_path)


# Negative Tests
from scripts.gen_top import ParserError

def test_missing_files_raise_errors():
    with pytest.raises(FileNotFoundError):
        parse_ea_module("/path/to/nonexistent/ea.sv")
        
    with pytest.raises(FileNotFoundError):
        parse_accelerator_def("/path/to/nonexistent/def.csv")

def test_malformed_ea_module_raises_error():
    # File missing both 'module' and 'endmodule' keywords entirely
    malformed_sv = "input wire clk;\n// missing declaration\n"
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tf:
        tf.write(malformed_sv)
        temp_path = tf.name
        
    try:
        with pytest.raises(ParserError, match="does not contain complete module"):
            parse_ea_module(temp_path)
    finally:
        os.remove(temp_path)
        
def test_ea_module_missing_name_raises_error():
    # File has keywords but regex fails to extract a name
    malformed_sv = "module  \ninput wire clk;\nendmodule"
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tf:
        tf.write(malformed_sv)
        temp_path = tf.name
        
    try:
        with pytest.raises(ParserError, match="Could not extract module name"):
            parse_ea_module(temp_path)
    finally:
        os.remove(temp_path)

def test_malformed_csv_raises_error():
    malformed_csv = "JUST_A_STRING_NO_COMMAS\n"
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tf:
        tf.write(malformed_csv)
        temp_path = tf.name
        
    try:
        with pytest.raises(ValueError, match="Malformed row in CSV"):
            parse_accelerator_def(temp_path)
    finally:
        os.remove(temp_path)
