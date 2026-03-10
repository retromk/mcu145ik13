# Vitis HLS template for MK-61 HLS core.
# Run: vitis_hls -f hls/vitis_hls.tcl

set proj_name mk61_hls_prj
set sol_name sol1
set part_name xc7a200tfbg484-2
set clk_period 10.0

open_project -reset $proj_name
set_top mk61_top_hls_step

add_files hls/mk61_hls.cpp -cflags "-std=c++17 -Ihls"
add_files hls/mk61_hls.hpp
add_files hls/rom_tables.hpp
add_files -tb hls/tb_mk61_hls.cpp -cflags "-std=c++17 -Ihls"

open_solution -reset $sol_name
set_part $part_name
create_clock -period $clk_period -name default

csim_design -argv "--cycles 20000 --mode 0"
csynth_design
export_design -format ip_catalog

exit
