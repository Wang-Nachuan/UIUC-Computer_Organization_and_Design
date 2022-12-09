module i_cache 
import i_cache_types::*;
import rv32i_types::*;
(
    input clk,
    input rst,

    // From CPU
    input logic mem_read,


    input rv32i_word mem_address,

    // To CPU
    output logic mem_resp,
    output [i_input_size-1:0] mem_rdata,

    input logic [i_size-1:0] icache_pmem_rdata,
    input logic icache_pmem_resp,

    output logic [31:0] icache_pmem_address,
    output logic icache_pmem_read

);

logic hit;

logic [i_width-1:0] evicting_way;

i_write_data_selection write_data_selection_t;
logic load;
i_write_enable_selection write_en_selection_t;
logic valid;
// logic dirty;
logic load_lru;
i_address_selection address_selection_t;


// Datapath to Bus Adapter
logic [i_s_line-1:0] mem_rdata256;
logic [31:0] mem_address_loaded;


i_cache_control control (
    .*,
    // Input from lower memory
    .pmem_resp_i(icache_pmem_resp),
    // Output to lower memory
    .pmem_read_t(icache_pmem_read)

);

i_cache_datapath datapath (
    .*,
    // Input from lower memory
    .pmem_data_in(icache_pmem_rdata),
    // Output to lower memory

    .pmem_address_t(icache_pmem_address),
    .valid_in(valid),

    .hit_output(hit),
    .evicting_way()

);

i_bus_adapter #(.i_s_offset(i_s_offset), .i_input_size(i_input_size)) bus_adapter (
    .*,
    .address(mem_address_loaded)

);

endmodule : i_cache
