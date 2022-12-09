//CPU <-> i_cache


module i_bus_adapter #(
    parameter i_input_size = 64,
    parameter i_s_offset = 5,
    parameter i_size = (2**i_s_offset)*8 
)
(

    input [i_size-1:0] mem_rdata256,
    output [i_input_size-1:0] mem_rdata,
    input [31:0] address

);


assign mem_rdata = i_input_size == 64 ? mem_rdata256[(64*address[i_s_offset-1:3]) +: 64] : mem_rdata;


endmodule : i_bus_adapter
