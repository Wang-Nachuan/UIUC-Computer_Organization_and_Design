/* MODIFY. Your cache design. It contains the cache
controller, cache datapath, and bus adapter. */



module l2_d_cache 
import l2_d_cache_types::*;
import rv32i_types::*;
(
    input clk,
    input rst,

    // From CPU
    input logic mem_read,
    input logic mem_write,
    //input logic [3:0] mem_byte_enable,
    input rv32i_word mem_address,
    input [input_size-1:0] mem_wdata,
    // To CPU
    output logic mem_resp,
    output [input_size-1:0] mem_rdata,

    // FROM lower memory
    input logic [size-1:0] dcache_pmem_rdata,
    input logic dcache_pmem_resp,
    // TO lower memory
    output logic hold_arbiter,
    output logic [size-1:0] dcache_pmem_wdata,
    output logic [31:0] dcache_pmem_address,
    output logic dcache_pmem_read,
    output logic dcache_pmem_write
);

// cache datapath to cache control
logic hit;
logic [num_ways-1:0] dirty_out;
logic [width-1:0] evicting_way;

// cache control to cache datapath 
logic load;
logic valid;
logic dirty;
logic load_lru;
logic write_back_busy;
d_write_data_selection write_data_selection_t;
d_address_selection d_address_selection_t;
d_write_enable_selection write_en_selection_t;

// bus adapter to cache datapath
logic [s_line-1:0] mem_wdata256;
logic [s_mask-1:0] mem_byte_enable256;

// cache datapath to bus adapter
logic [s_line-1:0] mem_rdata256;
logic [31:0] mem_address_loaded;

// cache control to Write back buffer
logic load_buffer;


l2_cache_control control (
    .*,
    // Input from lower memory
    .pmem_resp_i(dcache_pmem_resp),
    // Output to lower memory
    .pmem_read_t(dcache_pmem_read),
    .pmem_write_t(dcache_pmem_write)
);

l2_cache_datapath datapath (
    .*,
    // Input from lower memory
    .pmem_data_in(dcache_pmem_rdata),
    // Output to lower memory
    .pmem_data_t(dcache_pmem_wdata),
    .pmem_address_t(dcache_pmem_address),
    .valid_in(valid),
    .dirty_in(dirty),
    .hit_output(hit)

);

l2_bus_adapter #(.s_offset(s_offset), .input_size(input_size)) l2_bus_adapter (
    .mem_wdata256(mem_wdata256),
    .mem_rdata256(mem_rdata256),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_byte_enable256(mem_byte_enable256)
    //.address(mem_address_loaded),
    //.addresss_from_cpu(mem_address)
);

endmodule : l2_d_cache

