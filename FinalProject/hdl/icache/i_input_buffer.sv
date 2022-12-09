
module i_input_buffer #(
    parameter i_s_offset = 5,
    parameter i_s_index  = 3,
    parameter i_s_tag    = 32 - i_s_offset - i_s_index, 
    parameter i_s_mask   = 2**i_s_offset,
    parameter i_s_line   = 8*i_s_mask 
)
(
    input clk,
    input rst,
    input logic load_input_buffer,
    input logic [31:0] mem_address_in,
    output logic [31:0] mem_address_loaded,
    input logic [i_s_line-1:0] mem_rdata256_in,
    output logic [i_s_line-1:0] mem_rdata256

);

    assign mem_rdata256 = mem_rdata256_in;
    always_ff @ (posedge clk, posedge rst) begin
        if (rst) begin
            mem_address_loaded <= '0;

        end
        else if (load_input_buffer) begin
            mem_address_loaded <= mem_address_in;

        end
    end

endmodule
