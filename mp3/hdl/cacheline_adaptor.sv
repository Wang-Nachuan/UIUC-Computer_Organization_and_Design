module cacheline_adaptor
(
    input logic clk,
    input logic reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input logic read_i,
    input logic write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input logic resp_i
);

reg [2:0] cnt;
reg [255:0] buff;

assign address_o = address_i; 
assign line_o = buff;

enum int unsigned {
    idle,
    read_burst,
    read_finish,
    write_burst,
    write_finish
} curr_s, next_s;


// FSM
always_ff @(posedge clk) begin
    if (reset_n)
        curr_s <= idle;
    else 
        curr_s <= next_s;
end

always_comb begin
    next_s = curr_s;
    case (curr_s)
        idle:
            if (read_i)
                next_s = read_burst;
            else if (write_i)
                next_s = write_burst;
        read_burst:
            if (cnt == 4)
                next_s = read_finish;
        read_finish: next_s = idle;
        write_burst:
            if (cnt == 3 && resp_i)
                next_s = write_finish; 
        write_finish: next_s = idle;
    endcase
end

always_comb begin
    // State output
    resp_o = 1'b0;
    read_o = 1'b0;
    write_o = 1'b0;
    burst_o = 64'b0;
    case (curr_s)
        read_burst:begin
            if (cnt < 4)
                read_o = 1'b1;
            else
                read_o = 1'b0;
        end
        read_finish: resp_o = 1'b1;
        write_burst:begin
            write_o = 1'b1;
            burst_o = line_i[64*cnt +: 64];
        end
        write_finish: resp_o = 1'b1;
    endcase
end


// Update buffer
always_ff @ (posedge clk) begin
    if (reset_n) begin
        buff <= 256'b0;
    end
    else if (curr_s == read_burst || curr_s == read_finish) begin
        buff[64*cnt +: 64] <= burst_i;
    end
end


// Update counter
always_ff @ (posedge clk) begin
    if (reset_n)
        cnt <= 3'b0;
    else if (resp_i)
        cnt <= cnt + 3'b1;
    else if (cnt == 4)
        cnt <= 3'b0;
    else
        cnt <= cnt;
end


endmodule : cacheline_adaptor
