// CPU <-> dcache  input_size is 32
//L1 cache <-> L2 cache input_size is 256
module bus_adapter #(
    parameter input_size = 32,
    parameter s_offset = 5,
    parameter size = (2**s_offset)*8
)
(
    output [size-1:0] mem_wdata256,
    input [size-1:0] mem_rdata256,
    input [input_size-1:0] mem_wdata,
    output [input_size-1:0] mem_rdata,
    input [3:0] mem_byte_enable,
    output logic [(2**s_offset-1):0] mem_byte_enable256,
    input [31:0] address,
    input [31:0] addresss_from_cpu
);
localparam num_sets = 2**(s_offset-2);
logic [(2**s_offset-5):0] zeros = '0;


assign mem_wdata256 = input_size == 32 ? {num_sets{mem_wdata}} : mem_wdata;
assign mem_rdata = input_size == 32 ? mem_rdata256[(32*address[s_offset-1:2]) +: 32] : mem_rdata;
assign mem_byte_enable256 = input_size == 32 ? ({zeros, mem_byte_enable} << (addresss_from_cpu[s_offset-1:2]*4)) : 32'hFFFFFFFF;

endmodule : bus_adapter
