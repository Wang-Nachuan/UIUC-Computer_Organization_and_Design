module write_back_buffer #(
    parameter s_offset = 5,
    parameter s_index  = 3,
    parameter s_tag    = 32 - s_offset - s_index, 
    parameter s_mask   = 2**s_offset, 
    parameter s_line   = 8*s_mask 
)
(
    input clk,
    input rst,
    input logic load_buffer,
    input logic [s_line-1:0] evict_data_in,
    output logic [s_line-1:0] evict_data_out,
    input logic [31:0] write_back_addr_in,
    output logic [31:0] write_back_addr_out
);

    always_ff @ (posedge clk, posedge rst) begin
        if (rst) begin
            evict_data_out <= '0;

        end
        else if (load_buffer) begin

            evict_data_out <= evict_data_in;
            write_back_addr_out <= write_back_addr_in;
        end
    end

endmodule

