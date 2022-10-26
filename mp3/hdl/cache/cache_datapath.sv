/* MODIFY. The cache datapath. It contains the data,
valid, dirty, tag, and LRU arrays, comparators, muxes,
logic gates and other supporting logic. */

module cache_datapath #(
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

    /* From/To controller */
    // Valid
    input   logic [asso-1:0]    ld_valid,
    input   logic [asso-1:0]    valid_in,
    // output  logic [asso-1:0]    valid_out,
    // Dirty
    input   logic [asso-1:0]    ld_dirty,
    input   logic [asso-1:0]    dirty_in,
    output  logic [asso-1:0]    dirty_out,
    // Tage
    input   logic [asso-1:0]    ld_tag,
    // Data
    input   logic               datainmux_sel,
    input   logic [asso_log-1:0]    dataoutmux_sel,
    input   logic [asso-1:0][1:0]   datamaskmux_sel,
    // LRU
    input   logic               ld_lru,
    input   logic               lru_in,
    output  logic               lru_out,
    // Other
    input   logic               ld_data_writeback,
    input   logic               ld_addr_writeback,
    output  logic               is_hit,
    output  logic               is_full,
    output  logic[asso-1:0]     is_way_hit,
    input   logic               paddrmux_sel,

    /* From/To bus adapter */ 
    input   logic [255:0]       mem_wdata256,
    input   logic [31:0]        mem_address,
    input   logic [31:0]        mem_byte_enable256,
    output  logic [255:0]       mem_rdata256,

    /* From/TO memory */ 
    input   logic [255:0]       pmem_rdata,
    output  logic [255:0]       pmem_wdata,
    output  logic [31:0]        pmem_address

);

/*--------------------Internal Signals--------------------*/

// Decode address
logic [s_index-1:0] index;
logic [31 - s_offset - s_index:0] tag;

// Valid
logic [asso-1:0] valid_out_i; 

// Tage
logic [asso-1:0][31 - s_offset - s_index:0] tag_out_i;

// Data
logic [255:0] data_in;
logic [255:0] data_out;
logic [asso-1:0][255:0] data_out_set;
logic [255:0] data_writeback;
logic [31:0]  addr_write_back;
logic [asso-1:0][31:0] data_mask;

// Tag compare
logic [asso-1:0] is_tag_equal;
logic [asso-1:0] is_way_hit_i;

// LRU
logic lru_out_i;

/*---------------------Internal Logic---------------------*/

assign index = mem_address[s_offset+s_index-1:s_offset];
assign tag = mem_address[31:s_offset+s_index];

// assign valid_out = valid_out_i;

// LRU
assign lru_out = lru_out_i;

// Data in mux
assign data_in = (datainmux_sel) ? mem_wdata256 : pmem_rdata;

// Data out mux
assign data_out = data_out_set[dataoutmux_sel];
assign mem_rdata256 = data_out;
assign pmem_wdata = data_writeback;

always_ff @(posedge clk) begin
    if (ld_data_writeback)
        data_writeback <= data_out;
    else
        data_writeback <= data_writeback;

    if (ld_addr_writeback)
        addr_write_back <= {tag_out_i[lru_out_i], index, {s_offset{1'b0}}};
    else
        addr_write_back <= addr_write_back;
end

// Tag compare
integer n;
always_comb begin
    for (n = 0; n < asso; n++)
        is_tag_equal[n] = (tag == tag_out_i[n]) ? 1'b1 : 1'b0;
    is_way_hit_i = is_tag_equal & valid_out_i;
    // Output
    is_way_hit = is_way_hit_i;
    is_hit = | is_way_hit_i;
    // is_full = & tag_out_i;   // ?
    is_full = & valid_out_i;
end

// Address to main memory (0 for read/write miss, 1 for write back)
assign pmem_address = (paddrmux_sel) ? addr_write_back : {mem_address[31:s_offset], {s_offset{1'b0}}};

/*-------------------------Modules-------------------------*/
genvar i;    
generate
for (i = 0; i < asso; i++) begin
    // Valid
    array #(
        .s_index(s_index),
        .width(1)
    ) valid_array (
        .clk,
        .rst,
        .read(1'b1),
        .load(ld_valid[i]),
        .rindex(index),
        .windex(index),
        .datain(valid_in[i]),
        .dataout(valid_out_i[i])
    );

    // Dirty
    array #(
        .s_index(s_index),
        .width(1)
    ) dirty_array (
        .clk,
        .rst,
        .read(1'b1),
        .load(ld_dirty[i]),
        .rindex(index),
        .windex(index),
        .datain(dirty_in[i]),
        .dataout(dirty_out[i])
    );

    // Tag
    array #(
        .s_index(s_index),
        .width(s_tag)
    ) tag_array (
        .clk,
        .rst,
        .read(1'b1),
        .load(ld_tag[i]),
        .rindex(index),
        .windex(index),
        .datain(tag),
        .dataout(tag_out_i[i])
    );

    // Data
    data_array #(
        .s_offset(s_offset),
        .s_index(s_index)
    ) data_array (
        .clk,
        .read(1'b1),
        .write_en(data_mask[i]),
        .rindex(index),
        .windex(index),
        .datain(data_in),
        .dataout(data_out_set[i])
    );

    // Data mask mux
    always_comb begin
        case (datamaskmux_sel[i])
            2'b00: data_mask[i] = 32'h00000000;    // Disable
            2'b01: data_mask[i] = 32'hffffffff;    // Enable memory write
            2'b10: data_mask[i] = mem_byte_enable256;      // Enable cpu write
            default: data_mask[i] = 32'h00000000;
        endcase
    end
end
endgenerate

// LRU (needs to be updated manually)
array #(
    .s_index(s_index),
    .width(1)
) lru_array (
    .clk,
    .rst,
    .read(1'b1),
    .load(ld_lru),
    .rindex(index),
    .windex(index),
    .datain(lru_in),
    .dataout(lru_out_i)
);


endmodule : cache_datapath
