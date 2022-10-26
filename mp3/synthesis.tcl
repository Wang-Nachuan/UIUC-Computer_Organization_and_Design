set target_library [getenv STD_CELL_LIB]
set synthetic_library [list dw_foundation.sldb]
set link_library   [list "*" $target_library $synthetic_library]
set symbol_library [list generic.sdb]

set design_clock_pin clk
set design_reset_pin rst

suppress_message LINT-31
suppress_message LINT-52
suppress_message LINT-28
suppress_message LINT-29
suppress_message LINT-32
suppress_message LINT-33
suppress_message LINT-28
suppress_message LINT-1
suppress_message LINT-99

set hdlin_check_no_latch true

set modules [glob -nocomplain ../pkg/*.sv]
foreach module $modules {
    puts "analyzing $module"
    analyze -library WORK -format sverilog "${module}"
}

set modules [glob -nocomplain ../hdl/cpu/*.sv]
foreach module $modules {
    puts "analyzing $module"
    analyze -library WORK -format sverilog "${module}"
}

set modules [glob -nocomplain ../hdl/cache/*.sv]
foreach module $modules {
    puts "analyzing $module"
    analyze -library WORK -format sverilog "${module}"
}

set modules [glob -nocomplain ../hdl/*.sv]
foreach module $modules {
    puts "analyzing $module"
    analyze -library WORK -format sverilog "${module}"
}

elaborate mp3
current_design mp3
check_design

set clk_name $design_clock_pin
create_clock -period 10 -name my_clk $clk_name
set_dont_touch_network [get_clocks my_clk]
set_fix_hold [get_clocks my_clk]
set_clock_uncertainty 0.1 [get_clocks my_clk]
set_ideal_network [get_ports clk]

set_input_delay 1 [all_inputs] -clock my_clk
set_output_delay 1 [all_outputs] -clock my_clk
set_load 0.1 [all_outputs]
set_max_fanout 1 [all_inputs]
set_fanout_load 8 [all_outputs]

link
compile

current_design mp3

report_area -hier > reports/area.rpt
report_timing > reports/timing.rpt
check_design > reports/check.rpt

write_file -format ddc -output synth.ddc
exit