/* MODIFY. Your cache design. It contains the cache
controller, cache datapath, and bus adapter. */

module cache #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index,
    parameter s_mask   = 2**s_offset,
    parameter s_line   = 8*s_mask,
    parameter num_sets = 2**s_index,
    parameter asso = 2,         // Associative
    parameter asso_log = 1      // Log associative
)
(
    input clk,
    input rst,

    /* CPU memory signals */
    input   logic [31:0]    mem_address,
    output  logic [31:0]    mem_rdata,
    input   logic [31:0]    mem_wdata,
    input   logic           mem_read,
    input   logic           mem_write,
    input   logic [3:0]     mem_byte_enable,
    output  logic           mem_resp,

    /* Physical memory signals */
    output  logic [31:0]    pmem_address,
    input   logic [255:0]   pmem_rdata,
    output  logic [255:0]   pmem_wdata,
    output  logic           pmem_read,
    output  logic           pmem_write,
    input   logic           pmem_resp
);


/*--------------------Internal Signals--------------------*/

/* From/To controller */
// Valid
logic [asso-1:0] ld_valid, valid_in;
// Dirty
logic [asso-1:0] ld_dirty, dirty_in, dirty_out;
// Tage
logic [asso-1:0] ld_tag;
// Data
logic datainmux_sel;
logic [asso_log-1:0] dataoutmux_sel;
logic [asso-1:0][1:0] datamaskmux_sel;
// LRU
logic ld_lru, lru_in, lru_out;
// Other
logic ld_data_writeback;
logic ld_addr_writeback;
logic is_hit;
logic is_full;
logic [asso-1:0] is_way_hit;
logic paddrmux_sel;

/* From/To bus adapter */ 
logic [255:0] mem_wdata256;
logic [255:0] mem_rdata256;
logic [31:0] mem_byte_enable256;

/*-------------------------Modules-------------------------*/

cache_control #(
    .asso(asso),
    .asso_log(asso_log)
) control (.*);

cache_datapath #(
    .s_offset(s_offset),
    .s_index(s_index),
    .s_tag(s_tag),
    .s_mask(s_mask),
    .s_line(s_line),
    .num_sets(num_sets),
    .asso(asso),
    .asso_log(asso_log)
) datapath (.*);

bus_adapter bus_adapter (.address(mem_address), .*);

endmodule : cache
