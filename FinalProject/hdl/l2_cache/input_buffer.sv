module l2_input_buffer #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index, 
    parameter s_mask   = 2**s_offset, 
    parameter s_line   = 8*s_mask 
)
(
    input clk,
    input rst,
    input logic load_input_buffer,
    input logic [31:0] mem_address_in,
    output logic [31:0] mem_address_loaded,
    input logic [s_line-1:0] mem_rdata256_in,
    output logic [s_line-1:0] mem_rdata256,
    input logic [s_line-1:0] mem_wdata256,
    output logic [s_line-1:0] mem_wdata256_out,
    input logic [s_mask-1:0] mem_byte_enable256,
    output logic [s_mask-1:0] mem_byte_enable256_out
);

    assign mem_rdata256 = mem_rdata256_in;
    always_ff @ (posedge clk, posedge rst) begin
        if (rst) begin
            mem_address_loaded <= '0;
            mem_wdata256_out <= '0;
            mem_byte_enable256_out <= '0;
        end
        else if (load_input_buffer) begin
            mem_address_loaded <= mem_address_in;
            mem_wdata256_out <= mem_wdata256;
            mem_byte_enable256_out <= mem_byte_enable256;
        end
    end

endmodule
